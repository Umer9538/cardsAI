#!/bin/zsh
# Copy the finished assets from the two capture configs into goldie-all/out
# so one studio can show all three strips.
#
# Copies, not symlinks, on purpose: the studio's design controls write back
# into out/, and a stray re-render here must not reach the real deliverables.
# Re-run this after any capture or re-frame in ../goldie or ../goldie-ipad.
set -e
cd "${0:A:h}"
rm -rf out
mkdir -p out/raw out/screenshots out/previews

for src in ../goldie ../goldie-ipad; do
  for kind in raw screenshots previews; do
    [ -d "$src/out/$kind" ] || continue
    for dev in "$src"/out/$kind/*/; do
      [ -d "$dev" ] || continue
      cp -R "$dev" "out/$kind/$(basename "$dev")"
    done
  done
done

python3 repoint-raw.py "$PWD"
npx -y goldie@0.5.0 manifest >/dev/null
echo "goldie-all/out refreshed:"
for d in out/screenshots/*/; do
  printf "  %-14s %s tiles\n" "$(basename "$d")" "$(ls -1 "$d"en-US/*.png 2>/dev/null | wc -l | tr -d ' ')"
done
