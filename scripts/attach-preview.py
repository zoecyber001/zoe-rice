#!/usr/bin/env python3
"""
Architect's Note:
Dotfiles Screenshot Optimizer & Asset Attacher
----------------------------------------------
Finds the latest screenshot taken via GNOME's native screenshot UI,
optimizes its compression without visual fidelity loss, and saves it
directly into the repo's assets/ folder for README embedding.

Usage:
    python3 scripts/attach-preview.py             # Attaches latest screenshot as assets/preview.png
    python3 scripts/attach-preview.py ulauncher   # Attaches latest screenshot as assets/ulauncher.png
    python3 scripts/attach-preview.py studio      # Attaches latest screenshot as assets/studio.png
"""

import sys
import os
import shutil
import subprocess
from pathlib import Path
from PIL import Image

REPO_DIR = Path(__file__).resolve().parent.parent
ASSETS_DIR = REPO_DIR / "assets"
ASSETS_DIR.mkdir(parents=True, exist_ok=True)

SCREENSHOTS_DIR = Path.home() / "Pictures" / "Screenshots"

def get_latest_screenshot() -> Path | None:
    if not SCREENSHOTS_DIR.is_dir():
        return None
    candidates = list(SCREENSHOTS_DIR.glob("*.png")) + list(SCREENSHOTS_DIR.glob("*.jpg"))
    if not candidates:
        return None
    # Sort by modification time, newest first
    candidates.sort(key=lambda p: p.stat().st_mtime, reverse=True)
    return candidates[0]

def optimize_and_save(src_path: Path, dest_path: Path):
    print(f"[*] Reading screenshot: {src_path.name} ({src_path.stat().st_size // 1024} KB)")
    with Image.open(src_path) as im:
        w, h = im.size
        print(f"[*] Resolution: {w}x{h}")
        # Save optimized PNG
        im.save(dest_path, "PNG", optimize=True)
    
    new_size = dest_path.stat().st_size // 1024
    print(f"[✓] Saved to: {dest_path.relative_to(REPO_DIR)} ({new_size} KB)")

def main():
    target_name = sys.argv[1] if len(sys.argv) > 1 else "preview.png"
    if not target_name.endswith(".png"):
        target_name += ".png"
    
    dest_file = ASSETS_DIR / target_name
    latest = get_latest_screenshot()
    
    if not latest:
        print("[!] No screenshots found in ~/Pictures/Screenshots/")
        print("    Press Super+Shift+S or Print on your keyboard to take a screenshot first.")
        sys.exit(1)
        
    optimize_and_save(latest, dest_file)
    
    # Auto-commit to git if inside repo
    try:
        subprocess.run(["git", "-C", str(REPO_DIR), "add", str(dest_file)], check=True)
        subprocess.run(["git", "-C", str(REPO_DIR), "commit", "-m", f"chore(assets): attach {target_name}"], check=True)
        print(f"[✓] Committed {target_name} to git.")
    except Exception as e:
        print(f"[!] Git commit skipped: {e}")

if __name__ == "__main__":
    main()
