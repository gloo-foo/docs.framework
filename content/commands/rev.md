---
title: rev
---

# Rev Command Compatibility

## Summary

Fully compatible with util-linux `rev` for ASCII input. Output is byte-identical to util-linux `rev` for single lines, multiple lines, empty input, and single/multiple file operands (verified in the Docker integration harness against Debian's util-linux `rev`).

## Key Behaviors

```bash
# Reverse the characters of each line from stdin
$ printf 'Hello World\n' | rev
dlroW olleH

# Each line is reversed independently
$ printf 'abc\n12345\n' | rev
cba
54321

# Empty input yields empty output
$ printf '' | rev

# File operands are read in order; with no operand (or "-"), stdin is read
$ rev a.txt b.txt
```

## Intentional Divergences

None — output matches util-linux `rev` for ASCII input. rev takes no flags. Reversal is performed over Unicode runes rather than raw bytes, so multi-byte UTF-8 characters reverse codepoint-wise (a correctness improvement over byte-wise reversal); for ASCII the two are identical.
