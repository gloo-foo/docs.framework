[![docs](https://github.com/gloo-foo/docs.framework/actions/workflows/docs.yml/badge.svg)](https://github.com/gloo-foo/docs.framework/actions/workflows/docs.yml) [![pages](https://github.com/gloo-foo/docs.framework/actions/workflows/pages.yml/badge.svg)](https://github.com/gloo-foo/docs.framework/actions/workflows/pages.yml)

# docs.framework

The **public documentation** site for [`gloo-foo/framework`](https://github.com/gloo-foo/framework). Built from [`nicerobot/template.repo-docs`](https://github.com/nicerobot/template.repo-docs) as a self-contained [Hugo](https://gohugo.io) site, published to GitHub Pages.

## Layout

| Path | Purpose |
|------|---------|
| [`content/`](content/) | The documentation — Hugo site content. |
| [`layouts/`](layouts/) | Hugo templates. |
| [`hugo.json`](hugo.json) | Hugo configuration. |
| [`.github/workflows/pages.yml`](.github/workflows/pages.yml) | The GitHub Pages build workflow. Always present; it self-skips while the repo is private and deploys once the repo is public. |
| [`Makefile`](Makefile) | Local preview and build. Run `make` for help. |

## Public, with a self-gating workflow

Everything here is **public** — it exists to be published, so there is no `public/`/`private/` split. Anything private (ideas, tasks, specs) belongs in the project's private hub repo, never here.

GitHub Pages is unavailable on private repos in free orgs, so this repo ships ready to go public: the Pages workflow is always present but **self-skips while the repo is private**, deploying automatically once the repo is public and Pages is enabled — there is no file to rename.

## Preview locally

```bash
make serve    # http://localhost:1313
```

## Going public

1. Make the repository public.
2. Enable Pages: **Settings → Pages → Source: GitHub Actions**.
3. Push (or re-run the **pages** workflow). It stops self-skipping and publishes the whole site.
