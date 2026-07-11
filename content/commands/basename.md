---
title: basename
---

## Basename Command Compatibility

### Summary

Highly compatible with GNU `basename`. Output is byte-identical to GNU `basename` for plain paths, the `NAME SUFFIX` form, `-a`/`--multiple`, `-s`/`--suffix`, `-z`/`--zero`, and trailing-slash/degenerate paths (verified in the Docker integration harness against Debian coreutils).

### Key Behaviors

```bash
# Plain path: strip the leading directory components
$ basename /usr/local/bin/script.sh
script.sh

# NAME SUFFIX: also remove a trailing suffix operand
$ basename /usr/local/bin/script.sh .sh
script

# A suffix equal to the whole name is never removed (name is never emptied)
$ basename .txt .txt
.txt

# Trailing slashes collapse to the last path component
$ basename /path/to/dir/
dir

# Root and "." / ".." map to themselves
$ basename /
/

# -a/--multiple: every operand is a NAME, one result per line
$ basename -a /x/y /p/q.txt
y
q.txt

# -s/--suffix: implies -a and strips SUFFIX from each NAME
$ basename -s .txt a.txt /b/c.txt
a
c

# -z/--zero: terminate each record with NUL instead of newline
$ basename -az /x/y /p/q | od -An -c
   y  \0   q  \0
```

### Intentional Divergences

None — output matches GNU `basename` for the implemented flags (`-a`/`--multiple`, `-s`/`--suffix`, `-z`/`--zero`) and operand grammars (`NAME [SUFFIX]` and `OPTION... NAME...`). Single-letter flags bundle GNU-style (`-az` == `-a -z`). With no operand, `cmd-basename` exits non-zero with a `missing operand` message; a third bare operand without `-a`/`-s` is rejected as an `extra operand`, matching GNU's rejection of surplus operands.
