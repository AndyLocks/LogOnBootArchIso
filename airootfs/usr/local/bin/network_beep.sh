#!/usr/bin/env bash

for _ in {1..3}; do
    beep -f 880 -l 100
    sleep 0.1
done

sleep 5

if ip a | grep -q 'inet .* brd'; then
    beep -f 1000 -l 700
else
    for _ in {1..3}; do
        beep -f 400 -l 500
        sleep 0.3
    done
fi
