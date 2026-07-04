---
title: xargs
---

# Xargs Command Compatibility

## Summary

Compatible with GNU `xargs` for the implemented flags. With a command, output is byte-identical to GNU `xargs` for the default exec, `-n`, `-I`, `--null`, and `-P` behaviors (verified in the Docker integration harness against Debian findutils, using `echo` as the target). The one divergence is the short `-0` spelling.

## Key Behaviors

```bash
# Default exec: items from stdin become arguments to one command invocation
$ printf 'a b c\n' | xargs echo
a b c

# -n N: at most N items per command line; the command runs once per group
$ printf 'a b c d\n' | xargs -n 2 echo
a b
c d

# -I {}: substitute the replace-token with each whole input line, one run/line
$ printf 'a b\nc\n' | xargs -I {} echo '[{}]'
[a b]
[c]

# --null: items are NUL-separated, so an item may contain spaces
$ printf 'a b\0c d\0' | xargs --null echo
a b c d

# -P N: run up to N invocations concurrently; output stays in input order
$ printf 'a b c d\n' | xargs -P 4 -n 1 echo
a
b
c
d

# With no command, xargs regroups: split each line into whitespace fields and
# emit at most -n per output line (default one field per line)
$ printf 'one two three\n' | xargs
one
two
three
```

## Intentional Divergences

- The short `-0` spelling is not recognized: the cli/v3 flag parser stops at the first non-alphabetic short flag, so `-0` is taken as a positional command rather than the null-separator flag (the run then fails with no stdout). GNU `xargs -0` works; cmd-xargs requires the long `--null` form, which is byte-identical to GNU.
- `--null`, `-I`, and `-P` only take effect in exec mode (when a command is given). In regroup mode (no command) the input is split on newlines into whitespace fields and these flags have no effect, matching the regroup contract rather than GNU's item-parsing model.
- Implemented flag subset: `-n`/`--max-args`, `-I`/`--replace`, `-0`/`--null`, and `-P`/`--max-procs`. The GNU flags `-L` (max input lines), `-d` (custom delimiter), `-r`/`--no-run-if-empty`, `-t`/`-p` (echo/prompt commands), and the 123/124/125 child exit-status semantics are not implemented.

# cmd.xargs — Unimplemented Features

The original wave-3 features are now implemented:

- ~~Subprocess execution: run a command with grouped args~~ — done (`Xargs` exec mode; positional command, or an injected `XargsExec` factory; see `Subprocess`).
- ~~`-0` null-terminated input~~ — done (`XargsNull`).
- ~~`-I` replace string~~ — done (`XargsReplace`).
- ~~`-P` parallel execution~~ — done (`XargsMaxProcs`, order-preserving).

Remaining GNU `xargs` features not yet covered:

- `-L max-lines`: use at most N input lines per command line.
- `-d delim`: custom input delimiter (besides whitespace and `-0`).
- `-r` / `--no-run-if-empty`: skip running the command when there is no input.
- `-t`: echo each command line to stderr before running it.
- Exit-status 123/124/125 semantics on child failure.
