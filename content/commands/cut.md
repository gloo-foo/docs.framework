---
title: cut
---

# Cut Command Compatibility

## Summary

Highly compatible with GNU `cut`. Field (`-f`/`-d`), character (`-c`), and byte (`-b`) selection all match GNU, including discrete positions, ranges, the bounded `-N` (from-start) range, and `--complement`. The one divergence is the open-ended `-f N-` field range.

## Key Behaviors

```bash
# Select a single field with a custom delimiter
$ printf 'one:two:three\n' | cut -d : -f 2
two

# Discrete positions and a range
$ printf 'a:b:c:d:e\n' | cut -d : -f 1,3-4
a:c:d

# Default delimiter is TAB
$ printf 'alpha\tbeta\tgamma\n' | cut -f 1,3
alpha	gamma

# Bounded from-start field range: -N selects fields 1..N
$ printf 'one:two:three:four\n' | cut -d : -f -2
one:two

# Character mode: ranges and open-ended ranges
$ printf 'Hello, World\n' | cut -c 1-5
Hello
$ printf 'abcdefghij\n' | cut -c 3-
cdefghij

# Byte mode: discrete positions
$ printf 'abcdefgh\n' | cut -b 1,3,5
ace

# Complement: emit the fields NOT selected
$ printf 'a,b,c\n' | cut -d , -f 2 --complement
a,c

# A line with no delimiter passes through unchanged in field mode
$ printf 'no-delimiter\n' | cut -d : -f 1
no-delimiter
```

## Intentional Divergences

- **Open-ended `-f N-` field ranges are not supported.** The command package selects fields by explicit 1-based position, which cannot express an unbounded upper end, so `cut -f 2-` is rejected with a clear error rather than emitting fields 2 through the end. GNU prints field N onward. The bounded forms work: list the fields explicitly (`-f 2,3,4`) or use a from-start range (`-f -3`). Open-ended ranges are fully supported for `-c` and `-b`, which accept a spec string (e.g. `cut -c 3-`).
- Selected fields, bytes, and characters are emitted in input order, not request order, matching cut(1): `-f 3,1` yields field 1 then field 3.
