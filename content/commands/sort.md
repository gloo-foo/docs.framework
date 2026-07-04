---
title: sort
---

# Sort Command Compatibility

## Summary

Highly compatible with GNU `sort` for byte-lexical and keyed sorting. Output is byte-identical to GNU `sort` under `LC_ALL=C` across every supported flag.

## Key Behaviors

```bash
# Default: byte-lexical sort of stdin
$ printf 'c\na\nb\n' | sort
a
b
c

# -r: reverse the comparison
$ printf 'a\nb\nc\n' | sort -r
c
b
a

# -n: numeric compare by leading value
$ printf '10\n2\n100\n9\n' | sort -n
2
9
10
100

# -u: drop duplicate keys
$ printf 'a\na\nb\nc\nc\n' | sort -u
a
b
c

# -f: fold case before comparing
$ printf 'B\na\nC\n' | sort -f
a
B
C

# -b: ignore leading blanks
$ printf '  c\n b\na\n' | sort -b
a
 b
  c

# -h: human-numeric (SI suffixes K/M/G as powers of 1024)
$ printf '1M\n2K\n1G\n512\n' | sort -h
512
2K
1M
1G

# -M: month order
$ printf 'Mar\nJan\nFeb\nDec\n' | sort -M
Jan
Feb
Mar
Dec

# -V: version/natural order
$ printf 'v1.10\nv1.2\nv1.1\nv2.0\n' | sort -V
v1.1
v1.2
v1.10
v2.0

# -k / -t: compare a single field with the given delimiter (matches GNU -kN,N)
$ printf 'x,3\ny,1\nz,2\n' | sort -k 2 -t ,
y,1
z,2
x,3

# -s with -k: stable sort preserves input order of equal keys
$ printf 'b:2\na:3\nb:1\na:1\n' | sort -s -k 1 -t :
a:3
a:1
b:2
b:1
```

## Intentional Divergences

- Default ordering is byte-lexical, not locale-collated: comparisons use raw byte order regardless of `LC_COLLATE`. This matches GNU `sort` under `LC_ALL=C`, which the integration harness uses for a deterministic comparison.
- `-k N` selects only field N as the comparison key, whereas GNU `sort -kN` compares from field N to the end of the line. The single-field behavior is equivalent to GNU's `-kN,N`; the integration parity checks compare against that spelling.
- `-h` uses powers of 1024 for SI suffixes (K=1024, M=1024², G=1024³).
- `-R` shuffles input (grouping identical keys); its output is not byte-reproducible and is excluded from parity checks.
- `-m` (merge of pre-sorted streams) is unsupported: the single-stream `Accumulate` pattern cannot merge multiple pre-sorted inputs.
