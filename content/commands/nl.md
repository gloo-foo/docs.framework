---
title: nl
---

# Nl Command Compatibility

## Summary

Compatible with GNU `nl` for explicit body-numbering styles; the default body style and the rendering of unnumbered lines diverge by design.

## Key Behaviors

```bash
# Number every line (-b a): width-6 right-justified field, TAB separator
$ printf 'alpha\n\nbeta\n' | nl -b a
     1	alpha
     2	
     3	beta

# Narrower number field (-w)
$ printf 'alpha\nbeta\n' | nl -b a -w 3
  1	alpha
  2	beta

# Custom separator after the number (-s)
$ printf 'alpha\nbeta\n' | nl -b a -s ': '
     1: alpha
     2: beta

# Number formats (-n): ln (left), rn (right, default), rz (right zero-padded)
$ printf 'alpha\n' | nl -b a -n ln
1     	alpha
$ printf 'alpha\n' | nl -b a -n rz
000001	alpha

# Starting number (-v) and increment (-i)
$ printf 'alpha\nbeta\n' | nl -b a -v 10
    10	alpha
    11	beta
$ printf 'alpha\nbeta\n' | nl -b a -i 5
     1	alpha
     6	beta
```

## Intentional Divergences

- **Default body style.** GNU `nl` defaults to `-b t` (number non-empty lines only); cmd-nl defaults to `-b a` (number every line). With explicit `-b a`, output is byte-identical to GNU.
- **Unnumbered blank lines under `-b t`.** GNU pads a skipped blank line to the number-field width; cmd-nl emits the bare empty line.
- **Unnumbered lines under `-b n`.** GNU emits a width-wide blank field with no separator; cmd-nl emits the width-wide blank field followed by the separator (the default TAB).

All other behaviors — field width (`-w`), separator (`-s`), formats `ln`/`rn`/`rz` (`-n`), start (`-v`), and increment (`-i`) — match GNU `nl` exactly under `-b a`, as verified by the integration parity suite.
