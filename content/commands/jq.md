---
title: jq
---

# Jq Command Compatibility

## Summary

`cmd-jq` is a thin wrapper around the real `jq` binary, not a reimplementation: it forks `jq`, forwards the argument vector verbatim, pipes pipeline input to jq's stdin, and streams jq's stdout onward. For the invocations it forwards, output is jq's own and matches real `jq` exactly. The library constructor `Jq(args...)` performs no parsing or validation of its own — `jq`, not this wrapper, interprets every argument (the filter expression and any flags).

## Key Behaviors

```go
// The library exposes a single constructor that builds a composable Command.
// Each example below shows the argument vector forwarded to jq verbatim.

jq.Jq(".")                       // forks: jq .
jq.Jq("-c", ".items[]")          // forks: jq -c .items[]
jq.Jq("-r", ".name")             // forks: jq -r .name
jq.Jq("--arg", "k", "v", "$k")   // forks: jq --arg k v $k
jq.Jq("-n", "now")               // forks: jq -n now
```

Pipeline input is written to jq's stdin and jq's stdout becomes the Command's output stream, exactly as `jq` behaves as a stage in a shell pipe. Stderr passes through to the parent. Non-zero exit codes propagate as errors. A downstream stop or context cancellation closes the pipes and signals the child (SIGTERM, escalating to SIGKILL after a grace period), mirroring shell SIGPIPE semantics — so `jq | Take(3)` terminates jq promptly.

## Intentional Divergences

There is no standard parity contract beyond "fork jq and forward." The library constructor's contract is total argument-vector passthrough:

- **Full flag passthrough.** Unlike a constrained `urfave/cli` front end, the `Jq(args...)` constructor forwards every token verbatim — filter expressions and flags alike (`-c`, `-r`, `-n`, `-s`, `--arg`, `--argjson`, `--slurpfile`, …). The wrapper neither defines nor rejects flags; jq sees the exact vector it was given.
- **No filter is jq's own behavior.** A bare `Jq()` (no arguments) forks `jq` with no filter; the resulting behavior (jq reading and echoing input under its default filter) is jq's, not the wrapper's — the wrapper imposes no usage error of its own.

The wrapper follows the gloo pipeline model: a finite upstream source is streamed to jq's stdin, so it is intended for pipeline composition rather than interactive use.
