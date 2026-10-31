# Project guidance

Read [CONTRIBUTING.md](CONTRIBUTING.md) before changing code or tooling.
Agent-shell's linked guidance takes precedence over the local coding preferences.
Keep this addon independent; do not patch or vendor upstream implementations.

Use focused files, standard Emacs interfaces and one proportionate acceptance
pass. Avoid unnecessary abstraction and customization. Check whole-file cohesion,
error paths and asynchronous focus behavior. Discuss unsettled compatibility
choices before implementing them.

Preserve the user's working Emacs, buffers and window layout. Automated checks
run in separate batch processes; interactive checks use a separate test Emacs.
Do not install into a live setup or publish changes without owner authorization.

Keep documentation short, clear and free of emoji. Disclose AI assistance. Do not
claim human review, live backend testing or a successful check without evidence.
Use the filtered Nix entry point in CONTRIBUTING.md. Never import private data
or caches into the Nix source, and do not run automatic garbage collection.
