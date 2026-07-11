---
title: split
---

## Split Command Compatibility

### Summary

This `split` is a stream field-splitter (1:N line expansion), not GNU `split`'s file-chunker — the two share a name but nothing else, so there is no GNU reference to compare against. Each input line is expanded into multiple output lines using the `Expand` pattern: with no flag it splits on runs of whitespace (`bytes.Fields`), and with `-d`/`--delimiter` it splits on a literal delimiter (`bytes.Split`), keeping empty fields. The behaviors below were verified in the Docker integration harness.

### Key Behaviors

```bash
# Default: split on runs of whitespace; leading/trailing/collapsed runs are
# dropped, so adjacent spaces never yield empty fields.
$ printf 'hello   world\n  foo bar\n' | split
hello
world
foo
bar

# --delimiter (-d): split on the literal delimiter, KEEPING empty fields around
# adjacent delimiters. "::x" -> "", "", "x".
$ printf 'a:b:c\n::x\n' | split -d :
a
b
c


x

# Multi-character delimiters are matched literally.
$ printf 'aXYbXYc\n' | split -d XY
a
b
c

# A blank line under -d yields a single empty field (one empty output line);
# under the default whitespace split a blank line yields no fields (no output).
$ printf '\n' | split -d :

$ printf '\n' | split

# File operands are read in order; multiple files concatenate their fields.
$ split a.txt b.txt
```

### Intentional Divergences

- There is no standard Unix equivalent: GNU `split` writes input to multiple output files (`-l` lines per file, `-b` bytes per file, `-n` chunks, with `xaa`/`xab` suffixes). Those flags are deliberately not implemented — file output requires a side-effecting sink, whereas this module is a pure stream transform that fits the `Expand` pattern.
- The only flag is `-d`/`--delimiter`. The default (no flag) splits on runs of whitespace and drops empty fields (`bytes.Fields`); `-d` splits on the literal delimiter and keeps empty fields around adjacent delimiters (`bytes.Split`).
