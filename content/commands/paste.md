---
title: paste
---

# Paste Command Compatibility

## Summary

Compatible with GNU/Unix `paste` on a single input stream; multi-file operands intentionally diverge (this paste concatenates streams rather than merging columns).

## Key Behaviors

```bash
# Default (parallel) mode on a single stream is a passthrough: each input line
# is its own output row.
$ printf 'alpha\nbeta\ngamma\n' | paste
alpha
beta
gamma

# Serial mode (-s) collapses the whole stream into one TAB-joined row.
$ printf 'alpha\nbeta\ngamma\n' | paste -s
alpha	beta	gamma

# Serial mode with a custom single-character delimiter (-d).
$ printf 'alpha\nbeta\ngamma\n' | paste -s -d ,
alpha,beta,gamma

# The -d list is cycled byte by byte between joined lines.
$ printf 'w\nx\ny\nz\n' | paste -s -d '-='
w-x=y-z
```

## Intentional Divergences

- Multiple file operands in default (parallel) mode are **concatenated into one stream** and passed through line by line — they are not merged side by side into columns. GNU `paste a b` emits tab-separated columns (`a-line<TAB>b-line`); this paste emits every line of `a`, then every line of `b`.
- Multiple file operands in serial mode (`-s`) join the **whole concatenated stream into a single row**. GNU `paste -s a b` emits one row per file; this paste emits one row for all files combined.
- `-d` (delimiter) takes effect on serial joins, with the delimiter list cycled byte by byte between lines; this matches GNU for single-stream serial joins.
