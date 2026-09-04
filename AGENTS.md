# Repository Agent Guide

## Scope and Communication

This file applies to the entire repository.

- Keep communication concise. Do not send optional commentary.
- Inspect both staged and unstaged changes before editing or committing.
- Preserve unrelated user changes and never rewrite history or push unless asked.

## Repository Purpose

This is a personal Nix User Repository (NUR) built against nixpkgs unstable.
Its public interfaces are both the flake outputs in `flake.nix` and the classic
NUR entry points in `default.nix`, `overlay.nix`, and `ci.nix`.

Supported systems are:

- `aarch64-darwin`
- `x86_64-linux`

Keep these interfaces compatible when reorganizing internal files. A flake-only
implementation is not sufficient if it breaks NUR evaluation.

## Automatic Discovery

Repository contents are discovered rather than registered by hand.

- Packages live at `pkgs/by-name/<prefix>/<name>/package.nix`. Follow the
  existing two-character prefix convention. Do not add package entries to
  `default.nix` manually.
- `lib/name.nix` or `lib/name/default.nix` accepts `{ lib }` and returns an
  attribute set. Library sets are merged recursively; duplicate leaf attributes
  are errors.
- `apps/name.nix` or `apps/name/default.nix` accepts `{ pkgs }` and returns a
  flake app definition.
- `overlays/name.nix` or `overlays/name/default.nix` evaluates to an overlay.
  The name `default` is reserved for `overlay.nix`.
- A directory's own `default.nix` is its aggregator and is never exported as a
  discovered attribute.

Do not create both `name.nix` and `name/default.nix`; discovery rejects the
duplicate. Matching file and directory symlinks are supported. The explicit
`readFile` forcing in `support/discover.nix` is intentional: on Lix,
`pathExists` and `readFileType` do not reliably identify a dangling file
symlink. Do not simplify that check without equivalent fixture coverage.

Packages must not use the reserved root names `lib` or `overlays`.

`support/reserved-names.nix` must remain exactly synchronized with the special
outputs assembled in `default.nix`. Cross-prefix package collisions and all
reserved-name collisions must fail instead of using last-write-wins merging.

## Overlay Invariant

`overlay.nix` must build the repository with `prev`, not `final`. Importing
`default.nix` with `final` reaches `final.lib` while the overlay fixed point is
still being constructed and causes infinite recursion. Supporting packages that
depend on sibling repository packages would require a separate bootstrap design;
do not make a mechanical `prev` to `final` replacement.

## Flake and CI Semantics

- `legacyPackages` contains packages plus the special NUR namespaces.
- `packages` contains only derivations.
- `checks` contains every package plus repository invariant, formatting, shell,
  and updater checks, so `nix flake check` performs real build smoke tests.
- `ci.nix` is a separate NUR build/cache selector. It filters broken and
  non-free packages from builds and honors `preferLocalBuild` for caching.
  `cachePaths` also includes package-provided fixed-output paths that must be
  retained independently from runtime closures.
  Do not apply the cache policy to local flake checks without a concrete need.
- `apps`, the formatter, packages, and checks must remain available for every
  supported system.
- Pull-request labels and workflow-facing metadata are written in English.
- The `pull_request_target` metadata workflow must never check out or execute
  pull-request-controlled code; its write permissions are only for assignment
  and labels.
- Pull-request README generation is deliberately split across trust boundaries.
  The `pull_request` workflow may evaluate pull-request code but stays read-only.
  The `workflow_run` publisher must never execute pull-request code and may only
  copy a validated `README.md` artifact into the current same-repository head.
- The README publisher requires `UPDATE_PR_TOKEN` and must not fall back to
  `GITHUB_TOKEN`: its commit needs to trigger the normal pull-request workflows.

## Package Sources and Updates

Mutable versions and hashes live in a `hashes.json` beside each package. Package
expressions read that file through an overridable `versionData` argument, which
lets update programs build a candidate without first changing the working tree.
The package table in `README.md` is generated between its section markers from
the discovered package outputs.

- Prefer `nix run .#update-sources` from the repository root over hand-editing
  package hashes.
- Package-specific update programs must be named `update.*`, live below
  `pkgs/by-name`, and be executable in Git.
- Ordinary source updates should modify only the package's `hashes.json` and the
  generated package table in `README.md`.
- Updaters must calculate and fully build candidate data before atomically
  replacing `hashes.json`; failures must leave the tracked file unchanged.
- `scripts/update-readme.sh --check` must fail when package discovery or metadata
  no longer matches the generated README table.
- `UPDATE_PR_TOKEN` should be configured when automated update pull requests
  need to trigger the normal pull-request workflow without manual approval.
- Short-lived upstream assets must be mirrored permanently or exposed through
  a package `cachePaths` list and retained in the binary cache.

`scripts/update-sources.sh` must remain strict and fail-fast. Preserve all of
these properties when editing it:

- `errexit`, `nounset`, and `pipefail` are enabled.
- File enumeration is deterministic and NUL-delimited.
- Ripgrep exit code `1` means no files; exit codes greater than `1` are errors
  and must propagate.
- Failures from file enumeration and package update scripts must never be
  hidden by a conditional or process substitution.

Running the update app may update package versions and dependency hashes.
Do not use it as a casual smoke test in the main working tree; use a temporary
checkout when an end-to-end update test is required.

## Validation

Run checks in proportion to the change. For repository-wide or shared discovery
changes, use the full set below:

```console
nix fmt
nix fmt -- --ci
nix flake check --no-build --all-systems --no-write-lock-file
nix flake check --no-write-lock-file
checks/check-eval-failures.sh
find scripts checks pkgs/by-name -type f -name '*.sh' -exec bash -n {} +
git diff --check
git diff --cached --check
```

Also validate the classic NUR selectors when changing package discovery,
reserved names, overlays, or CI logic:

```console
nix-instantiate --eval -A buildOutputs ci.nix
nix-instantiate --eval -A cacheOutputs ci.nix
nix-instantiate --eval -A cachePaths ci.nix
```

Do not add `--strict` to those derivation-list commands with the current
Lix toolchain: it can terminate the evaluator with status 139 while printing
large derivation values. Use `nix eval` with a small projection when strict JSON
validation is needed.

On an Apple Silicon host, the normal flake check builds the Darwin checks. The
all-systems no-build command only evaluates and instantiates the Linux outputs;
do not report that as an actual `x86_64-linux` build.

When changing `support/discover.nix`, add or run focused fixtures for regular
files, `name/default.nix` directories, both symlink shapes, broken file symlinks,
duplicate names, and reserved names. When changing library merging, cover both
successful nested merges and duplicate nested leaves.

## Documentation and Commits

- Update `README.md` when public outputs, supported systems, discovery rules, or
  maintenance commands change.
- Use focused Conventional Commits matching the existing history.
- Keep `hashes.json` source updates in a separate `build(sources): ...` commit.
- Stage, commit, or push only when explicitly requested.
