#!/usr/bin/env python3
"""Build and copy the static documentation to GitHub Pages' main:/docs source."""
from pathlib import Path
import shutil
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
subprocess.run([sys.executable, "-m", "mkdocs", "build", "--strict"], cwd=root, check=True)
published = root / "docs"
if published.exists():
    shutil.rmtree(published)
shutil.copytree(root / "site", published)
(published / ".nojekyll").touch()
print("Generated docs/. Commit this directory together with docs-src/ changes.")
