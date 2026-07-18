---
title: tq
---

## Tq Command

### Summary

`cmd-tq` brings the [tq query language](https://github.com/tsvsheet/tq) — the TSV query language of the tsvsheet ecosystem — into gloo pipelines as a composable command value. It is a thin adapter over the canonical [go-tq](https://github.com/tsvsheet/go-tq) engine, exactly the shape `cmd-json` takes over cirql: the constructor parses the query once, and execution accumulates the stream (tq is whole-table by nature: header, sort, group), runs the program, and emits TSV lines. Between `cut` and `jq`: header-aware column selection, row predicates, derived columns, typed sort, and grouping with aggregates — TSV in, TSV out.

### Key Behaviors

```go
import tq "github.com/gloo-foo/cmd-tq/alias"

// One constructor; the query is the tq language, expressions are tsvsheet formulas.
tq.Tq("select name, stars")                                        // project columns by header name
tq.Tq("where [stars] > 1000 | sort -stars | limit 10")             // filter, typed sort, bound
tq.Tq("derive ratio = round([stars] / [forks], 2)")                // computed column via the tsvsheet engine
tq.Tq("group lang { total = sum([stars]), n = counta([name]) }")   // aggregates over groups
tq.Tq("select [1], [3]", tq.NoHeader)                              // headerless: positional references
tq.Tq("where [price] > 0", tq.Strict)                              // first error value aborts the run
```

The first input line is the header by default and travels through the pipeline; a `.tsvt` input (formula cells) is computed by the tsvsheet engine first, so the query sees values. A syntax error does not fail construction — the returned command emits the error on execution (the `cmd-json` error-command pattern), and go-tq's sentinels (`ErrSyntax`, `ErrUnknownColumn`, `ErrCellRef`, `ErrHeaderless`, `ErrStrict`, `ErrLimit`) flow through for `errors.Is`.

### Intentional Divergences

There is no coreutils counterpart; the parity contract is with the `tq` binary ([tsvsheet/tq.go](https://github.com/tsvsheet/tq.go)), and it is exact by construction: both are thin clients of the same engine, asserted by shared golden triples. Notes:

- **Whole-table semantics.** The adapter buffers via `Accumulate` — like `sort` and `tac`, not like `cut`. Streaming a prefix of row-local stages is a possible future optimization in go-tq, not in this wrapper.
- **Embeds and imports stay off.** The tsvsheet `SHEET`/`IMPORT*` capabilities require injected Loader/Fetcher seams; cmd-tq does not wire them in v1, so those functions yield their disabled error values as data.
- **Everything else is the language.** Semantics questions (the sort total order, error-value handling, column resolution) are answered by the [tq SPECIFICATION](https://github.com/tsvsheet/tq), never by this wrapper.
