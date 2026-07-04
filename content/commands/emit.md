---
title: emit
---

# Emit Command Compatibility

## Summary

`emit` is a gloo-specific pipeline source with no standard Unix equivalent; the closest analogy is `echo`/`printf` (or `yes`) used to seed a pipeline with fixed content.

## Key Behaviors

```bash
# Single line of stdout content emits one item
$ emit "Hello, World!"
Hello, World!

# Multi-line content emits one item per line (trailing newline trimmed)
$ emit "line one\nline two"
line one
line two

# Empty content emits nothing (zero items)
$ emit ""

# stdout flows down the pipeline; stderr is emitted on a separate side channel
$ emit "output message" --stderr "error message"
output message            # stdout (pipeline stream)
error message             # stderr (side channel, newline-terminated)
```

## Intentional Divergences

There is no Unix `emit`; it is a structural source for the gloo framework rather than a command-line tool. Its contract:

- It emits fixed, in-memory content as a `Source[[]byte]`, one pipeline item per line. The stdout string is split on `\n` after trimming a single trailing newline, so `"a\nb"` and `"a\nb\n"` both yield exactly two items (`a`, `b`) with no trailing empty item. Empty content emits zero items, not one empty item.
- Unlike `echo`/`printf`, it does not interpret escapes, format directives, or flags against the content — the string is emitted verbatim, line by line. Unlike `yes`, it emits its content once and stops; it is not an infinite repeater.
- It carries an independent stderr side channel (`EmitStderr`) that is written as a one-shot side effect to a destination (`os.Stderr` by default, redirectable with `EmitStderrTo`) when the source runs, not mixed into the pipeline stream. Stderr content is newline-terminated exactly once: a value already ending in `\n` is written verbatim, otherwise a single `\n` is appended.
