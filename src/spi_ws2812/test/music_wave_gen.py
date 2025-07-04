#!/usr/bin/env python3
import numpy as np
import colorsys
import subprocess
import time
import sys

AUDIO_FILE = "music.mp3"     # Input audio file
OUTPUT_BIN = "wave_output.bin"  # Output RGB binary
CHUNK = 1024                 # Samples per frame
RATE = 44100                 # Audio sample rate

hue = 0

# Decode audio to raw PCM using ffmpeg
ffmpeg = subprocess.Popen([
    "ffmpeg", "-loglevel", "quiet", "-i", AUDIO_FILE,
    "-f", "s16le", "-acodec", "pcm_s16le",
    "-ac", "1", "-ar", str(RATE), "-"
], stdout=subprocess.PIPE)

with open(OUTPUT_BIN, "wb") as out:
    while True:
        raw = ffmpeg.stdout.read(CHUNK * 2)  # 2 bytes per 16-bit sample
        if len(raw) < CHUNK * 2:
            break  # End of stream

        data = np.frombuffer(raw, dtype=np.int16)
        volume = np.linalg.norm(data) / CHUNK
        brightness = min(volume / 50.0, 1.0)

        # Hue sweep rainbow
        hue = (hue + 2) % 360
        r, g, b = [int(x * 255 * brightness) for x in colorsys.hsv_to_rgb(hue / 360.0, 1.0, 1.0)]

        out.write(bytes([r, g, b]))

