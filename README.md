# docs.framework

The **public documentation** site for [`gloo-foo/framework`](https://github.com/gloo-foo/framework). Built from [`nicerobot/template.repo-docs`](https://github.com/nicerobot/template.repo-docs) as a self-contained [Hugo](https://gohugo.io) site, published to GitHub Pages.

## Layout

| Path | Purpose |
|------|---------|
| [`content/`](content/) | The documentation — Hugo site content. |
| [`layouts/`](layouts/) | Hugo templates. |
| [`hugo.json`](hugo.json) | Hugo configuration. |
| [`.github/workflows/pages.yml.disabled`](.github/workflows/pages.yml.disabled) | The GitHub Pages build workflow, **disabled** by its `.disabled` suffix (GitHub Actions only runs `*.yml`). |
| [`Makefile`](Makefile) | Local preview and build. Run `make` for help. |

## Public, with a disabled workflow

Everything here is **public** — it exists to be published, so there is no `public/`/`private/` split. Anything private (ideas, tasks, specs) belongs in the project's private hub repo, never here.

GitHub Pages is unavailable on private repos in free orgs, so this repo ships ready to go public: the Pages workflow is present but **disabled** until the repo is public and Pages is enabled.

## Preview locally

```bash
make serve    # http://localhost:1313
```

## Going public

1. Enable Pages: **Settings → Pages → Source: GitHub Actions**.
2. Activate the workflow: `git mv .github/workflows/pages.yml.disabled .github/workflows/pages.yml`
3. Push. The whole site builds and publishes.
