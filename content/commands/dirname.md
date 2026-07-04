---
title: dirname
---

# Dirname Command Compatibility

## Summary

Highly compatible with GNU `dirname`. Output is byte-identical to GNU `dirname` for every operand form — absolute paths, relative paths, trailing slashes, multiple operands, and the root/edge cases — verified in the Docker integration harness against Debian coreutils.

## Key Behaviors

```bash
# Strip the last component of an absolute path
$ dirname /usr/local/bin/script.sh
/usr/local/bin

# A path with no '/' yields '.' (the current directory)
$ dirname filename
.

# Trailing slashes are stripped before and after dropping the last component
$ dirname /usr/local/bin///
/usr

# Root and repeated-slash edge cases collapse to '/'
$ dirname /
/
$ dirname ///
/

# Interior separators are preserved; "." / ".." are not resolved
$ dirname a//b//c
a//b
$ dirname /foo/..
/foo

# Multiple operands: one output line per NAME
$ dirname /usr/local/bin/script.sh /var/log/app.log
/usr/local/bin
/var/log
```

## Intentional Divergences

- GNU `dirname` requires at least one operand and errors when given none. cmd-dirname instead reads newline-separated paths from standard input when no operands are given, applying the same dirname transform to each line. With one or more operands, behavior is byte-identical to GNU `dirname`.
- The GNU `-z`/`--zero` flag (NUL-terminate each output line instead of newline) is not implemented; cmd-dirname always separates outputs with newlines.
