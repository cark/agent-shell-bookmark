# agent-shell-bookmark

Bring your agent conversations back with your workspace.

This small addon gives [agent-shell](https://github.com/xenodium/agent-shell)
standard Emacs bookmarks. Its goal is to let
[Activities](https://github.com/alphapapa/activities.el) restore agent buffers
alongside your files and window layouts.

A bookmark points to one conversation. It reuses a matching buffer or asks the
agent to resume that exact session. It never substitutes a new conversation.
Activities is optional. Ordinary bookmarks work on their own.

## Install

You need Emacs 29.1 or newer, agent-shell 0.89.5 or newer, and an agent that
supports loading or resuming sessions. Configure agent-shell first.

Clone this repository:

```sh
git clone https://github.com/cark/agent-shell-bookmark.git
```

Add its directory to your Emacs configuration:

```elisp
(add-to-list 'load-path "~/src/agent-shell-bookmark") ; Use your checkout path.
(require 'agent-shell-bookmark)
(agent-shell-bookmark-mode 1)
```

Alternatively, with Emacs 30 or newer:

```elisp
(use-package agent-shell-bookmark
  :vc (:url "https://github.com/cark/agent-shell-bookmark"
       :rev :newest)
  :after agent-shell
  :config
  (agent-shell-bookmark-mode 1))
```

Nix is not needed to install or use the addon. It does not install an agent,
change your authentication, or enable Activities.

## Use

1. Open an agent-shell conversation and wait for its session to start.
2. Press `C-x r m` to save a bookmark.
3. Press `C-x r b` to return to it.

Use `M-x bookmark-save` to save bookmarks to disk. Emacs's `bookmark-save-flag`
controls automatic saving.

If you use Activities, enable this addon before saving an activity. Agent
buffers saved earlier need to be saved again. Activities manages the layout;
this addon restores each conversation.

## What gets saved?

The agent's configured identifier, working directory and session ID. There are
no credentials, executable commands or transcript copies in the record. Session
IDs and directory names are still personal data; treat your bookmark file accordingly.

Your current agent configuration supplies the executable and authentication.
Transcript replay follows agent-shell's own restore settings. The addon does
not save unsent input, scroll positions, model settings or permissions.

The same session in the same directory shares a buffer. Different sessions stay
separate. The first version supports local directories and agents with unique
configuration identifiers. Remote directories are not supported.

If a directory, agent or session is unavailable, you get an ordinary message.
An asynchronous restore failure also appears in the buffer header. Close that
failed buffer, fix the cause, and try the bookmark again. There is no fallback
to another conversation and restoring a bookmark sends no prompt.

## Develop

With Emacs, Git and Python 3 installed:

```sh
./scripts/fetch-test-deps
./scripts/test
```

Tests use pinned upstream libraries and an offline ACP fixture. They need no API
key and make no model calls. Dependencies live in your user cache, outside this
checkout. See [contributing](CONTRIBUTING.md) for Activities checks, compatibility
notes and the optional Nix shell.

## AI assistance and license

OpenAI Codex assisted with the design, code, tests and documentation. Sacha De Vos
maintains this project. AI assistance does not replace testing or maintainer review.

This addon is released under the [MIT license](LICENSE). It is an independent
project, not an official part of agent-shell or Activities. Those projects keep
their own licenses.
