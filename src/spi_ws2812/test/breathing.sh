#!/bin/bash
out="breathing.bin"
rm -f "$out"
for i in $(seq 0 5 255); do
    printf $(printf '\\x%x\\x00\\x00' "$i") >> "$out"
done
for i in $(seq 255 -5 0); do
    printf $(printf '\\x%x\\x00\\x00' "$i") >> "$out"
done

