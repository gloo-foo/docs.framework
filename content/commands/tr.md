---
title: tr
---

## Tr Command Compatibility

### Summary

Highly compatible with GNU `tr` for translate, delete, squeeze, and complement. Output is byte-identical to GNU `tr` for all of these (verified in the Docker integration harness against Debian coreutils), with one line-orientation divergence on the input's trailing newline.

### Key Behaviors

```bash
# Translate SET1 -> SET2, character by character
$ printf 'abc\n' | tr abc xyz
xyz

# Ranges expand: lower-case to upper-case (and back)
$ printf 'hello world\n' | tr a-z A-Z
HELLO WORLD

# Delete every character in SET1 (-d), SET1 alone
$ printf 'hello world\n' | tr -d aeiou
hll wrld

# Squeeze runs of repeated characters in SET1 (-s), SET1 alone
$ printf 'hello   world\n' | tr -s ' '
hello world

# Squeeze with a translate: SET2 is the squeezed set
$ printf 'aabbcc\n' | tr -s ab xy
xy

# Complement of SET1 (-c), combined with delete
$ printf 'abc123 xyz\n' | tr -d -c a-z
abcxyz

# Complement translate: every char outside SET1 maps to the last char of SET2
$ printf 'Hello World 123\n' | tr -c a-z _
_ello__orld____
```

### Intentional Divergences

- **Trailing newline under a translating `-c`.** cmd-tr is line-oriented: it splits input on `\n`, transforms each line, and re-joins with `\n`, so the input's trailing newline is treated as a line terminator rather than translatable data. For a _translating_ complement (`tr -c SET1 SET2`), GNU maps that trailing newline — being outside SET1 — to the replacement, emitting one extra replacement character; cmd-tr leaves the terminator as `\n`. Every other case (translate, `-d`, `-s`, and `-d -c` delete-complement) is byte-identical to GNU `tr`, because there the trailing newline is either preserved by both or dropped by both.
- **Operand requirements follow GNU.** SET1 is always required; SET2 is required only for a plain translate. `-d` and `-s` operate on SET1 alone (`tr -s ' '` and `tr -d aeiou` are valid one-operand invocations), matching GNU.
- The GNU `-t`/`--truncate-set1` flag and the `[:class:]`/`[=equiv=]`/`[c*n]` set notations are not implemented; SET expansion supports literal characters and `a-z` ranges.
