---
title: grep
---

# Grep Command Compatibility

## Summary

Highly compatible with GNU `grep` for the supported flag set (`-i`, `-v`, `-n`, `-c`, `-E`, `-w`, `-x`). Matching is fixed-string by default (equivalent to GNU `grep -F`).

## Key Behaviors

```bash
# Basic fixed-string match (default mode == GNU `grep -F`)
$ printf 'hello world\ngoodbye\nHello again\nthe end\nhello\n' | grep hello
hello world
hello

# -i: case-insensitive match
$ printf 'hello world\ngoodbye\nHello again\nthe end\nhello\n' | grep -i hello
hello world
Hello again
hello

# -v: invert — select non-matching lines
$ printf 'hello world\ngoodbye\nHello again\nthe end\nhello\n' | grep -v hello
goodbye
Hello again
the end

# -n: prefix each match with its 1-based line number
$ printf 'hello world\ngoodbye\nHello again\nthe end\nhello\n' | grep -n hello
1:hello world
5:hello

# -c: print only the count of matching lines
$ printf 'hello world\ngoodbye\nHello again\nthe end\nhello\n' | grep -c hello
2

# No match: empty output, exit status 1 (matches GNU)
$ printf 'hello\n' | grep missing
$ echo $?
1

# -E: extended regular expression with alternation
$ printf 'hello world\ngoodbye\nthe end\n' | grep -E 'hello|end'
hello world
the end

# -w: whole-word match (word-boundary anchored)
$ printf 'the end\nthere\nother\n' | grep -w the
the end

# -x: whole-line match
$ printf 'hello\nhello world\n' | grep -x hello
hello

# A literal pattern is fixed-string by default — '.' is not a wildcard
$ printf 'a.c\nabc\n' | grep 'a.c'
a.c
```

## Intentional Divergences

- Matching is **fixed-string by default**, equivalent to GNU `grep -F`. There is no separate `-F`/`--fixed-strings` flag because that is already the default; regex matching is opt-in via `-E` (extended) or `-w` (word). GNU's default basic-regular-expression (BRE) mode is not provided.
- `-E` patterns are compiled with Go's `regexp` engine (RE2 syntax), not POSIX ERE. Common constructs (alternation, character classes, `.`, `*`, `+`, `?`, anchors) behave identically; backreferences and a few POSIX-only constructs are unsupported by RE2.
- Short boolean flags are **not bundled**: pass `-i -n`, not `-in`. Combining single-letter flags into one token is unsupported by the CLI parser, unlike GNU.
- No `-o`/`--only-matching`, `-l`/`--files-with-matches`, or per-file `FILE:` line prefixes when multiple files are given; the supported flags are `-i`, `-v`, `-n`, `-c`, `-E`, `-w`, `-x` only.
