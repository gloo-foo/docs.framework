---
title: hexdump
---

# Hexdump Command Compatibility

## Summary

Partially compatible with util-linux `hexdump`, and only for the canonical (`-C`) display of a single short input line. cmd-hexdump is line-oriented: it splits stdin on newlines and renders each line independently. This diverges substantially from util-linux `hexdump`, which treats the input as one continuous byte stream. The only byte-identical case is empty input (both produce nothing). All other behavior is documented as an intentional divergence (verified in the Docker integration harness against util-linux `hexdump` from `bsdextrautils` on Debian).

## Key Behaviors

```bash
# Default mode: space-separated lowercase hex bytes, one row per input line.
# The newline byte is dropped.
$ printf 'abc\n' | hexdump
61 62 63

# Default mode preserves line structure (one row per line)
$ printf 'Hi\nok\n' | hexdump
48 69
6f 6b

# Canonical mode (-C / --canonical): offset, midpoint-gapped hex field, ASCII
# sidebar — matches util-linux `hexdump -C` for a single short line.
$ printf 'Hi\n' | hexdump -C
00000000  48 69                                             |Hi|

# A full 16-byte line shows the gap inserted after the eighth byte.
$ printf '0123456789abcdef\n' | hexdump -C
00000000  30 31 32 33 34 35 36 37  38 39 61 62 63 64 65 66  |0123456789abcdef|

# Non-printable bytes (here NUL and DEL) render as '.' in the sidebar; the hex
# field still shows their true values.
$ printf 'A\x00B\x7f\n' | hexdump -C
00000000  41 00 42 7f                                       |A.B.|

# Empty input produces no output (the one byte-identical case with util-linux).
$ printf '' | hexdump -C
```

## Intentional Divergences

cmd-hexdump implements a deliberately minimal, line-oriented subset. It exposes only one flag, `-C` / `--canonical`; the util-linux format flags `-b` (octal bytes), `-c` (ASCII chars), `-d` (decimal), `-o` (octal), `-x` (hex words), and the `-n` / `-s` / `-v` length/offset/verbose controls are not implemented. Within what it does implement, it differs from util-linux `hexdump` as follows:

- **Line-oriented, not stream-oriented.** Input is split on `\n` and each line is dumped independently. util-linux processes the whole input as one continuous byte stream.
- **Per-line offset reset.** Every input line restarts the canonical offset at `00000000`. util-linux keeps a single offset that increments across the entire stream.
- **Newline byte dropped.** The `\n` that terminates each line is consumed by the line split and never appears in the dump. util-linux includes the `0a` byte in the stream.
- **No 16-byte wrapping.** A line longer than 16 bytes is rendered as one oversized row — the hex field stops at column 16 but the ASCII sidebar shows every byte. util-linux wraps every 16 bytes onto a new offset row.
- **No trailing offset line.** util-linux ends with a final line giving the total byte count (e.g. `00000003`); cmd-hexdump emits no such line.
- **Default mode is not util-linux's default.** With no flag, cmd-hexdump prints space-separated single hex bytes (xxd-like). util-linux's default is byte-swapped two-byte octal-grouped words plus the trailing offset line.
