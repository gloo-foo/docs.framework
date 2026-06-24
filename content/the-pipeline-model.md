---
title: The-Pipeline-Model
---

# The Pipeline Model

*Audience: everyone. This is the conceptual foundation the rest of the wiki builds on.*

A gloo pipeline is always the same shape:

```
 Source ──▶ Command ──▶ Command ──▶ … ──▶ Sink
        Stream[A]    Stream[B]      Stream[Y]
```

Four types capture it, all defined in [`framework.go`](https://github.com/gloo-foo/framework/blob/main/framework.go). This page defines each one, shows how data flows through them, and explains the two execution models you'll meet.

---

## The four core types

### `Stream[T]` — the pipe

```go
type Stream[T any] // a channel of values-or-errors, carrying a teardown handle
```

A stream is the wire between stages. Conceptually it's a sequence of items, each of which is either a **value** of type `T` or an **error**. It also carries the machinery to tear the pipeline down cleanly when a consumer stops early — covered in depth in **[Concurrency & Lifecycle](Concurrency-and-Lifecycle)**.

A consumer has exactly three operations, and all three are leak-free:

| Operation | Use |
|---|---|
| range over `Chan()` | low-level iteration (Command Authors only) |
| `Collect() ([]T, error)` | gather every item into a slice |
| `Discard()` | abandon a stream you won't finish reading |

There is deliberately **no bare "stop"** method — see [why](Concurrency-and-Lifecycle#why-there-is-no-stop).

### `Command[In, Out]` — a stage

```go
type Command[In, Out any] interface {
    Execute(ctx context.Context, input Stream[In]) Stream[Out]
}
```

A command consumes a `Stream[In]` and produces a `Stream[Out]`. The input and output element types can differ (`tr` keeps `string→string`; `wc -l` is `string→int`). Commands are **values**: you build one, then reuse it across as many pipelines as you like.

### `Source[Out]` — an origin

```go
type Source[Out any] interface {
    Stream(ctx context.Context) Stream[Out]
}
```

A source produces a stream from outside the pipeline — an in-memory slice, files on a filesystem, a set of `io.Reader`s. See the [sources catalog](For-Command-Authors#sources).

### `Sink[In, Res]` — a terminus

```go
type Sink[In, Res any] interface {
    Consume(ctx context.Context, input Stream[In]) (Res, error)
}
```

A sink drains the final stream and returns a typed result — a line count from `WriteTo`, a slice from `Collect`, a checksum, anything.

---

## How data flows

Items travel one at a time, lazily, and concurrently. When you wire `Source → Map → Filter → Sink`, you don't first compute the whole source and then map it; instead every stage runs in its own goroutine and items stream through. This is what lets a pipeline process input larger than memory and start producing output before the input has ended — exactly like a shell pipe.

Two consequences worth internalizing:

- **Backpressure is automatic.** A slow sink slows the whole chain; a fast source doesn't run away, because each stream has a small buffer (mirroring a shell pipe's kernel buffer) and then blocks.
- **Errors ride the stream.** An error doesn't unwind a call stack — it travels as an item. The first error a consumer sees stops the pipeline and is returned. See [Errors & Testing](Errors-and-Testing#how-errors-flow).

---

## Two execution models

Gloo gives you two ways to assemble a pipeline. They differ in *when* type checking happens and *whether* the result is reusable.

### Immutable values — checked at compile time

`Pipe` and `Compose` build pipelines as **immutable values** whose types the Go compiler verifies:

```go
cmd := gloo.Pipe(parse, double)   // Command[string,int] + Command[int,int] → Command[string,int]
```

If `parse` produced a type `double` couldn't accept, your code **wouldn't compile**. These values are safe to copy, alias, and run concurrently across pipelines. Reach for them when you want maximum safety and reuse.

### The fluent builder — checked at build time

`Chain` and `Run` offer a fluent, type-*changing* syntax:

```go
gloo.Chain(src).To(grep).To(sort).Sink(out)
```

Because Go has no generic methods yet, this builder is reflection-based and accepts `any`, so the compiler can't verify that the stages line up. Instead, gloo validates the types as you build — and reports a mismatch as a **returned error** you match with `errors.Is`, never a panic:

```go
_, err := gloo.Chain(src).To(wrongTypedCmd).Collect()
// errors.Is(err, gloo.ErrStageTypeMismatch) == true
```

The fluent builder (`FluentPipeline`) is a **single-owner, mutable** value: build it, call one terminal, discard it. Reach for it when you want the ergonomic syntax and are comfortable trading compile-time checking for a clear runtime error.

> When generic methods land ([golang/go#77273](https://github.com/golang/go/issues/77273)), the fluent builder becomes compile-time-checked too and this distinction disappears.

---

## Where to go next

- Composing and running pipelines → **[For Command Users](For-Command-Users)**
- Building the commands themselves → **[For Command Authors](For-Command-Authors)**
- The teardown guarantee that makes all of this leak-free → **[Concurrency & Lifecycle](Concurrency-and-Lifecycle)**
