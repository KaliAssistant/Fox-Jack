#!/bin/bash
out="police.bin"
rm -f "$out"
for i in {1..10}; do
    printf "\xFF\x00\x00" >> "$out"  # red
    printf "\x00\x00\xFF" >> "$out"  # blue
done

