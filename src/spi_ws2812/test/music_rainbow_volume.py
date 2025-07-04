#!/usr/bin/env python3
import numpy as np
import subprocess
import argparse
import colorsys

parser = argparse.ArgumentParser()
parser.add_argument("-i", "--input", required=True)
parser.add_argument("-o", "--output", required=True)
parser.add_argument("-s", "--scale", type=float, default=0.001)
args = parser.parse_args()

AUDIO_FILE = args.input
OUTPUT_BIN = args.output
SCALE = args.scale

CHUNK = 1024
RATE = 44100

ffmpeg = subprocess.Popen([
    "ffmpeg", "-loglevel", "quiet", "-i", AUDIO_FILE,
    "-f", "s16le", "-acodec", "pcm_s16le",
    "-ac", "1", "-ar", str(RATE), "-"
], stdout=subprocess.PIPE)

def clamp(x): return max(0, min(255, int(x)))

def fft_band_energy(data, rate, low, high):
    N = len(data)
    fft = np.fft.rfft(data)
    freq = np.fft.rfftfreq(N, 1.0 / rate)
    idx = np.where((freq >= low) & (freq < high))[0]
    band_power = np.abs(fft[idx])**2
    return np.sqrt(np.mean(band_power)) if len(band_power) else 0



with open(OUTPUT_BIN, "wb") as out:
    hue = 0
    while True:
        raw = ffmpeg.stdout.read(CHUNK * 2)
        if len(raw) < CHUNK * 2:
            break

        data = np.frombuffer(raw, dtype=np.int16)
        volume = np.linalg.norm(data) / CHUNK
        brightness = min(volume * SCALE, 1.0)
        bass = fft_band_energy(data, RATE, 20, 250)
        #brightness = min(bass * SCALE, 1.0)

        hue = (hue + 2) % 360
        r, g, b = [clamp(x * 255 * brightness) for x in colorsys.hsv_to_rgb(hue / 360.0, 1.0, 1.0)]
        out.write(bytes([r, g, b]))

