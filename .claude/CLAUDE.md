# `<repo>.docs` — documentation repository

This is the documentation repository for a source project. It follows [`nicerobot/template.docs`](https://github.com/nicerobot/template.docs).

## Conventions

- **`public/`** is a self-contained [Hugo](https://gohugo.io) site — public-facing docs, rendered by GitHub Pages when the repository is public. Markdown content goes under `public/content/`.
- **`private/`** is internal-only — never built, never published. Specs, design notes, runbooks.
- Documentation for the source project lives **here**, never in the source repository. The source repo carries only a minimal `README.md`.
- The Pages workflow stays **disabled** (`.github/workflows/pages.yml.disabled`) until the repository is public and Pages is enabled.
- Preview locally with `make serve`; build with `make build`.
