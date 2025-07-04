#!/usr/bin/env python3
import numpy as np
import subprocess
import argparse

def freq_band_energy(data, rate, low, high):
    N = len(data)
    fft = np.fft.rfft(data)
    freq = np.fft.rfftfreq(N, 1.0 / rate)

    # Get indices within band
    idx = np.where((freq >= low) & (freq < high))[0]
    band_power = np.abs(fft[idx])**2
    return np.sqrt(np.mean(band_power))  # Root mean square power

def clamp(x): return max(0, min(255, int(x)))

parser = argparse.ArgumentParser()
parser.add_argument("-i", "--input", required=True)
parser.add_argument("-o", "--output", required=True)
args = parser.parse_args()

AUDIO_FILE = args.input
OUTPUT_BIN = args.output

CHUNK = 1024
RATE = 44100

ffmpeg = subprocess.Popen([
    "ffmpeg", "-loglevel", "quiet", "-i", AUDIO_FILE,
    "-f", "s16le", "-acodec", "pcm_s16le",
    "-ac", "1", "-ar", str(RATE), "-"
], stdout=subprocess.PIPE)

with open(OUTPUT_BIN, "wb") as out:
    while True:
        raw = ffmpeg.stdout.read(CHUNK * 2)
        if len(raw) < CHUNK * 2:
            break

        data = np.frombuffer(raw, dtype=np.int16)
        if np.max(np.abs(data)) < 100:
            out.write(b"\x00\x00\x00")
            continue

        bass   = freq_band_energy(data, RATE, 20, 250)
        mid    = freq_band_energy(data, RATE, 250, 4000)
        treble = freq_band_energy(data, RATE, 4000, 20000)

        # Normalize and map to 0–255
        scale = 0.01
        r = clamp(bass * scale)
        g = clamp(mid * scale)
        b = clamp(treble * scale)

        out.write(bytes([r, g, b]))

