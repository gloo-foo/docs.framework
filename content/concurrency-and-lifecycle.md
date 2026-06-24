---
title: Concurrency-and-Lifecycle
---

# Concurrency & Lifecycle

*Audience: everyone — it's short, and it's the guarantee that makes gloo trustworthy. Authors writing a `FuncCommand` should read all of it.*

A gloo pipeline runs every stage in its own goroutine and streams items through concurrently. That raises the obvious question: **when a pipeline ends — normally, early, or under cancellation — does everything shut down, or do goroutines leak?**

The answer is that gloo makes clean teardown the *only* possibility. There is no API by which you can leak a producer. This page explains how.

---

## The shell analogy

Think of a shell pipeline:

```sh
yes | head -3 | sort
```

`head` prints three lines and exits. Its exit closes the pipe, so the next time `yes` writes, it dies of `SIGPIPE`. The pipeline ends cleanly even though `yes` is "infinite," and `sort` still sorts its three lines. No process is left running.

Gloo reproduces this exactly. When a downstream stage stops reading, every stage **upstream** of it tears down and exits; stages **downstream** are unaffected. `infinite | Take(3) | sort` sorts three items and leaves nothing running.

---

## A consumer's three safe operations

A `Stream[T]` gives a consumer exactly three things to do, and **all three are leak-free**:

| Operation | Meaning |
|---|---|
| range over `Chan()` to completion | read every item |
| `Collect() ([]T, error)` | gather every item into a slice |
| `Discard()` | abandon a stream you won't finish reading |

If you read a stream to the end (via `Chan()` or `Collect()`), teardown is automatic. If you want to stop early, you call `Discard()`.

### Why there is no `Stop`

You might expect a `Stop()` method to "just stop the upstream." Gloo deliberately doesn't have one, and that's a safety feature.

Stopping the upstream is only half of a correct early-exit. The producers between you and the source — pure transform stages like `Map` and `Filter` — have no cancellation hook of their own; they end only when their *input* closes. If you signalled "stop" but then stopped reading, a producer blocked mid-send would wait forever on a send nobody receives. **That's the leak.** The correct early-exit is always *stop **and** drain*: signal the upstream, then keep reading until the channel closes so every blocked producer can run to completion.

`Discard()` **is** that fused "stop and drain." Because the unsafe half (stop-without-drain) is never exposed, you can't write the leak. The high-level terminals — `Run`, `Chain().Collect()/.Sink()/.ForEach()`, and `Into` — all call `Discard` for you on the early-exit and error paths. You only manage it by hand when consuming a raw `Stream`, and even then the only tool you have is the safe one:

```go
stream := gloo.From(ctx, src, cmd)
defer stream.Discard()        // safe to call even after full consumption (no-op)
results, err := stream.Collect()
```

---

## Silent stop vs. surfaced cancellation

Not every "the stream ended" is a failure. Gloo distinguishes two causes, because a shell does:

- **Downstream stop** (a consumer called `Discard`, the SIGPIPE case): the producer closes **silently** — no error item. A pipeline isn't a failure just because `head` exited early (a shell without `pipefail` agrees). Internally this is the sentinel `ErrStopReading`.
- **External cancellation** (`ctx` cancelled — `^C`, a deadline): the cause is surfaced **exactly once** as a stream error item, then the stream closes. (Unless the producer already emitted its own error, in which case that one wins — no piling on.)
- **Natural completion**: the stream simply closes.

So a consumer can tell "I stopped this" (no error) from "something cancelled this" (one `context.Canceled`/deadline error) just by reading the stream.

---

## What's safe to share, and what isn't

| Value | Guarantee |
|---|---|
| `Command`, `Source`, `Sink` | **Immutable values.** Safe to copy, alias, and run concurrently across pipelines. |
| `Pipe`, `Compose`/`Pipeline`, `FuncCommand` | Immutable values — same guarantee. |
| `Stateful*` commands | Reusable because the factory mints fresh state per `Execute`. |
| `Stream[T]` | **Single consumption.** One consumer drains it once. |
| `FluentPipeline` (from `Chain`) | **Single-owner, mutable, consumed once.** Build → one terminal → discard. Don't share across goroutines. |
| Sinks (`WriteTo`, `ByteWriteTo`) | **Single consumer only** — they wrap a stateful `bufio.Writer`. |

The headline: the things you *compose with* are immutable and freely shareable; the things you *consume* (a live stream, a fluent builder) are single-owner. This is what lets you define a command once and run it in a hundred pipelines without a second thought.

---

## For authors: producing a stream

If you write a `FuncCommand`, you produce a stream with one of two primitives. Both inherit everything above — you don't re-implement teardown, you opt into it.

- **`Generate(ctx, producer)`** — an *origin* producer (a `Source`, no upstream).
- **`GenerateFrom(ctx, in, producer)`** — a producer *derived from* an input stream; a downstream `Discard` cancels your producer **and** tears `in` down, so one `Discard` collapses the whole chain (upstream only).

Your `producer` emits with `send(v) bool` and `sendErr(err)`. The contract is one rule:

> **`send` returns `false` once the consumer has stopped or the context was cancelled. Return promptly when it does** — exactly as a shell tool dies on SIGPIPE.

```go
gloo.GenerateFrom(ctx, in, func(_ context.Context, send func(T) bool, sendErr func(error)) {
    for item := range in.Chan() {
        if item.Error != nil { sendErr(item.Error); return }
        if !send(transform(item.Value)) { return } // consumer gone — stop now
    }
})
```

The teardown rides the `in` stream you pass; you never hold a loose stop handle, so you can't misuse it. That's the same safety-by-construction the consumer side enjoys, extended to authors.

For a pure rill transform, `WrapFrom(ch, in)` does the same wiring with no producer goroutine of its own. See [For Command Authors → Exotic commands](For-Command-Authors#exotic-commands--funccommand).

---

## In one sentence

Teardown propagates upstream automatically, the only early-exit you can express is the safe one (`Discard` = stop + drain), immutable values are freely shareable, and live consumers are single-owner — so a gloo pipeline shuts down as cleanly as a shell pipe, by construction, with no way to leak a goroutine.
