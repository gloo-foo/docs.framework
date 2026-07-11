---
title: exec
---

## Exec Command Compatibility

### Summary

`exec` has no standard Unix equivalent. It is a gloo-specific, structural command: an explicit escape hatch that runs an arbitrary external program as a pipeline stage. The input stream is written to the program's stdin and the program's stdout becomes the output stream — exactly the role of a command inside a shell pipe. There is therefore no GNU/Unix `exec` reference to compare against; this document records the command's own verified contract instead.

### Key Behaviors

```bash
# Direct execution: the program's stdout becomes exec's stdout.
# `--` lets the target's own -n flag through (see Intentional Divergences).
$ exec -- echo -n hello
hello

# stdin is piped to the program's stdin; its stdout flows out.
$ printf 'hello' | exec tr a-z A-Z
HELLO

# --directory (-C): run the program in DIRECTORY.
$ exec -C /tmp pwd
/tmp

# --env (-e) with --use-shell (-s): the variable is exported to the program.
# (env/working-dir/quiet/ignore-errors route the command through a shell.)
$ exec -s -e GREETING=hi printenv GREETING
hi

# --env (-e) repeats: every variable is exported.
$ exec -s -e A=a -e B=b -- sh -c 'printf "%s-%s" "$A" "$B"'
a-b

# --shell selects the interpreter used by --use-shell.
$ exec --shell sh -s echo shelled
shelled

# Exit-status contract: success -> 0, failure -> non-zero (mapped to 1).
$ exec true   ; echo $?
0
$ exec false  ; echo $?
1

# --ignore-errors makes a failing program succeed.
$ exec --ignore-errors false ; echo $?
0

# --quiet (-q) discards the program's stderr; stdout still flows.
$ exec -s -q -- sh -c 'echo discarded >&2; printf out'
out
```

### Contract and Flags

There is no standard Unix command to mirror, so the contract is exec's own:

- **Operands** — `exec [OPTIONS] COMMAND [ARG...]`: the first positional is the program, the rest are its arguments.
- **Streams** — exec's stdin is piped to the program's stdin; the program's stdout becomes exec's stdout.
- **`-C, --directory DIR`** — run the program with `DIR` as its working directory.
- **`-e, --env NAME=VALUE`** — export an environment variable; repeatable.
- **`--shell SHELL`** — choose the interpreter used when running through a shell (default `sh`).
- **`-s, --use-shell`** — run the command line through a shell (required for the env/quoting features above to take effect).
- **`--ignore-errors`** — succeed (exit 0) even if the program exits non-zero.
- **`-q, --quiet`** — discard the program's stderr.

When no shell-requiring flag is set the program is executed directly; otherwise it is run through a POSIX shell so the flags can take effect.

### Intentional Divergences

There is no standard Unix `exec` utility to diverge from, so "parity" is not applicable. The behaviors worth noting against shell intuition are:

- **`--` is required to pass dash-prefixed arguments to the target.** Leading dash tokens are parsed as exec's own flags (urfave/cli), so `exec echo -n hi` fails on the unknown `-n`; write `exec -- echo -n hi`. Tokens after the program name that are not dash-prefixed need no separator.
- **A non-zero program exit is reported as exit status 1**, not the program's own code, unless `--ignore-errors` is set (which forces exit 0). A missing command operand and a nonexistent program both exit 1.
- **Shell-mediated flags imply a shell.** `--directory`, `--env`, `--quiet`, and `--ignore-errors` route the command through a POSIX shell; without `-s`/`--shell` the bare program is executed directly and those flags have nothing to act through.
