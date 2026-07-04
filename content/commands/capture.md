---
title: capture
---

# Capture Command Compatibility

## Summary

A gloo-specific structural command with no standard Unix equivalent: it taps a pipeline, copying every line into one or more in-process `io.Writer` buffers while passing the line through unchanged.

## Key Behaviors

```bash
# Capture the stream into a buffer while it passes through unchanged
Capture(&buf) <<< "Hello, World!"
# buf -> "Hello, World!\n"

# All stream lines land in a single buffer (each newline-terminated)
Capture(&merged) <<< "one\ntwo\nthree"
# merged -> "one\ntwo\nthree\n"

# One call fans the stream out to several writers; each gets every line
Capture(&a, &b) <<< "data"
# a -> "data\n"   b -> "data\n"

# No writers: pure pass-through (lines flow, nothing captured)
Capture() <<< "x\ny"
# 2 lines pass through; nothing written

# Mid-pipeline tap: the buffer sees the stream, which still flows on
Pipe(Capture(&mid), Capture()) <<< "x\ny"
# 2 lines passed through; mid -> "x\ny\n"
```

## Intentional Divergences

There is no Unix reference for this command; its contract is defined entirely by the framework:

- `Capture` is a **Tap** (`patterns.Tap`): writing to the buffers is a side effect, and each line continues downstream unchanged after being written. Inserting it anywhere in a pipeline never alters the stream.
- It is configured purely by the variadic `io.Writer` arguments passed to `Capture(writers ...io.Writer)`; it has **no flags**. With no writers it degenerates to a pass-through.
- Each line is written **newline-terminated** to every writer, so a captured buffer reconstructs the line-delimited stream verbatim.
- Writers are written in argument order; the first `Write` error (on either the line or its trailing newline) aborts the pipeline and propagates, and later writers are not written for that line.
- Unlike `tee`, which duplicates a byte stream to files or stdout, `Capture` taps into in-process Go `io.Writer` buffers for programmatic reuse later in the same pipeline. Unlike shell command substitution (`$(...)`), it does not consume the stream into a value and stop the flow — the stream keeps flowing downstream while a copy accumulates in the buffer.
