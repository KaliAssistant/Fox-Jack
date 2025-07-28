# LED BIN EXAMPLES

This directory contains example **SHM writer binary files** for the Fox-Jack EXT board’s **WS2812B RGB LED**.

---

## File Format

Each `.bin` file is a sequence of RGB frames in **binary format**:

```bash
printf "\xRR\xGG\xBB\xRR\xGG\xBB..." > led.bin
```

* Each **frame = 3 bytes** (Red, Green, Blue)
* Multiple frames can be appended for animations

---

## Runtime Integration

These binary files are consumed by the `shmled` tool, which writes to a shared memory segment read by the `ws2812d` daemon.

### Device Path:

`/dev/shm/led_rgb` — shared memory backend read by the WS2812 RGB LED daemon

---

## Example Usage

```bash
shmled -l -i led.bin -s 10000
```

* `-l` → enable loop mode
* `-i led.bin` → input binary animation file
* `-s 10000` → delay 10,000 microseconds per frame

---

## Full Command-Line Options

```
$ shmled -h
shmLED - WS2812 RGB NEOPIXEL SHM WRITER

Usage: shmled -c #RRGGBB -i <rgb bin file input> [-l -i|-b|-d|-r] [-s µs]

-c :   #RRGGBB, RGB hex color
-i :   <input.bin>, binary RGB input file (\xRR\xGG\xBB ...)
-l :   Loop mode:
       -b : blink
       -d : fade
       -r : rainbow
       -i : loop input file
-s :   Delay in microseconds per frame
-h :   Show this help message
```

---

## Notes

* Compatible with **any WS2812B** device wired to `/dev/led_rgb`
* `shmled` can be used for **static colors**, **predefined animations**, or **custom loops**
* The example `.bin` files here are ready to use — or you can generate your own with simple scripts

---
