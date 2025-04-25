# What Is This ISO Useful For?

I once had to install Arch Linux on a PC without a monitor to set up a home server. That PC had network issues, so I had to figure out a way to get system logs without a monitor or network access. That’s why I created this ISO image — so that after booting, the Linux system would automatically save logs to a separate volume on a USB stick with a file system.

---

# Creating the ISO

First, clone the repository:

```sh
git clone https://github.com/AndyLocks/LogOnBootArchIso && cd ./LogOnBootArchIso
```

## Configuring and Preparing the Image

There is a systemd service located at `airootfs/etc/systemd/system/network-diag.service`, which launches the script `airootfs/root/network_diag.sh`:

```properties
[Unit]
Description=Network diag
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/usr/bin/bash -c 'chmod +x ~/network_diag.sh && ~/network_diag.sh'
Type=oneshot

[Install]
WantedBy=multi-user.target
```

You might need to modify something in this configuration, so it’s important to be aware of it.

Here is the `airootfs/root/network_diag.sh` script:

```bash
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
```

> [!WARNING]
> It's very important to replace `/dev/sda3` with the name of your USB drive!

Try running:

```sh
lsblk
```

You’ll get something like:

```
NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
zram0       254:0    0     4G  0 disk [SWAP]
nvme0n1     259:0    0 476.9G  0 disk 
├─nvme0n1p1 259:1    0     1G  0 part /boot
└─nvme0n1p2 259:2    0 475.9G  0 part /
```

Now insert the USB stick and run the command again. A new device should appear:

```
NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
sda           8:0    1   3.8G  0 disk 
├─sda1        8:1    1  1012M  0 part 
├─sda2        8:2    1   172M  0 part 
└─sda3        8:3    1   2.6G  0 part 
...
```

This is your USB stick. Replace `/dev/sda3` with `/dev/<your_flash_drive>3`. Keep the number 3, as we will later add a new partition for the log file. The Arch ISO already contains two partitions.

You can also customize the script or change the name of the log file.

## Build

```sh
sudo mkarchiso -v -w ~/TemporaryStorage -o ~/archout .
```

- `~/TemporaryStorage` — a temporary directory for intermediate files. You can create it temporarily:
    

```
mkdir ~/TemporaryStorage
```

- `~/archout` — the directory where the final ISO will be placed.
    

## Writing to USB

> [!WARNING]
> Make sure the USB stick doesn’t contain important data, as it will be erased when the image is written!

Write the image to disk. **Make sure to replace `/dev/diggawas` with your USB device (e.g., `/dev/sda`)**, and replace `archlinux-xxxx.xx.xx-x86_64.iso` with the actual filename.

```sh
sudo dd bs=4M if=archlinux-xxxx.xx.xx-x86_64.iso of=/dev/diggawas status=progress oflag=sync conv=fsync
```

## Creating a New Partition on USB

Now we need to create a third partition. But first, make sure that the Arch ISO indeed created two partitions — if it didn’t, you’ll need to edit the script and change `/dev/sda3` to `/dev/sda2`.

Check with:

```
lsblk
```

If you see two partitions:

```
NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
sda           8:0    1   3.8G  0 disk 
├─sda1        8:1    1  1012M  0 part 
└─sda2        8:2    1   172M  0 part 
...
```

Then you can create a third one. If there’s only one, modify the script `airootfs/root/network_diag.sh`, rebuild, and write again to USB.

Don’t forget to replace `/dev/diggawas` with your actual device:

```
sudo fdisk /dev/diggawas
```

Inside `fdisk`:

- `n` — create new partition
    
- `p` — primary
    

(You can press `Enter` for defaults, but here are the steps just in case):

- Partition number — 3 (or 2 if the ISO only created one partition)
    
- First sector — default
    
- Last sector — choose desired size (e.g., `+100M`)
    
- `w` — write and exit
    

Then format the new partition (again replacing `/dev/diggawas3` with your device — in my case `/dev/sda3`, but could be `/dev/sda2` if there were only two partitions total):

```
sudo mkfs.ext4 /dev/diggawas3
```

---

Now, when you plug the USB into a PC and boot from it, the service will start, run the script, and save logs to the USB. You can later plug it into another computer to read what happened. This helped me a lot in my case.
