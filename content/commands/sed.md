---
title: sed
---

## Sed Command Compatibility

### Summary

Partially compatible with GNU `sed`: it implements only the `s///` substitution command (with the `g`, `i`, `p`, and `N` flags) and uses Go's RE2 regular-expression engine, not GNU's BRE/ERE. Plain substitutions whose syntax is shared by both engines match GNU exactly; anything relying on BRE syntax, GNU `\1`/`&` replacements, addressing, or non-`s` commands diverges.

### Key Behaviors

```bash
# Basic first-occurrence substitution
$ printf 'aaa\n' | sed 's/a/x/'
xaa

# Global flag g: every match on the line
$ printf 'banana\n' | sed 's/a/x/g'
bxnxnx

# Ignore-case flag i
$ printf 'ABC\n' | sed 's/abc/x/i'
x

# Nth-match flag N: replace only the 2nd match
$ printf 'aaa\n' | sed 's/a/x/2'
axa

# Print flag p: emit the line again when a substitution fired
$ printf 'abc\n' | sed 's/b/X/p'
aXc
aXc

# Any byte may delimit the script
$ printf 'hello\n' | sed 's|l|L|g'
heLLo

# Anchors and "any char" behave as in GNU
$ printf 'cat\n' | sed 's/^/> /'
> cat
$ printf 'cat\n' | sed 's/$/!/'
cat!

# SCRIPT followed by one or more FILE operands (stdin when none given)
$ sed 's/world/universe/' in.txt
hello universe
```

### Intentional Divergences

- **Regular-expression flavor is Go RE2, not GNU BRE.** RE2 is ERE-like, so `+`, `?`, `|`, `(` and `)` are operators with no backslash. GNU `sed`'s default is BRE, where those are literals (and groups are `\( \)`). Consequences:
  - `s/[0-9]+/N/` on `foo123` yields `fooN` here, but GNU BRE treats `+` literally and leaves the line unchanged.
  - `s/(a)b/X/` on `ab` yields `X` here (`( )` form a group), but GNU BRE treats `( )` as literals and does not match.
- **Replacement back-references use Go syntax (`$1`, `${1}`), not GNU `\1`.** `s/(a)(b)/${2}${1}/` on `ab` yields `ba`; a GNU-style `s/.../[\1]/` leaves the literal text `[\1]` because RE2 does not expand `\1`.
- **`&` in the replacement is literal**, not "the whole match". `s/c/[&]/` on `cat` yields `[&]at`; GNU yields `[c]at`. Use a capture group plus `$0`/`${0}` for whole-match insertion.
- **Only the `s///` command is supported.** Any other GNU `sed` command (`d`, `p` as a standalone, `y///`, `a`/`i`/`c`, etc.) fails the stream with the sentinel `sed: unsupported expression`.
- **No line addressing.** Addresses (`1d`, `/re/d`, `2,5s/.../.../`, `$`, `0~3`) are not parsed; the substitution always applies to every line.
- **No command-line options.** GNU flags such as `-n`, `-e`, `-E`/`-r`, `-i`, `-f`, and `-z` are not accepted; the first operand is the SCRIPT and the rest are FILEs. (`--version` and `--help` are provided by the CLI wrapper.)
