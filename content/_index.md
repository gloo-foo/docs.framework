---
title: framework
---

# Gloo Framework

**Fluent shell pipes for Go.** Gloo expresses the Unix pipeline model as type-safe, composable Go values. A command is a value — you assign it, pass it around, and compose it — and the pipeline you build reads like a shell one-liner while staying fully typed, concurrent, and testable without ever touching real I/O.

```go
gloo.Run(
    gloo.SliceSource([]string{"error: a", "info: b", "error: c"}),
    gloo.WriteTo(os.Stdout),
    grep("error"),          // a Command[string, string]
    patterns.Head[string](1),
)
// error: a
```

That's the whole idea: a **source** of data, a chain of **commands** that transform it, and a **sink** that consumes it — connected by a **stream** that behaves exactly like a shell pipe, down to the SIGPIPE-style teardown when a downstream stage stops early.

Built on [rill](https://github.com/destel/rill) for stream plumbing and [afero](https://github.com/spf13/afero) for filesystem abstraction.

| | |
|---|---|
| **Module** | `github.com/gloo-foo/framework` |
| **Package** | `gloo` (+ subpackage `gloo-foo/framework/patterns`) |
| **API reference** | [pkg.go.dev/github.com/gloo-foo/framework](https://pkg.go.dev/github.com/gloo-foo/framework) |

---

## The one mental model

Everything in gloo is this shape:

```
 Source ──▶ Command ──▶ Command ──▶ … ──▶ Sink
        Stream[A]    Stream[B]      Stream[Y]
```

- A **`Source[Out]`** produces a stream from external data (a slice, files, readers).
- A **`Command[In, Out]`** transforms one stream into another.
- A **`Sink[In, Res]`** consumes the final stream and returns a typed result.
- A **`Stream[T]`** is the pipe between stages — a channel of values-or-errors that carries its own teardown.

Hold that picture and the rest of the framework falls into place. The four types are defined in [`framework.go`](https://github.com/gloo-foo/framework/blob/main/framework.go); they're explored in depth on **[The Pipeline Model](The-Pipeline-Model)**.

---

## Which reader are you?

Gloo has two audiences. Pick your track — they share the vocabulary above but touch different parts of the API.

### 🧑‍🍳 Command Users — *compose and run*

You take prebuilt commands and wire them into pipelines. You never see `rill`, never write a `FuncCommand`, never touch a raw stream. This is the product; everything else exists to make it pleasant.

→ **[For Command Users](For-Command-Users)**

### 🔧 Command Authors — *build the commands*

You write the commands Users compose. You pick a **pattern** and supply only your algorithm — the pattern owns all stream wiring, channels, and cancellation.

→ **[For Command Authors](For-Command-Authors)**

Whichever you are, read **[Concurrency & Lifecycle](Concurrency-and-Lifecycle)** once. It's short, it's the framework's most carefully engineered guarantee, and it explains why a gloo pipeline tears down cleanly the way a shell pipe does — with no way to leak a goroutine.

---

## Sixty-second start

```go
package main

import (
    "os"
    "strings"

    gloo "github.com/gloo-foo/framework"
    "github.com/gloo-foo/framework/patterns"
)

func main() {
    // A command is just a value built from a pattern.
    shout := patterns.Map(func(line string) (string, error) {
        return strings.ToUpper(line), nil
    })

    // Compose a source, a sink, and commands; run once.
    gloo.Run(
        gloo.SliceSource([]string{"hello", "world"}),
        gloo.WriteTo(os.Stdout),
        shout,
    )
    // HELLO
    // WORLD
}
```

To run a pipeline as a real Unix filter (stdin → stdout), use [`Pump`](For-Command-Users#run-it-as-a-unix-filter--pump).

---

## Map of the wiki

| Page | What it covers | For |
|---|---|---|
| **[The Pipeline Model](The-Pipeline-Model)** | The four core types, how data flows, lazy vs. eager wiring, values vs. builders | Everyone |
| **[For Command Users](For-Command-Users)** | `Run`, `Chain`, `Compose`, `Pipe`, `Pump`; the error model | Users |
| **[For Command Authors](For-Command-Authors)** | The pattern catalog + decision matrix; building commands; `FuncCommand` for exotic cases | Authors |
| **[Concurrency & Lifecycle](Concurrency-and-Lifecycle)** | The teardown contract, `Discard`, silent stop vs. surfaced cancellation, what's safe to share | Everyone |
| **[Errors & Testing](Errors-and-Testing)** | Sentinel errors, how errors flow, testing commands with in-memory streams | Everyone |

---

## Resources

- **API reference (godoc):** [pkg.go.dev/github.com/gloo-foo/framework](https://pkg.go.dev/github.com/gloo-foo/framework)
- **Runnable examples:** [`example_test.go`](https://github.com/gloo-foo/framework/blob/main/example_test.go)
- **End-to-end suite:** [`verification/`](https://github.com/gloo-foo/framework/tree/main/verification)
- **rill** (stream engine): [github.com/destel/rill](https://github.com/destel/rill) · **afero** (filesystem): [github.com/spf13/afero](https://github.com/spf13/afero)
- **Roadmap:** when Go ships [generic methods (golang/go#77273)](https://github.com/golang/go/issues/77273), the reflection-based fluent `.To()` becomes a compile-time-checked `.To[Next]()` and `Pipe` becomes unnecessary — the User-facing syntax won't change.
