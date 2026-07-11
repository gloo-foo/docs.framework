---
title: uniq
---

## Uniq Command Compatibility

### Summary

Highly compatible with GNU `uniq` for the implemented flags. Output is byte-identical to GNU `uniq` for the default collapse, `-c`, `-d`, `-u`, and `-i` (verified in the Docker integration harness against Debian coreutils).

### Key Behaviors

```bash
# Collapse each run of ADJACENT identical lines to one line (default).
# Non-adjacent repeats are preserved, so input is typically sorted first.
$ printf 'a\nb\nb\nc\n' | uniq
a
b
c

# -c / --count: prefix each line with its occurrence count, right-justified in a
# width-7 field followed by a single space (GNU's "%7d " format).
$ printf 'a\nb\nb\nc\n' | uniq -c
      1 a
      2 b
      1 c

# -d / --repeated: only print groups that repeat (run length > 1).
$ printf 'a\nb\nb\nc\n' | uniq -d
b

# -u / --unique: only print groups that do not repeat (run length == 1).
$ printf 'a\nb\nb\nc\n' | uniq -u
a
c

# -i / --ignore-case: fold case when comparing; the first line of each group is
# still emitted verbatim.
$ printf 'a\nA\nb\n' | uniq -i
a
b

# A FILE operand is read instead of standard input.
$ uniq -c in.txt
```

### Intentional Divergences

None — output matches GNU `uniq` for the implemented flags (`-c`, `-d`, `-u`, `-i`), including the `-c` count field width (`%7d`). The comparison-key offset flags `-f` (skip fields), `-s` (skip characters), and `-w` (compare width) are not yet implemented; within the implemented flags, output is byte-identical to GNU `uniq`.
