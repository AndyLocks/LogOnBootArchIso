#!/bin/bash

mkdir -p /mnt/logs

if mount /dev/sda3 /mnt/logs; then
    LOGFILE="/mnt/logs/network_diagnostics.txt"

    echo "=== Network Diagnostics ===" > "$LOGFILE"
    echo "Date: $(date)" >> "$LOGFILE"
    echo >> "$LOGFILE"

    echo "--- Interfaces ---" >> "$LOGFILE"
    ifconfig -a >> "$LOGFILE" 2>&1
    echo >> "$LOGFILE"

    echo "--- dmesg (NIC-related) ---" >> "$LOGFILE"
    dmesg | grep -iE 'eth|net|e1000|realtek|r8169|link|carrier|MAC' >> "$LOGFILE" 2>&1
    echo >> "$LOGFILE"

    echo "--- PCI Devices ---" >> "$LOGFILE"
    lspci | grep -i eth >> "$LOGFILE" 2>/dev/null
    echo >> "$LOGFILE"

    echo "--- Kernel Modules (NIC-related) ---" >> "$LOGFILE"
    lsmod | grep -iE 'e1000|r8169|realtek|net' >> "$LOGFILE" 2>/dev/null
    echo >> "$LOGFILE"

    echo "--- Bringing up interface ---" >> "$LOGFILE"
    ifconfig eth0 up >> "$LOGFILE" 2>&1
    sleep 2

    echo "--- DHCP Request ---" >> "$LOGFILE"
    udhcpc -i eth0 >> "$LOGFILE" 2>&1
    echo >> "$LOGFILE"

    echo "--- Ping Test ---" >> "$LOGFILE"
    ping -c 3 1.1.1.1 >> "$LOGFILE" 2>&1
    if [ $? -eq 0 ]; then
        echo "[✓] Network: SUCCESS" >> "$LOGFILE"
        beep -f 1000 -l 200
    else
        echo "[✗] Network: FAILED" >> "$LOGFILE"
        beep -f 500 -l 800
        beep -f 500 -l 800
    fi

    echo "--- Done ---" >> "$LOGFILE"

    umount /mnt/logs
else
    echo "Error: Failed to mount /dev/sda3" >&2
fi
