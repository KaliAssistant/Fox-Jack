#!/bin/bash
out="rainbow_wave.bin"
frames=180
for h in $(seq 0 2 358); do
    python3 -c "
import colorsys
r, g, b = [int(x * 255) for x in colorsys.hsv_to_rgb($h/360, 1.0, 1.0)]
open('$out', 'ab').write(bytes([r, g, b]))
"
done

