---
title: Errors-and-Testing
---

# Errors & Testing

_Audience: everyone. How errors travel through a pipeline, and how to test commands without real I/O._

---

## How errors flow

A gloo error doesn't unwind a call stack — it travels **in the stream** as an item. Each item a stage produces is either a value or an error. The first error a consumer encounters stops the pipeline and is returned:

```go
result, err := gloo.Chain(src).To(cmd).Collect()
if err != nil {
    // the first error any stage produced; the upstream was already torn down
}
```

When a consumer hits an error it `Discard`s the rest of the stream (stop + drain), so the producers behind the error can't leak — see [Concurrency & Lifecycle](Concurrency-and-Lifecycle). As an author, returning an error from your pattern function is all it takes to propagate one:

```go
patterns.Map(func(line string) (string, error) {
    n, err := strconv.Atoi(line)
    if err != nil {
        return "", err   // travels downstream; stops the pipeline
    }
    return strconv.Itoa(n * 2), nil
})
```

---

## Sentinel errors

The framework's errors are **sentinels** you match structurally with `errors.Is`, never by string. The package defines a single error type:

```go
type Error string
func (e Error) Error() string { return string(e) }
```

…and declares each error it can emit as a `const` of that type. Wrap a cause with `.With`:

```go
return ErrFileNotFound.With(err, "file", name) // "file not found: <cause>: file <name>"
```

`errors.Is` matches both the sentinel and the wrapped cause:

```go
if errors.Is(err, gloo.ErrFileNotFound) { … }
```

### The errors gloo can emit

| Sentinel | When |
| --- | --- |
| `ErrStopReading` | the silent downstream-stop cause (you rarely match this) |
| `ErrFileNotFound` | a `File` positional couldn't be opened |
| `patterns.ErrSubprocessStart`, `ErrSubprocessReadStdout`, `ErrSubprocessStdinPipe`, `ErrSubprocessStdoutPipe`, `ErrSubprocess` | a `Subprocess` failed at the named stage |

### Fluent builder errors

The reflection-based fluent builder (`Chain`/`Run`) reports a malformed pipeline as a returned error — **never a panic** — surfaced by the terminal:

| Sentinel | When |
| --- | --- |
| `ErrNotSource` | the `Chain` argument isn't a `Source` |
| `ErrNotCommand` | a `.To()` argument isn't a `Command` |
| `ErrNotSink` | a `.Sink()` argument isn't a `Sink` |
| `ErrStageTypeMismatch` | a stage's input type doesn't match the previous output |
| `ErrSinkTypeMismatch` | the sink's input type doesn't match the pipeline |
| `ErrNotForEachFunc` | a `.ForEach()` argument isn't `func(T) error` |
| `ErrPipelineConsumed` | the builder was already consumed by a terminal |

```go
_, err := gloo.Chain(src).To(wrongTypedCmd).Collect()
if errors.Is(err, gloo.ErrStageTypeMismatch) { … } // and the message names both types
```

> Prefer `Pipe`/`Compose` when you want these caught at _compile_ time instead — see [the two execution models](The-Pipeline-Model#two-execution-models).

---

## Testing commands

Commands are designed to be tested with **in-memory streams** — no filesystem, no stdin/stdout, no subprocesses (except when testing `Subprocess` itself).

### The basic shape

Feed a synthetic stream, run the command, collect the result, assert exact values:

```go
func TestShout(t *testing.T) {
    shout := patterns.Map(func(s string) (string, error) {
        return strings.ToUpper(s), nil
    })

    got, err := shout.Execute(context.Background(), gloo.StreamOf("a", "b")).Collect()
    if err != nil {
        t.Fatal(err)
    }
    if len(got) != 2 || got[0] != "A" || got[1] != "B" {
        t.Errorf("got %v, want [A B]", got)
    }
}
```

| Need                | Use                                                  |
| ------------------- | ---------------------------------------------------- |
| synthetic input     | `gloo.StreamOf(items…)` or `gloo.SliceSource(items)` |
| byte-pipeline input | `gloo.ByteReaderSource([]io.Reader{r})`              |
| a fake filesystem   | `afero.NewMemMapFs()` — never the real disk          |
| the result          | `.Collect()` (slice) or a sink                       |
| a godoc example     | `patterns.MustRun(cmd)` with an `// Output:` matcher |

### Assert behavior, not coverage

The framework holds itself to 100% statement coverage — but coverage is the floor, not the goal. A test should **fail if the behavior is wrong**, not merely execute the code. Concretely:

- Assert **exact values and order**, not just lengths (`got == [a, b]`, not `len(got) == 2`).
- Match errors with **`errors.Is(err, Sentinel)`**, not `err != nil` or a substring.
- For early-stop / cancellation, prove the **producer actually exited** — wait on a `done` channel the producer closes, rather than sleeping or counting goroutines. (See the `verification/` suite's `waitClosed`/`mustExit` helpers.)
- For "fresh state per run," **reuse the same command value across two pipelines** and assert their results are independent.

### Worked references

- **Runnable godoc examples:** [`example_test.go`](https://github.com/gloo-foo/framework/blob/main/example_test.go)
- **End-to-end pipelines (the real proof):** [`verification/`](https://github.com/gloo-foo/framework/tree/main/verification) — especially `shell_pipeline_test.go` (full value oracles) and `cancellation_test.go` (deterministic leak detection)
- **Per-pattern tests:** [`patterns/`](https://github.com/gloo-foo/framework/tree/main/patterns)

---

That completes the wiki. Back to [Home](Home), or jump to the [API reference](https://pkg.go.dev/github.com/gloo-foo/framework).
