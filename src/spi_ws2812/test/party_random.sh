#!/bin/bash
out="party.bin"
rm -f "$out"
for i in {1..50}; do
    r=$((RANDOM % 256))
    g=$((RANDOM % 256))
    b=$((RANDOM % 256))
    printf $(printf '\\x%x' "$r" "$g" "$b") >> "$out"
done

