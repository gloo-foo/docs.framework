---
title: Concurrency Analysis
---

# gloo-foo Framework Concurrency Analysis

## Executive Summary

**Current State**: The framework CAN support goroutines with careful implementation, but it's not explicitly designed for it. The architecture is fundamentally **goroutine-safe at the framework level** but requires **command-specific attention** for concurrent execution.

**Recommendation**: Document the framework as "goroutine-compatible with care" rather than "goroutine-native". Commands can be made concurrent, but it requires explicit design.

---

## Framework Level Analysis

### ✅ Safe for Concurrent Use

#### 1. Command Interface (`yup.Command`)
```go
type Command interface {
    Executor() CommandExecutor
}
```

**Status**: ✅ **Goroutine-Safe**
- Pure interface with no shared state
- Each command instance is independent
- Executor returns a function, doesn't hold mutable state

**Usage**:
```go
// Safe: Different goroutines can create and execute different commands
go yup.Run(cat.Cat("file1.txt"))
go yup.Run(grep.Grep("pattern", "file2.txt"))
```

#### 2. Inputs[T, O] Structure
```go
type Inputs[T any, O any] struct {
    Positional []T
    Flags      O
    stdin      []reader
    stdout     writer
    stderr     writer
}
```

**Status**: ✅ **Goroutine-Safe (per instance)**
- Immutable after initialization
- Each command gets its own Inputs instance
- No shared mutable state between commands

**Note**: Each command instance is independent and goroutine-safe
```go
// ✅ SAFE: Create separate command instances
go func() {
    yup.Run(cat.Cat("file1.txt"))
}()
go func() {
    yup.Run(cat.Cat("file2.txt"))
}()

// ✅ ALSO SAFE: Can use MustRun in examples/tests
go func() {
    yup.MustRun(cat.Cat("file1.txt"))
}()
go func() {
    yup.MustRun(cat.Cat("file2.txt"))
}()
```

#### 3. Initialize Function
```go
func Initialize[T any, O any](parameters ...any) Inputs[T, O]
```

**Status**: ✅ **Goroutine-Safe**
- Called internally by command constructors (e.g., `cat.Cat()`, `awk.Awk()`)
- Creates new instances each time a command is created
- No shared state between command instances
- File opening is per-instance

**Note for Command Developers**: Each command constructor calls `Initialize` once, creating independent `Inputs` for that command instance.

**Consideration**: File handles are NOT shared, so concurrent commands reading the same file will have independent file descriptors and positions.

#### 4. Helper Functions (LineTransform, AccumulateAndProcess, etc.)

**Status**: ✅ **Goroutine-Safe**
- Each creates independent command instances
- No shared state across invocations
- Closures capture command-specific state

**Example**:
```go
// ✅ SAFE: Each command has its own state
func (c command) Executor() yup.CommandExecutor {
    return yup.LineTransform(func(line string) (string, bool) {
        // c is captured per command instance
        return processLine(c, line), true
    }).Executor()
}
```

---

> **Note**: For command-specific concurrency analysis (e.g., awk), see [COMMAND_CONCURRENCY_ANALYSIS.md](COMMAND_CONCURRENCY_ANALYSIS.md).

---

## Concurrency Scenarios

### Scenario 1: Multiple Commands in Parallel ✅

**Status**: ✅ **Works Today**

```go
// ✅ SAFE: Different commands, different instances
func processFiles(files []string) {
    var wg sync.WaitGroup
    for _, file := range files {
        wg.Add(1)
        go func(f string) {
            defer wg.Done()
            cmd := cat.Cat(f)
            yup.Run(cmd)
        }(file)
    }
    wg.Wait()
}
```

**Why it works**:
- Each command has its own Inputs instance
- Each command has its own file handles
- No shared state between commands

**Limitation**: Output interleaving (stdout/stderr from different goroutines will mix)

### Scenario 2: Parallel Line Processing Within a Command ❌

**Status**: ❌ **Does Not Work (Race Conditions)**

```go
// ❌ UNSAFE: Current implementation
func (c *statefulLineCommand) Executor() CommandExecutor {
    return func(ctx context.Context, stdin io.Reader, stdout, stderr io.Writer) error {
        scanner := bufio.NewScanner(stdin)
        lineNum := int64(0)

        // Trying to parallelize this would cause races:
        for scanner.Scan() {
            lineNum++  // Race condition if concurrent
            line := scanner.Text()
            output, emit := c.fn(lineNum, line)  // Race if fn uses shared state
            if emit {
                fmt.Fprintln(stdout, output)  // Race on stdout
            }
        }
    }
}
```

**Issues**:
1. `lineNum++` is not atomic
2. `stdout` writes are not synchronized
3. User-provided functions may have shared state

### Scenario 3: Pipeline Parallelism ⚠️

**Status**: ⚠️ **Partially Possible**

Go's `io.Pipe()` allows streaming between commands:

```go
// ✅ SAFE: Commands in pipeline run concurrently
r, w := io.Pipe()

go func() {
    defer w.Close()
    cmd1 := cat.Cat("file.txt")
    cmd1.Executor()(ctx, os.Stdin, w, os.Stderr)
}()

cmd2 := grep.Grep("pattern")
cmd2.Executor()(ctx, r, os.Stdout, os.Stderr)
```

**Current State**: This works but is not a built-in framework feature.

---

## Required Changes for Full Concurrency Support

### Level 1: Documentation Only (Effort: Low, Value: High)

**Goal**: Clarify what's safe today

1. **Document goroutine safety guarantees**:
   - ✅ Multiple command instances can run concurrently
   - ❌ Single command instance cannot parallelize its internal processing
   - ⚠️ Shared I/O streams (stdout/stderr) will interleave

2. **Add examples**:
   ```go
   // examples/concurrency/parallel_commands_test.go
   func ExampleParallelCommands() {
       var wg sync.WaitGroup
       files := []string{"file1.txt", "file2.txt", "file3.txt"}

       for _, file := range files {
           wg.Add(1)
           go func(f string) {
               defer wg.Done()
               cmd := cat.Cat(f)
               yup.Run(cmd)
           }(file)
       }
       wg.Wait()
   }
   ```

### Level 2: Framework Enhancements (Effort: Medium, Value: Medium)

**Goal**: Enable safe concurrent line processing

#### 2.1: Add Parallel Line Transform Helper

```go
// helpers.go
func ParallelLineTransform(fn LineTransformFunc, workers int) Command {
    return &parallelLineTransformCommand{
        fn:      fn,
        workers: workers,
    }
}

type parallelLineTransformCommand struct {
    fn      LineTransformFunc
    workers int
}

func (c *parallelLineTransformCommand) Executor() CommandExecutor {
    return func(ctx context.Context, stdin io.Reader, stdout, stderr io.Writer) error {
        // Channel for lines
        lines := make(chan string, 100)
        results := make(chan string, 100)

        // Worker pool
        var wg sync.WaitGroup
        for i := 0; i < c.workers; i++ {
            wg.Add(1)
            go func() {
                defer wg.Done()
                for line := range lines {
                    output, emit := c.fn(line)
                    if emit {
                        results <- output
                    }
                }
            }()
        }

        // Output writer (maintains order if needed)
        go func() {
            for result := range results {
                fmt.Fprintln(stdout, result)
            }
        }()

        // Read input
        scanner := bufio.NewScanner(stdin)
        for scanner.Scan() {
            lines <- scanner.Text()
        }
        close(lines)

        wg.Wait()
        close(results)

        return scanner.Err()
    }
}
```

**Challenges**:
- **Order preservation**: Output may need to maintain input order
- **Error handling**: How to collect and report errors from workers
- **Backpressure**: Need buffered channels and proper coordination

#### 2.2: Thread-Safe I/O Helpers

```go
// helpers.go
type SynchronizedWriter struct {
    mu sync.Mutex
    w  io.Writer
}

func (sw *SynchronizedWriter) Write(p []byte) (n int, err error) {
    sw.mu.Lock()
    defer sw.mu.Unlock()
    return sw.w.Write(p)
}

func SyncWriter(w io.Writer) io.Writer {
    return &SynchronizedWriter{w: w}
}
```

**Usage**:
```go
func (c command) Executor() yup.CommandExecutor {
    return func(ctx context.Context, stdin io.Reader, stdout, stderr io.Writer) error {
        safeStdout := yup.SyncWriter(stdout)
        // Now multiple goroutines can write safely
    }
}
```

> **Note**: For command-specific enhancements like awk parallelism, see [COMMAND_CONCURRENCY_ANALYSIS.md](COMMAND_CONCURRENCY_ANALYSIS.md).

---

## I/O Specific Concerns

### 1. bufio.Scanner
**Status**: ⚠️ **Not goroutine-safe**
```go
// Current usage (safe):
scanner := bufio.NewScanner(stdin)
for scanner.Scan() {
    line := scanner.Text()
    // process sequentially
}

// ❌ UNSAFE:
scanner := bufio.NewScanner(stdin)
for scanner.Scan() {
    go func(line string) {
        // Scanner is being called from multiple goroutines
    }(scanner.Text())
}
```

### 2. io.Reader
**Status**: ⚠️ **Implementation-dependent**
- Most io.Reader implementations are not goroutine-safe
- `os.File` has some internal synchronization but concurrent reads can interleave
- Safe approach: Single reader goroutine, distribute via channels

### 3. io.Writer (stdout/stderr)
**Status**: ⚠️ **Unbuffered writes are "atomic" but can interleave**
```go
// Each fmt.Fprintln is atomic, but output interleaves:
go fmt.Fprintln(stdout, "line 1")
go fmt.Fprintln(stdout, "line 2")

// Output could be:
// line 1
// line 2
// OR
// line 2
// line 1
```

**Solution**: Synchronized wrapper (see Level 2.2 above)

### 4. File Handles
**Status**: ✅ **Safe per-instance**
- Each command opens its own file handles
- No sharing between command instances
- Proper cleanup with defer/Close()

---

## Recommendations

### Immediate (No Code Changes)

1. **Document current guarantees**:
   ```
   # Concurrency

   Multiple command instances can run concurrently:
   - Each command has independent state
   - No shared memory between commands
   - Output streams may interleave

   Individual commands process data sequentially:
   - Line-by-line processing is single-threaded
   - This matches Unix tool behavior
   - Most commands are I/O bound, not CPU bound
   ```

2. **Add documentation about goroutine safety**:
   ```
   ## Goroutine Safety

   ✅ Commands are goroutine-safe when used with yup.Run() or yup.MustRun().
   ✅ Create a new command instance for each concurrent execution.

   Example - Concurrent execution:
   go yup.Run(cat.Cat("file1.txt"))
   go yup.Run(cat.Cat("file2.txt"))
   go yup.Run(grep.Grep("pattern", "file3.txt"))

   Example - With error handling:
   var wg sync.WaitGroup
   for _, file := range files {
       wg.Add(1)
       go func(f string) {
           defer wg.Done()
           if err := yup.Run(cat.Cat(f)); err != nil {
               log.Printf("Error processing %s: %v", f, err)
           }
       }(file)
   }
   wg.Wait()
   ```

### Short Term (Framework Enhancement)

3. **Add optional parallel helpers** for CPU-intensive transformations:
   - `ParallelLineTransform(fn, workers)`
   - `SyncWriter(io.Writer)`
   - Document trade-offs (order, complexity)

4. **Add examples** showing safe concurrency patterns:
   - Parallel command execution
   - Pipeline construction with io.Pipe
   - Synchronized output

### Long Term (If Demanded)

5. **Consider a "concurrent" variant** of the framework:
   - Separate package: `github.com/yupsh/concurrent`
   - Explicit about ordering guarantees
   - Built-in worker pools and channels
   - Higher complexity but better performance for CPU-bound tasks

---

## Conclusion

**Can the framework support goroutines?**

✅ **Yes, with caveats:**
- Multiple command instances can run concurrently ✅
- Individual command internals are sequential by design ⚠️
- Shared I/O requires synchronization ⚠️
- Framework is goroutine-compatible, not goroutine-native ✅

**Should you claim "supports goroutines"?**

🎯 **Recommend**: "Goroutine-compatible" with clear documentation:
- Each command instance is independent and can run in a goroutine
- Commands follow Unix tool semantics (sequential line processing)
- For parallel processing, create multiple command instances
- Optional parallel helpers available for specific use cases

**Effort Required for Full Support:**

| Feature | Effort | Value | Priority |
|---------|--------|-------|----------|
| Document current state | Low | High | 🔥 **Do Now** |
| Add parallel examples | Low | Medium | ✅ **Recommended** |
| Parallel line helpers | Medium | Medium | 🤔 **If Needed** |
| Synchronized I/O | Medium | High | 🤔 **If Needed** |

> For command-specific considerations, see [COMMAND_CONCURRENCY_ANALYSIS.md](COMMAND_CONCURRENCY_ANALYSIS.md).

**Bottom Line**: The framework is already well-suited for the most common concurrency pattern (running multiple independent commands). More advanced patterns are possible but require careful design and documentation.

