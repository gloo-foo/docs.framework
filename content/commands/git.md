---
title: git
---

## Git Command Compatibility

### Summary

`cmd-git` is a thin wrapper around the real `git` binary, not a reimplementation: it forks `git`, forwards the argument vector, pipes pipeline input to git's stdin, and streams git's stdout onward. For the invocations it forwards, output is git's own and matches real `git` exactly. The wrapper is not transparent, however: it forwards only flag-free invocations and intercepts `--version`, so it is a constrained passthrough, not a drop-in for arbitrary `git` command lines.

### Key Behaviors

```bash
# Forwarded verbatim to git; output is git's own. (Identity/date env pinned for
# reproducibility: GIT_AUTHOR_*/GIT_COMMITTER_* and dates fixed.)

# Flag-free subcommand: reports git's own version.
$ cmd-git version
git version 2.50.1

# Flag-free status on a clean repo: forwarded, byte-identical to git.
$ cmd-git status
On branch main

No commits yet

nothing to commit (create/copy files and use "git add" to track)

# Content-addressed, deterministic: the blob SHA-1 matches real git.
$ printf 'content\n' > f.txt && cmd-git hash-object f.txt
d95f3ad14dee633a758d2e331151e950dd13e4ed

# Flag-free staging: add then write-tree; the tree SHA-1 matches real git.
$ cmd-git add f.txt && cmd-git write-tree
91ccd52a998ef3d846c3e6033d3dc42b4bf15f4a
```

### Intentional Divergences

There is no standard "GNU git" parity contract for this command — `cmd-git` is a wrapper whose contract is "fork git and forward." Its behavior diverges from invoking `git` directly in three documented ways:

- **No flag passthrough.** The wrapper is a `urfave/cli` root command with no registered subcommands, so cli parses the entire argument vector for the root command and rejects any unknown `-flag`/`--flag` token — even one that follows the git subcommand. `cmd-git status --porcelain` exits 1 with `flag provided but not defined: -porcelain` instead of running `git status --porcelain`. Only flag-free invocations (a subcommand plus non-flag operands, e.g. `status`, `add f.txt`, `hash-object f.txt`, `write-tree`) reach git. This is the wrapper's defining limitation.
- **`--version` is intercepted.** The wrapper overrides cli's default version flag, so `cmd-git --version` prints the wrapper's own build version (`git version <appVersion>`, e.g. `git version dev`), not git's. To get git's version, use the flag-free subcommand form `cmd-git version`.
- **No subcommand is a usage error.** A bare `cmd-git` (no arguments) does not reach git; the wrapper rejects it up front with the `ErrNoArgs` sentinel (`git: no git subcommand given`) and exits 1.

The wrapper also drains pipeline input (stdin) to completion before forking git, so it is intended for the gloo pipeline model (a finite upstream source) rather than interactive use.
