---
title: tac
---

# Tac Command Compatibility

## Summary

Compatible with GNU `tac` for the common case — reversing the line order of stdin or a single file is byte-identical. Multiple file operands and the `-s` record separator diverge by design (verified in the Docker integration harness against Debian coreutils).

## Key Behaviors

```bash
# Reverse the order of lines read from stdin (identity-after-reversal)
$ printf 'alpha\nbeta\ngamma\n' | tac
gamma
beta
alpha

# A single record passes through unchanged
$ printf 'solo\n' | tac
solo

# Empty input yields empty output
$ printf '' | tac

# Reverse a single file's lines
$ tac a.txt        # a.txt = one\ntwo\nthree
three
two
one
```

## Intentional Divergences

- **Multiple file operands.** GNU `tac` reverses each file's lines independently and emits the reversed files in operand order. `tac` (this command) instead concatenates every operand into one stream and reverses that stream as a whole. For operands `b.txt` (`red\ngreen\nblue`) then `a.txt` (`one\ntwo\nthree`), GNU yields `blue green red / three two one` while this command yields `three two one / blue green red` (the full reversal of the concatenation `red green blue one two three`).
- **`-s` record separator.** GNU `tac -s SEP` treats `SEP` as a trailing record terminator and preserves it on each emitted record, so `printf 'a:b:c\n' | tac -s :` yields `c\nb:a:`. This command instead joins the input on newlines, splits on the literal separator, reverses the records, and rejoins them with newlines, so the same input yields `c\nb\na\n` — the separators are replaced by newlines rather than preserved. Only the `-s`/`--separator` flag is implemented; GNU's `-b`/`--before` (attach separator before each record) and `-r`/`--regex` (treat the separator as a regular expression) are not.
