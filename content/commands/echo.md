---
title: echo
---

## Echo Command Compatibility

### Summary

Highly compatible with GNU `echo` (coreutils `/bin/echo`, not the shell builtin) for the implemented flags. Output is byte-identical to GNU `echo` for plain operands, `-n`, `-e` (the common backslash escapes), and `-E` (verified in the Docker integration harness against Debian coreutils `/bin/echo`).

### Key Behaviors

```bash
# Operands joined by single spaces, trailing newline
$ echo hello world
hello world

# No operands: a single blank line
$ echo

# -n: suppress the trailing newline (no newline after "hello")
$ echo -n hello
hello

# -e: interpret backslash escapes (\t, \n, etc.)
$ echo -e 'a\tb\nc'
a	b
c

# -e with \c: truncate the rest of the output, including the trailing newline
$ echo -e 'keep\cdrop'
keep

# -E (default): backslash sequences stay literal
$ echo -E 'a\tb'
a\tb
$ echo 'a\tb'
a\tb
```

### Intentional Divergences

- Flag parsing follows urfave/cli, not GNU's positional option scan. GNU `echo` stops treating tokens as options at the first non-option operand and prints any unknown leading `-`/`--` token verbatim; cmd-echo parses `-n`/`-e`/`-E` (and `--version`/`--help`) as flags and errors on an unknown leading flag (e.g. `echo --nope`) instead of printing it.
- `-e` interprets the common escapes `\\ \a \b \e \f \n \r \t \v` and `\c` (truncate). The numeric escapes `\0NNN` (octal) and `\xHH` (hex) are not interpreted and remain literal — `echo -e '\x41'` prints `\x41`, where GNU prints `A`.
- The reference is coreutils `/bin/echo`, not the POSIX shell builtin `echo`, whose flag and escape handling differ by shell.
