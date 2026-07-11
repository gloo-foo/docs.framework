---
title: json
---

## Json Command Compatibility

### Summary

There is no single standard Unix `json` binary; `jq` is the closest reference. This command is a focused JSON normalizer/compactor (with sibling selector commands), not a full `jq` expression engine.

### Key Behaviors

```bash
# Compact + key-sort each input line of JSON (jq -c, with sorted keys like jq -S)
$ echo '{"name":"alice","age":30}' | json
{"age":30,"name":"alice"}

# Whitespace is collapsed; keys are re-sorted (output is deterministic)
$ echo '{ "key" : "value" , "num" : 42 }' | json
{"key":"value","num":42}

# One value per line in, one compact value per line out (JSON Lines)
$ printf '{"a":1}\n{"b":2}\n' | json
{"a":1}
{"b":2}

# Arrays and scalars pass through, re-emitted compact (not exploded)
$ echo '[1,2,3]' | json
[1,2,3]
$ echo '"hello"' | json
"hello"

# Invalid JSON is an error, not silent passthrough (validation)
$ echo 'not json' | json
# exits non-zero: json: invalid JSON

# Decode: normalize arbitrary framing into one compact value per line.
# A pretty-printed document collapses to a single compact line...
$ printf '{\n  "name": "alice",\n  "age": 30\n}\n' | json-decode
{"age":30,"name":"alice"}

# ...a single top-level array is streamed element-by-element (jq '.[]')...
$ echo '[{"a":1},{"b":2},3]' | json-decode
{"a":1}
{"b":2}
3

# ...and whitespace/concatenated values are split apart.
$ echo '{"a":1} {"b":2}' | json-decode
{"a":1}
{"b":2}

# Pluck: keep only named fields of each object (jq '{name, age}').
# Objects with none of the fields, and non-objects, are dropped.
$ echo '{"name":"Alice","age":30,"city":"NYC"}' | json-pluck name age
{"age":30,"name":"Alice"}

# Select: keep values matching a condition (jq 'select(...)').
$ printf '{"name":"Alice","age":30}\n{"name":"Charlie"}\n' | json-select has age
{"age":30,"name":"Alice"}
```

### Intentional Divergences

- Not a `jq` expression language. There is no filter DSL — no `.path.to.field`, pipes (`|`), `map`, arithmetic, string interpolation, `reduce`, `to_entries`, functions, or variables. Selection/projection is provided by separate sibling commands (`Decode`, `Pluck`, `Select`) built on a shared streaming core, each composed as a Go pipeline stage rather than a `jq` program string.
- Compact-only output, with keys always sorted. The root command emits compact JSON like `jq -c` and always sorts object keys like `jq -S`; neither behavior is optional. It does not pretty-print (no `jq` default multi-line indentation), and there is no flag to preserve original key order or indentation. Options are currently deferred (`opt.go` declares an empty `flags` struct).
- Line-oriented by default. The root command treats each input line as one independent JSON value (JSON Lines), unlike `jq`, which by default slurps a whole document/stream. Multi-line / pretty-printed / concatenated / single-array input must first pass through `Decode`, which buffers and re-frames it to one compact value per line; downstream commands then stream value-by-value.
- Strict validation. Any line that is not valid JSON aborts the stream with `json: invalid JSON` (root) or `json: invalid input` (Process). There is no `jq -R`/`--raw-input` mode that accepts non-JSON text, and no lenient skip-on-error behavior.
- `Pluck`/`Select` operate only on JSON objects. Non-object values (scalars, arrays) are dropped rather than passed through or queried; `Pluck` also drops any object that retains none of the requested fields. This is a deliberately narrower contract than the equivalent `jq` constructs, which can index and filter any value.
- Numbers are decoded as `float64` and re-encoded by Go's `encoding/json`. Output number formatting follows Go's marshaler, which can differ from `jq`'s libc-based formatting for large or high-precision numbers; there is no big-number/`--arg`-style preservation.
