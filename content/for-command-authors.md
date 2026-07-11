---
title: For-Command-Authors
---

## For Command Authors

_Audience: you build the commands that [Users](For-Command-Users) compose._

The rule of authoring: **pick a pattern from [`patterns/`](https://github.com/gloo-foo/framework/tree/main/patterns) and supply only your algorithm.** The pattern owns every hard part — stream wiring, channels, backpressure, cancellation, teardown — and hands you a plain function to fill in. You write _what the command does to a line_, never _how lines move_.

> Read [The Pipeline Model](The-Pipeline-Model) first if you haven't. Authors should also read [Concurrency & Lifecycle](Concurrency-and-Lifecycle) — it explains the teardown your commands inherit for free.

---

### The pattern catalog

Each pattern captures one shape of "how input relates to output." Find your command's shape, and the pattern is chosen.

| Pattern | You supply | Output relationship | Shell analogues |
| --- | --- | --- | --- |
| `Map[In, Out]` | `func(In) (Out, error)` | one in → one out | `tr`, `sed s///`, `cut`, `basename` |
| `StatefulMap[In, Out]` | factory → `func(In) (Out, error)` | one → one, with memory | `nl` (line counter) |
| `Filter[T]` | `func(T) (bool, error)` | keep or drop | `grep`, `grep -v` |
| `StatefulFilter[T]` | factory → `func(T) (bool, error)` | keep/drop, with memory | `uniq` (previous line) |
| `Accumulate[T]` | `func([]T) ([]T, error)` | all in → all out (reordered/trimmed) | `sort`, `tac`, `tail -n`, `shuf` |
| `Aggregate[In, Out]` | `func([]In) (Out, error)` | all in → one out | `wc -l`, `sha256sum`, `paste -s` |
| `Expand[In, Out]` | `func(In) ([]Out, error)` | one in → zero-or-more out | `fold`, `split`, `xargs -n1` |
| `Take[T]` / `Head[T]` | `n int` | first n, then stop the upstream | `head -n`, `grep -m`, `sed q` |
| `Drop[T]` | `n int` | skip first n, pass the rest | `tail -n +N` |
| `Tap[T]` | `func(T) error` | pass through, with a side effect | `tee` |
| `Subprocess` | `name, args…` | shell out to a real process | `perl`, `git` (last resort) |

#### Decision shortcuts

- **One line → one line?** `Map`. Need a counter or running state? `StatefulMap`.
- **Keep some lines?** `Filter`. Need the previous line? `StatefulFilter`.
- **Need to see _all_ input first** (sort, reverse, tail)? `Accumulate` (same type out) or `Aggregate` (one summary out).
- **One line becomes many** (or none)? `Expand`.
- **"I've seen enough"** (stop early)? `Take` / `Head` — and read [why this is special](#early-termination--take).
- **Just observing** (write a copy, log)? `Tap`.

---

### Writing a command

A command is a constructor that returns a `Command`. Supply the algorithm; that's it.

```go
func Grep(pattern string) gloo.Command[string, string] {
    return patterns.Filter(func(line string) (bool, error) {
        return strings.Contains(line, pattern), nil
    })
}

func Sort() gloo.Command[string, string] {
    return patterns.Accumulate(func(lines []string) ([]string, error) {
        sort.Strings(lines)
        return lines, nil
    })
}

func WordCount() gloo.Command[string, int] {
    return patterns.Aggregate(func(lines []string) (int, error) {
        return len(lines), nil
    })
}
```

Returning an error from your function propagates it down the stream and stops the pipeline — see [how errors flow](Errors-and-Testing#how-errors-flow).

#### Stateful commands take a _factory_

A command is a value that may be reused across many pipelines, possibly concurrently. If a stateful command captured its state directly, two runs would share it. So `StatefulMap` and `StatefulFilter` take a **factory** called **once per `Execute`** — each run gets its own fresh state.

```go
func Nl() gloo.Command[string, string] {
    return patterns.StatefulMap(func() func(string) (string, error) {
        n := 0 // fresh per Execute — never shared between pipelines
        return func(line string) (string, error) {
            n++
            return fmt.Sprintf("%d\t%s", n, line), nil
        }
    })
}
```

Never close over a mutable variable _outside_ the factory — that's the one way to make a command unsafe to reuse.

#### Early termination — `Take`

`Take(n)` emits the first `n` items and then **stops the upstream** — the SIGPIPE analogue. This is the one thing a `Filter` cannot do: a filter can drop items but can never say "I need nothing more," so a filter-based `head` over a huge or infinite source reads _everything_. `Take` actively tears the producer down, so:

- `Take(3)` over an infinite source terminates instantly and leaks no goroutine, and
- a `FileSource | Take(3)` reads only a small prefix of the file.

Stages _downstream_ of `Take` still run to completion, so `Take(3)` before a `sort` yields three sorted lines — exactly like `seq inf | head -3 | sort`. `Take` is the building block for `head`, `grep -m`, and `sed q`. (`Head` is a readability alias for `Take`.)

The mechanics behind this — how a downstream stop propagates upstream without leaking — are on [Concurrency & Lifecycle](Concurrency-and-Lifecycle).

---

### Exotic commands — `FuncCommand`

When no pattern fits, drop to `FuncCommand[In, Out]` and build the output stream yourself. This is the _only_ place an author touches `rill`. Two primitives produce a stream while inheriting clean teardown:

- **`GenerateFrom(ctx, in, producer)`** — produce output derived from an input stream. A downstream stop tears down both your producer and the upstream `in`, because you pass the _stream_, not a loose handle.

  ```go
  func Doubler() gloo.Command[int, int] {
      return gloo.FuncCommand[int, int](func(ctx context.Context, in gloo.Stream[int]) gloo.Stream[int] {
          return gloo.GenerateFrom(ctx, in, func(_ context.Context, send func(int) bool, sendErr func(error)) {
              for item := range in.Chan() {
                  if item.Error != nil { sendErr(item.Error); return }
                  if !send(item.Value * 2) { return } // send==false → consumer stopped; return promptly
              }
          })
      })
  }
  ```

- **`WrapFrom(ch, in)`** — wrap a pure rill transform's output channel, chaining teardown to `in`:

  ```go
  out := rill.OrderedMap(in.Chan(), 1, fn)
  return gloo.WrapFrom(out, in)
  ```

For an _origin_ producer (a `Source`, no upstream), use `Generate(ctx, producer)` and `Wrap(ch)` — same primitives without the upstream argument.

The golden rule: **`send` returning `false` means the consumer has walked away — return promptly**, exactly as a shell tool dies on SIGPIPE.

---

### Sources

Build a `Source` to feed a pipeline. All filesystem access goes through [`afero.Fs`](https://github.com/spf13/afero) — never `os.Open`. Tests use `afero.NewMemMapFs()`.

| Constructor | Produces | Notes |
| --- | --- | --- |
| `SliceSource(items)` | `Source[T]` | in-memory slice — the here-string |
| `FileSource(fs, files)` | `Source[string]` | lines from files |
| `ByteFileSource(fs, files)` | `Source[[]byte]` | same, as independent `[]byte` copies |
| `ReaderSource(readers)` | `Source[string]` | lines from `io.Reader`s |
| `ByteReaderSource(readers)` | `Source[[]byte]` | same, as `[]byte` |
| `StreamOf(items…)` | `Stream[T]` | a finished stream — the test here-string |

Sources are cancellation-aware and handle lines far larger than `bufio.Scanner`'s 64 KB default (up to `MaxLineSize`, 1 GiB) via `NewLineScanner`, so minified JSON and long log lines never abort a pipeline.

---

### Where things belong

Per the framework's constitution: stream wiring lives in `framework/`, patterns in `framework/patterns/`, and each command in its own `cmd-*` module. `Subprocess` is a last resort — if an algorithm can be done in pure Go, it must be. New patterns require maintainer approval; exhaust the existing set first.

Next: **[Errors & Testing](Errors-and-Testing)** shows how to surface errors and how to test a command with in-memory streams.
