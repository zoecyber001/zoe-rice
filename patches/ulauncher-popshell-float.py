#!/usr/bin/env python3
"""
Ulauncher Pop Shell Float Patch
-------------------------------
Patches Ulauncher's window initialization to prevent Pop Shell's tiling engine
from capturing and auto-tiling the launcher window.

Modifications:
  1. Sets role="quake" (Pop Shell hardcoded bypass in window.js)
  2. Sets type_hint=Gdk.WindowTypeHint.DIALOG (excluded from is_tilable())
  3. Adds self.set_wmclass("ulauncher", "Ulauncher") for explicit WM_CLASS

Safe to re-run: skips if already patched.
"""
import sys
import site
import re
from pathlib import Path


def find_ulauncher_window():
    """Locate ulauncher_window.py in user or system site-packages."""
    candidates = [
        Path(site.getusersitepackages()) / "ulauncher" / "ui" / "ulauncher_window.py",
    ]
    for sp in site.getsitepackages():
        candidates.append(Path(sp) / "ulauncher" / "ui" / "ulauncher_window.py")

    for p in candidates:
        if p.is_file():
            return p
    return None


def patch(filepath: Path):
    content = filepath.read_text()

    # Check if already patched
    if 'role="quake"' in content and 'set_wmclass("ulauncher"' in content:
        print("[✓] Already patched. Skipping.")
        return True

    backup = filepath.with_suffix(".py.bak")
    filepath.rename(backup)
    print(f"[*] Backup: {backup}")

    patched = content

    # Patch 1: Add role="quake" to super().__init__
    if 'role="quake"' not in patched:
        patched = patched.replace(
            "resizable=False,",
            'resizable=False,\n            role="quake",\n            type_hint=Gdk.WindowTypeHint.DIALOG,',
        )
        print("[+] Injected role='quake' and type_hint=DIALOG")

    # Patch 2: Add set_wmclass after super().__init__ block
    if 'set_wmclass("ulauncher"' not in patched:
        patched = patched.replace(
            "        # avoid checking layer shell support",
            '        self.set_wmclass("ulauncher", "Ulauncher")\n        # avoid checking layer shell support',
        )
        print('[+] Injected set_wmclass("ulauncher", "Ulauncher")')

    filepath.write_text(patched)
    print(f"[✓] Patched: {filepath}")
    return True


def main():
    target = find_ulauncher_window()
    if not target:
        print("[!] ulauncher_window.py not found. Is Ulauncher installed via pip?", file=sys.stderr)
        return 1

    print(f"[*] Found: {target}")
    if not patch(target):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
