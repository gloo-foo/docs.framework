---
title: awk
---

# Awk Command Compatibility

## Summary

Implements awk's record/field processing model (BEGIN, per-record condition + action, END, field splitting, `NR`/`NF`/`FS`/`OFS`/`RS`, variables) as a Go API, but the awk _language_ — patterns and actions written as text — is not parsed; programs are expressed in Go via the `Program` interface.

## Key Behaviors

```bash
# Print a single field by position: awk '{print $2}'
$ echo "one two three" | awk '{print $2}'
two

# Last field via NF: awk '{print $NF}'
$ echo "one two three four" | awk '{print $NF}'
four

# Whole-record access ($0) and NR line numbering: awk '{print NR": "$0}'
$ printf 'first\nsecond\nthird\n' | awk '{print NR": "$0}'
1: first
2: second
3: third

# Field count via NF: awk '{print NF" fields"}'
$ printf 'one two\nthree four five\n' | awk '{print NF" fields: "$0}'
2 fields: one two
3 fields: three four five

# Multiple fields joined with OFS (default single space): awk '{print $1, $3}'
$ echo "one two three four" | awk '{print $1, $3}'
one three

# Custom OFS: awk 'BEGIN{OFS=","} {print $1,$2,$3}'
$ echo "one two three" | awk 'BEGIN{OFS=","}{print $1,$2,$3}'
one,two,three

# Custom field separator: awk -F: '{print $2}'
$ echo "one:two:three" | awk -F: '{print $2}'
two

# Default FS collapses runs of whitespace into field boundaries
$ printf 'alice 30\nbob 25\n' | awk '{print $2, $1}'
30 alice
25 bob

# Pattern match (condition) filters records: awk '/ap/'
$ printf 'apple\nbanana\napricot\n' | awk '/ap/'
apple
apricot

# BEGIN runs once before input
$ echo "data" | awk 'BEGIN{print "Starting processing..."}{print $0}'
Starting processing...
data

# END runs once after all input
$ echo "data" | awk '{print $0} END{print "Processing complete."}'
data
Processing complete.

# Accumulate across records with BEGIN/END: awk 'BEGIN{s=0}{s+=$1}END{print "Sum:",s}'
$ printf '10\n20\n30\n' | awk 'BEGIN{sum=0}{sum+=$1}END{print "Sum:",sum}'
Sum: 60

# Variable supplied at start (-v) used in a condition: awk -v threshold=20 '$1>threshold'
$ printf '10\n25\n30\n15\n' | awk -v threshold=20 '$1>threshold'
25
30

# Stateful dedup using a map variable: awk '!seen[$0]++'
$ printf 'apple\nbanana\napple\ncherry\nbanana\n' | awk '!seen[$0]++'
apple
banana
cherry
```

## Intentional Divergences

- Not an awk-language interpreter. There is no lexer/parser for awk source: patterns and actions are not written as `/regex/ { print $1 }` text. A program is a Go value implementing `Program` (`Begin`/`Condition`/`Action`/`End`), and `SimpleProgram` supplies pass-through defaults. The `# awk ...` lines above are equivalence notes, not accepted input.
- Only the four phases exist. The whole pattern/action machinery reduces to: `Begin` (BEGIN), a single boolean `Condition` (the pattern), a single `Action` returning `(output, emit)` (the action), and `End` (END). There are no multiple pattern/action pairs, no range patterns (`/a/,/b/`), and no per-pattern blocks beyond this one condition + one action.
- No expression language, operators, or control flow of awk's own. Arithmetic, comparison, regex matching, `if`/`for`/`while`, ternaries, etc. are written in Go inside the action, not in awk syntax. `print`/`printf` are not implemented as awk statements; output is the string an action returns. `ctx.Print(...)` joins values with `OFS` (the analogue of `print a, b`), and `fmt.Sprintf` stands in for `printf`.
- No awk built-in functions. `length`, `substr`, `index`, `split`, `sub`, `gsub`, `match`, `sprintf`, `toupper`, `tolower`, `getline`, `system`, math functions, etc. are absent — Go's standard library (`strings`, `strconv`, `fmt`, `regexp`) is used directly instead.
- Field assignment does not rebuild `$0`. `SetField` can set or extend `$1..$NF` (growing the field slice and recomputing `NF`), but it does not re-render `$0` from the fields via `OFS` the way awk does. Reading `$0` still returns the original record.
- Reduced set of built-in variables. `NR`, `NF`, `FS`, `OFS`, and `RS` are present on the context; `NR` increments per record and `NF` reflects the current split. `RS` defaults to `"\n"` but record splitting is fixed to newline-delimited lines — it is not honored as a configurable record separator. Common awk built-ins like `FNR`, `RT`, `FILENAME`, `SUBSEP`, `OFMT`, `CONVFMT`, and the `ARGV`/`ARGC`/`ENVIRON`/`FS`-as-regex behaviors are not modeled.
- `FS` is a literal string, not a regex. The default separator (`" "`) collapses runs of whitespace into field boundaries (matching awk's default), but any explicit `FS` splits on the exact literal string — it is not interpreted as a regular expression, and a single-character `FS` is not special-cased differently from a multi-character one.
- Out-of-range field access returns `""` rather than awk's numeric/empty-string duality; fields are plain strings, with no automatic string/number coercion. Numeric interpretation is the caller's responsibility (e.g. `strconv.Atoi`).
- Variables are an untyped `map[string]any` carrying real Go values (ints, maps, etc.), not awk's string/number scalars and associative-array-only model. `-v name=value` is modeled by `AwkVariable{Name, Value}` with an arbitrary Go value, and there is no automatic initialization of an unset variable to `0`/`""`.
- Self-sourcing differs from awk's file-argument semantics. Positional inputs (file paths or `io.Reader`s) replace the upstream stream, but there is no multi-file `FNR` reset, no `FILENAME`, and no `var=value` operands interleaved between files.
