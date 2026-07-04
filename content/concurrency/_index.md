---
title: Concurrency
---

# gloo-foo Framework Concurrency Testing & Analysis

This repository contains comprehensive concurrency analysis, testing, and demonstrations for the [yupsh framework](https://github.com/gloo-foo/framework).

## Quick Answer

**YES** ✅ - The yupsh framework supports concurrent execution of commands with goroutines.

Each command instance is independent and goroutine-safe, allowing you to run multiple commands concurrently:

```go
var wg sync.WaitGroup
for _, file := range files {
    wg.Add(1)
    go func(f string) {
        defer wg.Done()
        yup.Run(cat.Cat(f))
    }(file)
}
wg.Wait()
```

## Documentation

### Framework Analysis
- **[CONCURRENCY_QUICK_REFERENCE.md](CONCURRENCY_QUICK_REFERENCE.md)** - Quick reference guide with safe/unsafe patterns
- **[CONCURRENCY_SUMMARY.md](CONCURRENCY_SUMMARY.md)** - Executive summary with recommendations
- **[CONCURRENCY_ANALYSIS.md](CONCURRENCY_ANALYSIS.md)** - Comprehensive framework-level technical analysis

### Command-Specific Analysis
- **[COMMAND_CONCURRENCY_ANALYSIS.md](COMMAND_CONCURRENCY_ANALYSIS.md)** - Analysis of specific commands (awk, uniq, etc.)

## Running the Demonstrations

### Concurrency Demo
Shows working patterns and potential issues:

```bash
go run concurrency_demo.go
```

This demonstrates:
- ✅ Multiple commands running in parallel
- ⚠️ Output interleaving with shared I/O
- ✅ Pipeline composition with io.Pipe
- ❌ Why parallel line processing is unsafe
- ✅ Synchronized output wrapper

### Race Condition Demo
Shows race conditions that would occur with improper usage:

```bash
go run -race race_demo.go
```

Run with the `-race` flag to see Go's race detector in action.

### Tests
Run the test suite:

```bash
go test -v
```

Run with race detection:

```bash
go test -race -v
```

## What Works ✅

1. **Multiple independent command instances in parallel**
   ```go
   go yup.Run(cat.Cat("file1.txt"))
   go yup.Run(grep.Grep("pattern", "file2.txt"))
   go yup.Run(awk.Awk(program{}, "file3.txt"))
   ```

2. **Error handling in concurrent execution**
   ```go
   var wg sync.WaitGroup
   for _, file := range files {
       wg.Add(1)
       go func(f string) {
           defer wg.Done()
           if err := yup.Run(cat.Cat(f)); err != nil {
               log.Printf("Error: %v", err)
           }
       }(file)
   }
   wg.Wait()
   ```

3. **Each command instance is isolated**
   - Independent `Inputs` structures
   - Separate file handles
   - No shared mutable state


## What Doesn't Work ❌

1. **Parallel line processing within a single command**
   - Commands process lines sequentially by design
   - Matches Unix tool semantics (order and line numbers matter)
   - Most text processing is I/O bound, not CPU bound

2. **Sharing I/O streams without synchronization**
   - Multiple goroutines writing to the same stdout will interleave
   - Use synchronized wrappers if needed (see demo)

## Key Design Insights

### Command Instances Are Independent

Each call to a command constructor creates a new, independent instance:

```go
cmd1 := cat.Cat("file.txt")  // Instance 1 with Inputs₁
cmd2 := cat.Cat("file.txt")  // Instance 2 with Inputs₂
```

### Use yup.Run() and yup.MustRun()

These are the user-facing APIs for executing commands:

```go
// Production code - returns error
if err := yup.Run(cat.Cat("file.txt")); err != nil {
    log.Fatal(err)
}

// Examples and tests - panics on error
yup.MustRun(cat.Cat("file.txt"))
```

Both are safe to use in concurrent goroutines.

### Sequential Line Processing Is Intentional

Commands process lines one at a time, maintaining order:
- Preserves line numbers (critical for awk's `NR`)
- Maintains output order
- Simplifies implementation
- Matches Unix tool behavior

## Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│ Goroutine 1 │     │ Goroutine 2 │     │ Goroutine 3 │
├─────────────┤     ├─────────────┤     ├─────────────┤
│ Command A   │     │ Command B   │     │ Command C   │
│ Instance 1  │     │ Instance 2  │     │ Instance 3  │
├─────────────┤     ├─────────────┤     ├─────────────┤
│ Own Inputs  │     │ Own Inputs  │     │ Own Inputs  │
│ Own Files   │     │ Own Files   │     │ Own Files   │
│ Own State   │     │ Own State   │     │ Own State   │
└─────────────┘     └─────────────┘     └─────────────┘
      ↓                   ↓                   ↓
   file1.txt           file2.txt           file3.txt
```

## Framework Analysis

### ✅ Goroutine-Safe Components

| Component | Status | Notes |
|-----------|--------|-------|
| `Command` interface | ✅ Safe | Stateless interface |
| `Inputs[T, O]` | ✅ Safe per-instance | Immutable after creation |
| `Initialize()` | ✅ Safe | Creates independent instances |
| Helper functions | ✅ Safe | Return independent commands |
| `Executor()` method | ✅ Safe | Can be called multiple times |

### ⚠️ Considerations

| Aspect | Status | Notes |
|--------|--------|-------|
| Shared stdout | ⚠️ Interleaves | Use SyncWriter if needed |
| Awk Context | ⚠️ Sequential | `NR`, `Variables` are single-threaded |
| File I/O | ✅ Safe | Each instance opens own handles |

## Testing Coverage

1. **Safe Patterns**
   - Multiple concurrent command instances
   - Pipeline composition
   - Synchronized output

2. **Unsafe Patterns (Documented)**
   - Reusing command instances (actually safe, but shown for completeness)
   - Sharing stateful context
   - Parallel line processing attempts

3. **Race Detection**
   - Demonstrations showing what race conditions would look like
   - Tests that can be run with `-race` flag

## Recommendations

### For Framework Users

1. **Create new command instances** for each concurrent execution
2. **Use synchronized wrappers** if output order matters
3. **Leverage pipelines** for natural concurrency

### For Command Developers

1. **Avoid package-level mutable state**
2. **Capture command-specific state in closures**
3. **Let each instance be independent**

### For Framework Maintainers

1. **Document the goroutine safety guarantees**
2. **Add concurrency examples to the main README**
3. **Consider adding optional synchronized I/O helpers**

## Contributing

This repository serves as:
- **Documentation** of concurrency capabilities
- **Testing** of concurrent usage patterns
- **Examples** for users wanting concurrent processing

Feel free to add more tests, examples, or documentation improvements.

## License

Same as the yupsh framework.

## Related

- [yupsh framework](https://github.com/gloo-foo/framework)
- [yupsh commands](https://github.com/yupsh)

