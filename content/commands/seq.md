---
title: seq
---

## Seq Command Compatibility

### Summary

Highly compatible with GNU `seq`.

### Key Behaviors

```bash
# Basic: seq LAST
$ seq 5
1 2 3 4 5

# Two args: seq FIRST LAST
$ seq 2 5
2 3 4 5

# Three args: seq FIRST INCREMENT LAST
$ seq 1 2 10
1 3 5 7 9

# Negative increment (descending, inclusive of LAST)
$ seq 10 -2 1
10 8 6 4 2

# Custom separator: numbers joined onto one line, no trailing separator
$ seq -s , 1 5
1,2,3,4,5

# Equal width: zero-pad to a common field width
$ seq -w 8 11
08 09 10 11

# Equal width with a fractional step: fixed precision, sign-aware padding
$ seq -w 8 0.5 10
08.0 08.5 09.0 09.5 10.0

# printf-style format applied to each number
$ seq -f %.2f 1 3
1.00 2.00 3.00
```

### Intentional Divergences

- `-s` follows GNU: the separator is placed only between numbers, with no trailing separator. BSD `seq` appends a trailing separator.
- The default (non-`-w`) rendering uses Go's `%g`. Unlike GNU, a fractional increment does not promote whole numbers to a trailing-zero form: `seq 1 0.5 2.5` yields `1 1.5 2 2.5`, not `1.0 1.5 2.0 2.5`. Under `-w`, equal-width output matches GNU exactly (fixed precision, sign-aware zero padding).
