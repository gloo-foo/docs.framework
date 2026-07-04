---
title: base64
---

# Base64 Command Compatibility

## Summary

Highly compatible with GNU `base64`: encode/decode, `-d`/`--decode`, `-i`/`--ignore-garbage`, and `-w`/`--wrap` (including `-w 0` to disable wrapping and the default wrap of 76) all match GNU byte-for-byte. The one divergence is that input is read line-by-line, so a single trailing newline on the input is dropped before encoding.

## Key Behaviors

```bash
# Encode stdin (default wrap at column 76)
$ printf '%s' 'The quick brown fox jumps over the lazy dog.' | base64
VGhlIHF1aWNrIGJyb3duIGZveCBqdW1wcyBvdmVyIHRoZSBsYXp5IGRvZy4=

# Decode (-d / --decode)
$ printf 'aGVsbG8=' | base64 -d
hello

# Wrap at a custom column (-w / --wrap): output is split into lines of COLS chars
$ printf 'aaaaaaaaaa' | base64 -w 4
YWFh
YWFh
YWFh
YQ==

# Disable wrapping (-w 0): one unbroken line
$ printf 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' | base64 -w 0
YWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFh

# Ignore non-alphabet bytes when decoding (-i / --ignore-garbage)
$ printf 'aGV sbG8 =' | base64 -d -i
hello

# Round-trip: decode reverses encode
$ printf '%s' 'The quick brown fox jumps over the lazy dog.' | base64 | base64 -d
The quick brown fox jumps over the lazy dog.
```

## Intentional Divergences

- Input is read line-by-line and a single trailing newline is dropped before encoding, so encoding text *with* a trailing newline yields the same result as encoding it without one. GNU `base64` encodes the trailing newline byte as part of the data. For example, `printf 'hello\n' | base64` yields `aGVsbG8=` here, but `aGVsbG8K` under GNU. Feed input without a trailing newline (`printf '%s'`) for byte-identical parity; all other behavior — encode, decode, `-d`/`--decode`, `-i`/`--ignore-garbage`, and every `-w`/`--wrap` width including the default of 76 and `-w 0` — matches GNU `base64` exactly.
