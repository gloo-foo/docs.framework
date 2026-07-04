---
title: shuf
---

# Shuf Command Compatibility

## Summary

Behaviorally compatible with GNU `shuf` for the implemented flags. Because `shuf` writes a random permutation, output is never byte-identical to GNU `shuf`; compatibility is verified by the defining INVARIANTS (permutation, count, range, echo) in the Docker integration harness against Debian coreutils.

## Key Behaviors

```bash
# Permutation: shuffling a fixed set, then sorting, returns the input set
# (no line is lost, duplicated, or invented). Order is random per run.
$ printf 'alpha\nbeta\ngamma\ndelta\n' | shuf | sort
alpha
beta
delta
gamma

# --head-count (-n): output exactly N lines, a random subset of the input
$ printf 'a\nb\nc\nd\ne\n' | shuf -n 2 | wc -l
2

# --input-range (-i LO-HI): shuffle the integers LO..HI; sort -n recovers seq
$ shuf -i 1-9 | sort -n | tr '\n' ' '
1 2 3 4 5 6 7 8 9

# --echo (-e): shuffle the operands; sorted output equals the sorted operands
$ shuf -e red green blue | sort
blue
green
red

# Deterministic output for tests/reproducibility via --seed
$ shuf --seed 42 -e a b c
```

## Intentional Divergences

- Ordering is random by design. To make a run reproducible, use `--seed N` to seed the shuffle deterministically. This is a divergence from GNU `shuf`, which seeds reproducibility via `--random-source=FILE`; `--random-source` is not implemented.
- `-o`/`--output` (write to a file instead of stdout) and `-z`/`--zero-terminated` (NUL line delimiter) are not implemented; output goes to stdout, newline-delimited.
- The implemented flags — `-n`/`--head-count`, `-i`/`--input-range`, `-e`/`--echo` — match GNU `shuf` semantics: `-n` caps the line count, `-i LO-HI` permutes the inclusive integer range, and `-e` treats operands as input lines. Within these, behavior matches GNU `shuf`.
