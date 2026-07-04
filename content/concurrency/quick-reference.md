---
title: Concurrency Quick Reference
---

# Yupsh Concurrency Quick Reference

## TL;DR

✅ **YES**, the framework supports goroutines
✅ Each command instance is independent and goroutine-safe
❌ Don't reuse command instances across goroutines
ℹ️  No framework changes needed - works today

---

## Safe Patterns ✅

### Pattern 1: Parallel Independent Commands
```go
// Process multiple files concurrently
var wg sync.WaitGroup
for _, file := range files {
    wg.Add(1)
    go func(f string) {
        defer wg.Done()
        yup.Run(cat.Cat(f))  // Each call creates a new instance
    }(file)
}
wg.Wait()
```

### Pattern 2: Processing with Error Handling
```go
// Handle errors properly in concurrent execution
var wg sync.WaitGroup
errors := make(chan error, len(files))

for _, file := range files {
    wg.Add(1)
    go func(f string) {
        defer wg.Done()
        if err := yup.Run(cat.Cat(f)); err != nil {
            errors <- fmt.Errorf("file %s: %w", f, err)
        }
    }(file)
}

wg.Wait()
close(errors)

for err := range errors {
    log.Println(err)
}
```

### Pattern 3: Synchronized Output
```go
// Prevent output interleaving
type SyncWriter struct {
    mu sync.Mutex
    w  io.Writer
}

func (sw *SyncWriter) Write(p []byte) (n int, err error) {
    sw.mu.Lock()
    defer sw.mu.Unlock()
    return sw.w.Write(p)
}

syncOut := &SyncWriter{w: os.Stdout}
go yup.Run(cat.Cat("file1.txt"))  // Writes to syncOut
go yup.Run(cat.Cat("file2.txt"))  // Writes to syncOut
```

---

---

## Unsafe Patterns ❌

### Anti-Pattern 1: Trying to Parallelize Line Processing
```go
// ❌ DON'T DO THIS - commands process lines sequentially by design
// This is not supported and would break semantic guarantees

// Just use the command normally:
yup.Run(cat.Cat("file.txt"))  // Sequential line processing
```

---

## Why This Design?

### Commands Are Independent Instances
- Each call to `cat.Cat()`, `grep.Grep()`, etc. creates a NEW instance
- Each instance has its own `Inputs` (created internally via `Initialize`)
- Use `yup.Run()` to execute commands (with error handling)
- Use `yup.MustRun()` in examples/tests (panics on error)
- **Therefore**: Creating new instances for each goroutine is safe

### Sequential Line Processing Is Intentional
- Matches Unix tool semantics (line order matters)
- Preserves line numbers (NR in awk)
- Most text processing is I/O bound, not CPU bound
- Simplifies command implementation

---

## Framework Internals (For Command Developers)

### How Commands Are Created
```go
// User code:
cmd := cat.Cat("file.txt")

// Internally (in cat package):
func Cat(parameters ...any) yup.Command {
    // Initialize creates THIS instance's Inputs
    inputs := yup.Initialize[yup.File, flags](parameters...)
    return command(inputs)  // Return new instance
}
```

### Each Instance Is Isolated
```
User Call 1: cat.Cat("file1.txt")
    └─> Initialize() creates Inputs₁
        └─> Opens file1.txt with fd₁

User Call 2: cat.Cat("file2.txt")
    └─> Initialize() creates Inputs₂
        └─> Opens file2.txt with fd₂

Inputs₁ and Inputs₂ are completely independent
```

### Command Execution Flow
```
1. User: cmd := cat.Cat("file.txt")  // Create instance with Inputs
2. User: yup.Run(cmd)                // Get executor and run
3. Framework: executor := cmd.Executor()
4. Framework: executor(ctx, stdin, stdout, stderr)
5. Command: Process data using its own Inputs
6. Framework: Return result
```

---

## Testing Concurrency

### Run the Demo
```bash
cd examples
go run concurrency_demo.go
```

Shows:
- ✅ Multiple commands in parallel
- ⚠️ Output interleaving with shared I/O
- ✅ Pipeline composition
- ❌ Why parallel line processing is unsafe
- ✅ Synchronized output

### Run Tests
```bash
cd examples
go test -v race_test.go concurrency_demo.go
```

### Detect Races
```bash
cd examples
go run -race race_demo.go
```

---

## Documentation Needed

### For Users (Add to Framework README)
```markdown
## Concurrent Execution

Commands are goroutine-safe. Create a new command instance for each execution:

```go
// Process multiple files concurrently
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

✅ Each call to `cat.Cat()`, `grep.Grep()`, etc. creates a new instance
✅ Use `yup.Run()` for production code (returns error)
✅ Use `yup.MustRun()` for examples/tests (panics on error)
```

### For Command Developers
```markdown
## Goroutine Safety

Commands are automatically goroutine-safe as long as:
1. You don't use package-level mutable variables
2. You capture command-specific state in closures
3. You let Initialize() create independent Inputs per instance

Example:
```go
func (c command) Executor() yup.CommandExecutor {
    return yup.LineTransform(func(line string) (string, bool) {
        // c is captured per instance - safe
        return process(c.Flags, line), true
    }).Executor()
}
```
```

---

## Summary Table

| Scenario | Safe? | Notes |
|----------|-------|-------|
| Multiple command instances | ✅ Yes | Most common pattern |
| Reusing same instance | ❌ No | Create new instances |
| Pipeline with io.Pipe | ✅ Yes | Natural concurrency |
| Shared stdout without sync | ⚠️ Interleaves | May need SyncWriter |
| Parallel line processing | ❌ No | Sequential by design |
| Command composition | ✅ Yes | Each command independent |

---

## Bottom Line

**Can you use goroutines?** YES ✅

**What works?** Running multiple independent command instances concurrently

**What doesn't work?** Reusing the same command instance or trying to parallelize within a single command

**What's needed?** Just documentation - the framework already supports this safely

