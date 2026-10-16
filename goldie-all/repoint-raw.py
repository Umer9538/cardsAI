"""Re-point the copied per-device raw manifests at their copies.

`goldie capture` records ABSOLUTE paths in out/raw/<device>/manifest.json, so
a manifest copied into goldie-all still names the directory it was captured
in. `goldie manifest` then relativises those against goldie-all/out/raw and
emits capture urls like

    raw/../../../goldie/out/raw/iphone-6.9/scan.png

The browser normalises that above the server root, gets the SPA fallback HTML
instead of a PNG, and every tile renders as a broken image inside an empty
bezel - which is exactly what the merged studio did before this ran.
"""
import pathlib
import re
import sys

root = (pathlib.Path(sys.argv[1]) / "out" / "raw").resolve()
for manifest in sorted(root.glob("*/manifest.json")):
    text = manifest.read_text()
    fixed = re.sub(r'"[^"]*?/out/raw/', '"%s/' % root.as_posix(), text)
    if fixed != text:
        manifest.write_text(fixed)
        print("  repointed %s" % manifest.parent.name)
