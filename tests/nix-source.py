#!/usr/bin/env python3
"""Check the actual source exported to Nix, including its invalidation boundary."""
from pathlib import Path
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix="asb-boundary-") as directory:
    fixture = Path(directory)
    (fixture / "scripts").mkdir()
    for name in ("flake.nix", "flake.lock", "scripts/nix-source"):
        shutil.copyfile(root / name, fixture / name)
    def snapshot():
        return Path(subprocess.check_output(["python3", str(fixture / "scripts/nix-source")], text=True).strip())
    before = snapshot()
    assert sorted(p.name for p in before.iterdir()) == ["flake.lock", "flake.nix"]
    for name in (".git", ".direnv", "transcripts", "nested-workspace"):
        (fixture / name).mkdir()
        (fixture / name / "excluded").write_text("private fixture")
    (fixture / "agent-shell-bookmark.el").write_text("source-only edit")
    assert snapshot() == before
    with (fixture / "flake.nix").open("a") as stream:
        stream.write("\n# A tool-definition edit must change the shell source.\n")
    assert snapshot() != before
print("Nix input boundary passed: only two files; source and private data excluded.")
