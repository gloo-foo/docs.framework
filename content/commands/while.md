---
title: while
---

# While Command Compatibility

## Summary

`while` has **no standard Unix equivalent**: it is a gloo-specific stream-control command, and the shell `while` is a language builtin, not a program. There is therefore nothing to be byte-compatible *with*. Instead, `while` defines its own contract — it reads standard input line by line and runs a body for each line — which the `cmd-while` CLI surfaces by running an operand COMMAND once per line. The behavior below was verified in the Docker integration harness (Debian coreutils), which is assert-only (no GNU reference).

## Contract

`while COMMAND [ARG...]` reads standard input line by line. For each input line it runs `COMMAND [ARG...]`, pipes that line to the command's standard input, and replaces the line with the command's standard output (with a single trailing newline trimmed). The transformed lines are emitted in input order, one per line. Empty input produces no output. The underlying `cmd-while` package exposes `While(body func([]byte) ([]byte, error))`, where the body is the per-line transform; the CLI's body is "run the operand command, return its stdout".

## Key Behaviors

```bash
# Uppercase each line: the body command's stdout replaces the line
$ printf 'alpha\nbeta\n' | while tr a-z A-Z
ALPHA
BETA

# Reverse each line
$ printf 'abc\nxyz\n' | while rev
cba
zyx

# Body command with arguments (sed substitution, applied per line)
$ printf 'one\ntwo\n' | while sed 's/one/X/'
X
two

# A constant-output body replaces every line with the same text
$ printf 'a\nb\nc\n' | while echo z
z
z
z

# Identity body (cat) round-trips each line; one trailing newline is trimmed
$ printf 'keep\nthese\n' | while cat
keep
these

# Empty input emits nothing
$ printf '' | while tr a-z A-Z

# No COMMAND operand is a usage error (exit 1)
$ printf 'alpha\n' | while; echo $?
while: no command given
1

# A body command that cannot be run exits 1
$ printf 'alpha\n' | while definitely-not-a-real-command-xyz; echo $?
1
```

## Intentional Divergences

No standard Unix `while` binary exists, so there is no reference to diverge from. The notable contract points (not divergences, but behaviors a caller should know):

- The body command is re-executed once per input line (a fresh process per line), and each line is delivered on the command's standard input — the line is *not* passed as an argument.
- Exactly one trailing newline is trimmed from each body command's standard output before it becomes the replacement line; bodies that emit multiple lines therefore widen the stream.
- A missing COMMAND operand yields the sentinel `no command given` (exit 1); a body command that fails to run or exits non-zero propagates as exit 1.
