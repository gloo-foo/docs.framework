---
title: For-Command-Users
---

# For Command Users

*Audience: you compose prebuilt commands into pipelines and run them. You never touch `rill`, a `FuncCommand`, or a raw stream.*

A **command** is a value — built once, reused anywhere. Your job is to wire commands between a source and a sink. Gloo gives you four ways to compose and one way to run a pipeline as a Unix filter. This page covers each, with guidance on when to reach for which.

> New here? Read [The Pipeline Model](The-Pipeline-Model) first — it defines `Source`, `Command`, `Sink`, and `Stream` in two minutes.

---

## `Run` — one-shot pipeline

The shortest path. Pass a source, a sink, then the commands in order; gloo wires and runs them.

```go
src := gloo.SliceSource([]string{"hello", "world"})
shout := patterns.Map(func(line string) (string, error) {
    return strings.ToUpper(line), nil
})

gloo.Run(src, gloo.WriteTo(os.Stdout), shout)
// HELLO
// WORLD
```

`Run` returns `(any, error)` — the sink's result and the first error the pipeline produced. Use `RunContext(ctx, …)` to pass a context (for cancellation or deadlines).

## `Chain` — fluent builder

Reads top-to-bottom and offers three terminals: `.Sink()`, `.Collect()`, and `.ForEach()`.

```go
src := gloo.SliceSource([]string{"apple red", "banana yellow", "cherry red"})

result, err := gloo.Chain(src).
    To(keep("red")).
    To(shout).
    Collect()
// result.([]string) == ["APPLE RED", "CHERRY RED"]
```

| Terminal | Returns | Use |
|---|---|---|
| `.Collect()` | `(any, error)` — a `[]T` as `any` | gather every item |
| `.Sink(sink)` | `(any, error)` — the sink's result | write out, count, reduce |
| `.ForEach(fn)` | `error` | run a side-effect per item |

Use `ChainContext(ctx, src)`, `.ToContext(ctx, cmd)`, and `.SinkContext(ctx, sink)` for per-stage context control.

Two things to know about `Chain`:

- **It's lazy.** Nothing runs — no goroutine starts, nothing leaks — until you call a terminal. A chain you build and throw away costs nothing.
- **It validates as you build, and reports problems as errors, never panics.** If a stage's input type doesn't match the previous stage's output, the terminal returns a matchable error:

  ```go
  _, err := gloo.Chain(src).To(wrongTypedCmd).Collect()
  if errors.Is(err, gloo.ErrStageTypeMismatch) { … }
  ```

  See [the full list of fluent errors](Errors-and-Testing#fluent-builder-errors).

> `Chain` is a single-owner, mutable builder. Don't share it across goroutines, and call exactly one terminal — afterwards it's consumed (`ErrPipelineConsumed`).

## `Compose` — reusable same-type chain

When every stage shares one element type, `Compose` builds an **immutable, reusable** `Command[T, T]` you can drop into other pipelines:

```go
clean := gloo.Compose(trim).To(dropBlanks).To(shout) // Command[string, string]

// Reuse it anywhere, even concurrently — it's an immutable value.
gloo.Run(src1, sink1, clean)
gloo.Run(src2, sink2, clean)
```

Each `.To()` returns a *new* `Pipeline`; the original is never mutated.

## `Pipe` — binary, type-changing, compile-time-checked

`Pipe` composes two commands whose types chain, and the compiler verifies it:

```go
// string → int → string
pipeline := gloo.Pipe(gloo.Pipe(parse, double), format)
```

If the types didn't line up, this wouldn't compile. `Pipe` produces an immutable value, like `Compose`. Reach for `Pipe`/`Compose` when you want the strongest guarantee; reach for `Chain`/`Run` when you want the fluent syntax. (See [the two execution models](The-Pipeline-Model#two-execution-models) for the trade-off.)

---

## Run it as a Unix filter — `Pump`

To turn a composed command into a real command-line tool that reads stdin and writes stdout, use `Pump`. Nothing is shelled out; the work stays in-process.

```go
func main() {
    upper := patterns.Map(strings.ToUpper) // Command[string, string]
    if _, err := gloo.Pump(context.Background(), upper, os.Stdin, os.Stdout); err != nil {
        log.Fatal(err)
    }
}
```

`PumpBytes` is the same for a `Command[[]byte, []byte]` (the byte pipeline used by most `cmd-*` tools).

---

## Choosing a composition style

| Want… | Use |
|---|---|
| the quickest run of source→cmds→sink | `Run` |
| a fluent, readable, type-*changing* chain | `Chain` |
| a reusable building block, all one type | `Compose` |
| a reusable, type-changing pair, compiler-checked | `Pipe` |
| to ship it as a stdin→stdout tool | `Pump` / `PumpBytes` |

---

Next: the commands you're composing are built from **patterns** — see **[For Command Authors](For-Command-Authors)**. And read **[Concurrency & Lifecycle](Concurrency-and-Lifecycle)** to understand why every one of these terminals tears the pipeline down cleanly.
