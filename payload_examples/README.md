# FOX-JACK Payload Examples

This directory contains example payloads for **FOX-JACK**.

## Filename Format

Payload filenames must follow this format:

```
E????-name.payload
```

* `E????` is a 4-digit payload ID (e.g., `E0000`)
* `name` is a short, descriptive label

**Example:**

```
E0000-arp-scan.payload
```

## How to Use

1. Copy or write your payload file into one of the following directories on the UMS disk:

   ```
   <UMS_DISK>/payloads/mod1.d/
   <UMS_DISK>/payloads/mod2.d/
   <UMS_DISK>/payloads/mod3.d/
   ```

   These correspond to FOX-JACK’s Mode 1, 2, and 3 (switch positions).

2. Each payload must be a valid executable script (typically Bash) and will run automatically when that mode is selected.

## ⚠️ Notes

* GNU `coreutils` is **not supported currently**, because its build requires disabling **Y2038** support in Buildroot, which is not recommended.
* Use **BusyBox-compatible** commands in your scripts for best compatibility with FOX-JACK’s minimal environment.

