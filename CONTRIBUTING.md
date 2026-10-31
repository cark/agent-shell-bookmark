# Contributing

Keep the addon small. Its job is to restore a saved conversation through Emacs
bookmarks, so Activities can restore the surrounding workspace.

Follow [agent-shell's coding conventions](https://github.com/xenodium/agent-shell/blob/main/CONTRIBUTING.org)
first. Prefer keyword alists, `map.el`, `seq.el`, shallow control flow and named
arguments. Use `cl-lib` only where it adds a clear benefit. Tests use `cl-letf`
and a fixture macro to replace transport boundaries without a mocking framework.

Keep each file focused on one responsibility. Avoid speculative options and
compatibility layers. Review changed files for cohesion and responsiveness, not
just line count. Discuss behavior or compatibility changes before implementing
them. Human-facing text should be concise, readable and free of emoji.

## Run checks without Nix

Install Emacs 29.1 or newer, Git and Python 3. Then run:

```sh
./scripts/fetch-test-deps
./scripts/test
```

The fetch command downloads the revisions in `tests/dependencies.json`.
The test command uses a fresh `emacs -Q --batch` process. It checks syntax,
byte compilation, docstrings, package metadata and behavior. Compiled files go
to a temporary directory and are removed afterward.

Set `EMACS` to choose an Emacs executable. Set `ASB_DEPS` to choose a dependency
cache. By default it is `$XDG_CACHE_HOME/agent-shell-bookmark/deps`, or
`~/.cache/agent-shell-bookmark/deps`. You can also pass extra Emacs arguments:

```sh
./scripts/test -L /path/to/another/library
```

The offline ACP fixture exercises real upstream initialization and session
restoration. It rejects unknown sessions and records requests, so tests can
verify that restoration never starts a new session or sends a prompt.

Activities has a separate integration check described in
[the test guide](tests/README.md). Do not run tests through a working Emacs daemon.
Live checks must use disposable sessions and must not interrupt existing work.

## Optional Nix shell

```sh
./scripts/dev
# Inside the shell:
./scripts/fetch-test-deps
./scripts/test
```

Or run a single command with `./scripts/dev -c ./scripts/test`.
Direnv users can run `direnv allow`; `.envrc` uses the same filtered source.

Use this entry point rather than `nix develop .`. The helper copies only
`flake.nix` and `flake.lock` before invoking Nix. It never imports source code,
Git data, transcripts, caches or nested checkouts. Source edits therefore do not
change the shell input. The shell has no package-source input and does not build
this addon. Emacs, Python, Git and their dependencies still occupy normal Nix
store space. Nothing runs garbage collection or retains extra profiles.

Run `python3 tests/nix-source.py` after changing this boundary. It checks the
actual exported files and verifies that only tool-definition edits invalidate
the snapshot. Update the pin with `./scripts/update-nix-lock`.

## Code map and compatibility

- `agent-shell-bookmark.el` owns records, buffer matching and the opt-in mode.
- `agent-shell-bookmark-session.el` owns the upstream session adapter.
- `tests/` owns fixtures and behavioral checks.

The adapter uses four private upstream entry points: `agent-shell--start`,
`agent-shell--initiate-session`, `agent-shell--initiate-session-resume-by-id`,
and `agent-shell--update-bootstrapping-fragment`.
It also reads the session capability state through `agent-shell--state`.
The public start API cannot suppress focus changes or stop resume fallback.
The fragment API keeps failures in the conversation body across header redraws.
That is why these few private calls are isolated here.

A temporary client-maker wrapper installs the buffer-local guard before
upstream can start asynchronous work. A synchronous startup failure kills the
partially created shell. The wrapper stops arming when startup exits, so it
does not change the policy of later restarts.

Advice is active only for this addon's pending or failed restores. Other shells
retain upstream behavior. Successful restoration returns control to upstream.
Disabling the mode removes bookmark creation from buffers; saved bookmark
handlers remain usable. The failure guard remains for outstanding restores.

The initial record format is version 1. Dependencies are tested at the pinned
revisions, with agent-shell 0.89.5 as the minimum. Newer releases are not assumed
to be compatible merely because their version is higher. Update the pins and
run integration checks before claiming compatibility with an upstream change.

Do not copy agent-shell's implementation into this MIT addon. Reuse its APIs.
When contacting its maintainers, follow their
[communication guidance](https://github.com/xenodium/agent-shell/blob/main/AGENTS.md):
write your own issue comments and PR descriptions, review the code yourself,
and state your level of endorsement. This repository's AI disclosure does not
replace those requirements.
