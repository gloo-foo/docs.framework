---
title: comm
---

## Comm Command Compatibility

### Summary

Fully compatible with GNU `comm`. Output is byte-identical for the default three-column form and for every column-suppression combination, including GNU's grouped digit flags (`-12`, `-23`, `-123`).

### Key Behaviors

Both inputs must already be sorted. Column 1 holds lines unique to FILE1, column 2 (one leading tab) holds lines unique to FILE2, and column 3 (two leading tabs) holds lines common to both. Suppressing an earlier column collapses the leading tab of every later column.

```bash
# Inputs (sorted):
#   a.txt: apple banana cherry
#   b.txt: banana cherry kiwi

# Default three-column output
$ comm a.txt b.txt
apple
		banana
		cherry
	kiwi

# -1: suppress column 1; columns 2 and 3 lose a leading tab
$ comm -1 a.txt b.txt
	banana
	cherry
kiwi

# -2: suppress column 2
$ comm -2 a.txt b.txt
apple
	banana
	cherry

# -3: suppress column 3 (lines common to both)
$ comm -3 a.txt b.txt
apple
	kiwi

# -12: grouped suppression of columns 1 and 2 (only common lines, no tabs)
$ comm -12 a.txt b.txt
banana
cherry

# -123: suppress every column (empty output)
$ comm -123 a.txt b.txt
```

### Intentional Divergences

None — output matches GNU `comm`.

GNU comm's column-suppression flags are the digit-leading short options `-1`, `-2`, `-3`. Because urfave/cli/v3 parses a leading-digit token as a positional rather than a short flag, the wrapper rewrites these (and grouped forms such as `-12`/`-123`) into long flags (`--suppress-column-1`, etc.) before parsing. This is transparent: the accepted syntax and output are identical to GNU `comm`. Tokens after a `--` terminator are left untouched, so filenames beginning with a digit are safe.
