---
title: wc
---

## Wc Command Compatibility

### Summary

Partially compatible with GNU `wc`: the per-flag column selection and field order match, but cmd-wc emits bare, space-separated counts with no field padding and no filename, and its byte/char counts exclude line terminators. Counts were verified empirically in the Docker integration harness against Debian coreutils `wc`.

### Key Behaviors

```bash
# Default: lines, words, bytes (GNU field order), single-space separated.
$ printf 'alpha\nbeta\n' | wc
2 2 9

# Lines only (-l): newline count.
$ printf 'alpha\nbeta\n' | wc -l
2

# Words only (-w): whitespace-delimited word count.
$ printf 'one two three\nfour five\n' | wc -w
5

# Bytes only (-c): bytes EXCLUDING line terminators.
$ printf 'alpha\nbeta\n' | wc -c
9

# Chars only (-m): Unicode rune count, excluding newlines.
$ printf 'abc\nXY\n' | wc -m
5

# Max line length (-L): length in bytes of the longest line.
$ printf 'hello world\nfoo\n' | wc -L
11

# Multiple flags select multiple columns in GNU order (lines words bytes).
$ printf 'alpha\nbeta\n' | wc -l -w -c
2 2 9
```

### Intentional Divergences

- **No field padding or alignment.** cmd-wc prints each count as a bare integer joined by a single space. GNU `wc` right-aligns every count in a common-width, leading-space-padded field (e.g. `2       2      11`). cmd-wc never pads, for single-flag or multi-count output.
- **No filename column.** GNU `wc` appends the filename after the counts for file operands and prints a `total` line when more than one file is given. cmd-wc emits only the counts.
- **Byte (`-c`) and char (`-m`) counts exclude line terminators.** The gloo stream strips the trailing newline from each line before counting, so newlines are not counted as bytes or characters. For `alpha\nbeta\n`, cmd-wc reports 9 bytes where GNU reports 11 (the two `\n`); for `abc\nXY\n`, cmd-wc reports 5 chars where GNU reports 7. Line counts (`-l`), word counts (`-w`), and max line length (`-L`) report the same numeric values as GNU.
