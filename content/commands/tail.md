---
title: tail
---

## Tail Command Compatibility

### Summary

Compatible with GNU `tail` for line selection (`-n N`, `-n +N`) and the default last-ten-lines behavior; verified byte-identical in the Docker integration harness against Debian coreutils. Byte mode (`-c N`) and multiple file operands diverge as noted below. Follow mode (`-f`) is not implemented.

### Key Behaviors

```bash
# Default: the last 10 lines of stdin (or each file)
$ seq 1 15 | tail
6
7
8
9
10
11
12
13
14
15

# -n N: the last N lines
$ seq 1 5 | tail -n 3
3
4
5

# -n +N: every line from the 1-indexed line N onward
$ seq 1 5 | tail -n +3
3
4
5

# Fewer lines available than requested: all lines are emitted
$ printf '1\n2\n3\n' | tail -n 10
1
2
3

# File operand: a single file reads like stdin (no header)
$ tail -n 4 file.txt

# -c N: the last N bytes (see divergence below)
$ seq 1 15 | tail -c 6
14
15
```

### Intentional Divergences

- `-c N` (byte mode) emits the trailing bytes as a single stream record, and the line-oriented byte sink appends a record newline — so the raw output ends with **one extra trailing `\n`** versus GNU `tail -c` (GNU emits 6 bytes for `seq 1 15 | tail -c 6`; this implementation emits 7). The visible text is otherwise identical; the difference is masked by any shell `$(...)` capture, which strips trailing newlines.
- **Multiple file operands are concatenated with no `==> FILE <==` header.** GNU `tail` prints a `==> name <==` banner before each file when more than one is given; this implementation simply concatenates the per-file tails in order. With a single file operand the output matches GNU exactly.
- `-f` / `--follow` is **not implemented.** GNU `tail -f` streams new content as a file grows; the batch, EOF-terminated pipeline model used here has no streaming source, so follow mode has no place in it.
