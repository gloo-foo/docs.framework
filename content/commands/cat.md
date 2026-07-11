---
title: cat
---

## Cat Command Compatibility

### Summary

Highly compatible with GNU `cat` for the implemented flags. Output is byte-identical to GNU `cat` for concatenation, `-n`, and `-b` (verified in the Docker integration harness against Debian coreutils).

### Key Behaviors

```bash
# Concatenate stdin or files to stdout (identity with no flags)
$ printf 'a\nb\n' | cat
a
b

# Number all output lines (-n): 6-wide right-aligned number, a TAB, then the line
$ printf 'a\n\nb\n' | cat -n
     1	a
     2
     3	b

# Number nonempty output lines (-b); blank lines are emitted unnumbered.
# -b overrides -n when both are given (GNU precedence).
$ printf 'a\n\nb\n' | cat -b
     1	a

     2	b

# Multiple file operands are concatenated in order; "-" (or no operand) is stdin
$ cat a.txt b.txt
```

### Intentional Divergences

- cmd-cat implements the line-numbering subset of GNU `cat`: `-n`/`--number` and `-b`/`--number-nonblank`. The GNU display/whitespace flags `-s` (squeeze blank), `-E`/`-T`/`-A` (show ends/tabs/all), `-v` (show nonprinting), and `-u` (unbuffered) are not implemented. Within the implemented flags, output matches GNU `cat` exactly.
