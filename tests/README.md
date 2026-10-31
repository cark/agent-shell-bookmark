# Test guide

## Everyday checks

Run `./scripts/fetch-test-deps`, then `./scripts/test`.

The suite checks saved records, matching buffers, mode teardown, invalid input,
strict restore failures and fresh-process persistence. Regressions also cover
startup-hook exceptions and failure messages surviving window layout changes. A small Python ACP agent
exercises real upstream startup without credentials or model calls.

Fixtures use temporary directories. Test libraries are pinned in
`dependencies.json` and cached outside the repository. No test contacts a working
Emacs daemon. The byte compiler writes only to a temporary directory.

## Activities

```sh
./scripts/fetch-test-deps --activities
./scripts/test-activities
```

This uses real Activities and two offline agent sessions. It saves a two-window
layout, kills its buffers, restores both conversations, then restores again to
check buffer reuse. Activities and its dependencies are optional test libraries;
they are not runtime dependencies of this addon.

The test runs in a fresh batch Emacs with a private profile. For a visual review,
use a separate `emacs -Q` with the same library paths and a disposable profile.
Never load an exit-oriented test runner into your everyday Emacs.

## Live Codex smoke check

This check is opt-in. Configure Codex authentication first, then run:

```sh
./scripts/test-codex
# Or select your existing ACP executable:
ASB_CODEX_COMMAND=/path/to/codex-acp ./scripts/test-codex
```

It creates an empty conversation, saves its bookmark, kills the shell buffer and
resumes the same session. It sends no prompt. The empty conversation may remain
in Codex's own session history. Local test buffers and files are removed.

This verifies session identity with a real backend. It does not claim that every
agent supports replay, or that all agents expose the same session capabilities.

## Nix source boundary

Run `python3 tests/nix-source.py` when changing the flake or its entry helper.
It checks that only the tool definitions enter the Nix source. It also checks
that private files and source edits leave the shell snapshot unchanged.
