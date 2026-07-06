---
title: Command Concurrency Analysis
---

# Command-Level Concurrency Analysis

This document analyzes concurrency considerations for specific command implementations, separate from the framework-level analysis.

---

## Awk Command Analysis

The awk command has specific concurrency considerations due to its stateful nature.

### ⚠️ Mixed Safety Profile

#### 1. Context Structure

```go
type Context struct {
    Fields    []string
    NR        int64
    NF        int
    FS        string
    OFS       string
    Variables map[string]any
    RS        string
}
```

**Status**: ⚠️ **NOT Goroutine-Safe**

- Mutable state (`Fields`, `NR`, `Variables`)
- No synchronization primitives
- Designed for single-threaded line processing

**Issue**: If you tried to process lines concurrently:

```go
// ❌ UNSAFE: Race condition on ctx.NR and ctx.Variables
for scanner.Scan() {
    go func(line string) {  // DON'T DO THIS
        ctx.NR++  // Race condition!
        output, emit := program.Action(ctx)  // Race on Variables
    }(scanner.Text())
}
```

#### 2. Program Interface

```go
type Program interface {
    Begin(ctx *Context) error
    Condition(ctx *Context) bool
    Action(ctx *Context) (string, bool)
    End(ctx *Context) (string, error)
}
```

**Status**: ⚠️ **Implementation-Dependent**

- Interface itself is safe
- Safety depends on whether Program implementations mutate shared state
- Current usage pattern is single-threaded

**Current Design**: Sequential processing

```go
// Current (single-threaded):
for scanner.Scan() {
    ctx.NR++
    // ... split fields ...
    if program.Condition(ctx) {
        output, emit := program.Action(ctx)
        if emit {
            fmt.Fprintln(stdout, output)
        }
    }
}
```

### Why Awk is Sequential by Design

1. **Line Numbers Matter**: `NR` (record number) is a fundamental awk variable
2. **Stateful Variables**: BEGIN/END blocks and variables maintain state across lines
3. **Order Semantics**: Awk programs expect lines to be processed in order
4. **I/O Bound**: Most awk operations are I/O bound, not CPU bound

---

## Potential Awk Concurrency Enhancements

### Level 3: Awk-Specific Concurrency (Effort: High, Value: Low)

**Goal**: Enable parallel line processing in awk

**Challenge**: Awk's design is inherently sequential:

- `NR` (line number) is meaningful in order
- `Variables` may have dependencies between lines
- `BEGIN` and `END` blocks are sequential by nature

### Possible Approaches

#### Option A: Parallel Action with Sequential Context

```go
// Parallel processing with sequential line numbers
type ParallelAwkProgram interface {
    Program
    ParallelAction(ctx *Context) (string, bool) // Thread-safe action
}

// Framework provides:
// - Workers process lines in parallel
// - Each worker gets its own Context copy
// - Line numbers are assigned before parallel dispatch
// - Results are ordered by line number before output
```

#### Option B: Explicit Parallel Programs

```go
type MapReduceProgram interface {
    Map(lineNum int64, line string) (key, value any)      // Parallel
    Reduce(key any, values []any) (output string)         // Parallel per key
}
```

### Reality Check

- **Semantic compatibility**: True awk parallelism breaks semantic guarantees
- **Performance**: Most awk programs are fast enough sequentially
- **Alternative**: Users wanting parallel text processing should use a different tool
- **Recommendation**: Keep awk sequential to match Unix semantics

---

## Other Stateful Commands

Commands with similar considerations to awk:

### `uniq` Command

- Compares consecutive lines
- Requires sequential processing to detect duplicates
- Cannot parallelize without buffering entire input

### `nl` Command

- Numbers lines sequentially
- Line numbers must be in order
- Naturally sequential

### Commands with `NR`-like State

Any command that:

- Maintains line counters
- Compares current line to previous
- Has BEGIN/END blocks
- Uses stateful variables

These all benefit from the framework's sequential line processing design.

---

## Stateless Commands (Easily Concurrent)

These commands can run many instances concurrently without issues:

### `cat`

- Pure streaming, no state
- Multiple instances can process different files simultaneously

### `grep`

- Pattern matching per line
- No cross-line state
- Highly parallelizable at the command instance level

### `tr`

- Character translation per line
- No state between lines
- Perfect for concurrent execution

### `cut`

- Field extraction
- No cross-line dependencies
- Safe for parallel instances

---

## Recommendation for Command Developers

When implementing commands:

1. **Prefer stateless designs** where possible
2. **Use the framework's sequential helpers** (LineTransform, StatefulLineTransform)
3. **Don't try to parallelize within a single command** - let users run multiple instances
4. **Document any stateful behavior** that affects concurrency

### Pattern: Stateless Command

```go
func (c command) Executor() yup.CommandExecutor {
    return yup.LineTransform(func(line string) (string, bool) {
        // No state - safe to run many instances concurrently
        return processLine(line), true
    }).Executor()
}
```

### Pattern: Stateful Command (Sequential by Nature)

```go
func (c command) Executor() yup.CommandExecutor {
    return yup.StatefulLineTransform(func(lineNum int64, line string) (string, bool) {
        // Uses lineNum - framework handles this sequentially
        return fmt.Sprintf("%d: %s", lineNum, line), true
    }).Executor()
}
```

---

## Summary

| Command Type | Concurrency Level | Recommendation |
| --- | --- | --- |
| Stateless (cat, grep, tr) | ✅ High | Run multiple instances |
| Stateful (awk, uniq, nl) | ⚠️ Sequential | One instance, sequential processing |
| Custom with state | ⚠️ Varies | Use framework helpers, document behavior |

The framework's design naturally supports the most useful concurrency pattern: **running multiple independent command instances**, while keeping individual command implementations simple and sequential.
