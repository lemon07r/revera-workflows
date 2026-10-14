# revera-workflows

Shared [Revera](https://github.com/VeraTools/revera) setup for my
repositories. Every repository runs the same reusable workflow,
[`.github/workflows/revera.yml`](.github/workflows/revera.yml), so models and
settings are changed in one place.

- On a pull request, Revera reviews it and posts findings as comments.
- On a push to the default branch, it refreshes the cached Vera index, so new
  pull requests start with a warm index.
- Fork and Dependabot pull requests are skipped (they get no secrets).

## Enable a repository

```sh
export REVERA_MODEL_BASE_URL=... REVERA_MODEL_API_KEY=...
export REVERA_EMBEDDING_BASE_URL=... REVERA_EMBEDDING_API_KEY=...
./enable.sh lemon07r/some-repo
```

This sets the four secrets and commits
[`caller.yml`](caller.yml) as `.github/workflows/revera.yml` on the default
branch (or opens a pull request if the branch is protected).

## Disable a repository

Delete `.github/workflows/revera.yml` from it. The secrets can stay or be
removed under Settings → Secrets and variables → Actions.

## Rotate a key

Export the new values and run `./enable.sh` again on the same repositories;
it overwrites the secrets and leaves an unchanged workflow alone.
