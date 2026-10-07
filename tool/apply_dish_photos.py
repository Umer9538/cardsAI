"""Turn a photo-sourcing result (tool/dish_photos.json) into assets, taxonomy entries and credits.

Each entry names a 640x640 WebP file, its Openverse id, creator, source page, license and
license URL. Re-run after swapping a photo:
    python3 tool/apply_dish_photos.py tool/dish_photos.json
Turn the photo-sourcing result into assets, taxonomy entries and credits.

usage: python3 apply_photos.py photos.json
"""
import json, os, re, shutil, sys
from PIL import Image

import pathlib
REPO = str(pathlib.Path(__file__).resolve().parent.parent)
photos = json.load(open(sys.argv[1]))
LICENSE_NAME = {'cc0': 'CC0 1.0', 'pdm': 'Public Domain Mark', 'by': 'CC BY'}

chosen = []
for p in photos:
    src = p['file'] if os.path.isabs(p['file']) else os.path.join(REPO, p['file'])
    if not p['file'] or not os.path.exists(src):
        print('no photo:', p['id'], '-', p['note'][:120]); continue
    if p['license'] not in LICENSE_NAME:
        print('REJECT license', p['id'], p['license']); continue
    im = Image.open(src)
    if im.size != (640, 640):
        print('REJECT size', p['id'], im.size); continue
    dest = f"{REPO}/assets/images/dishes/{p['id']}.webp"
    if os.path.abspath(src) != os.path.abspath(dest): shutil.copyfile(src, dest)
    chosen.append(p)

# 1. Dish.asset in the taxonomy.
t = f'{REPO}/lib/core/nutrition/dish_taxonomy.dart'
s = open(t).read()
for p in chosen:
    pat = re.compile(r"(    Dish\(\n      id: '%s',\n(?:      .*\n)*?      minutes: \d+,\n)(      asset: '[^']*',\n)?(    \),)" % re.escape(p['id']))
    m = pat.search(s)
    assert m, p['id']
    s = s[:m.start()] + m.group(1) + f"      asset: 'assets/images/dishes/{p['id']}.webp',\n" + m.group(3) + s[m.end():]
open(t, 'w').write(s)

# 2. Credits, as LegalBlocks appended to the Help page, and a repo-side record.
def lic(p):
    name = LICENSE_NAME[p['license']]
    if p['license'] == 'by' and p['licenseVersion']:
        name += f" {p['licenseVersion']}"
    return name

lines = []
for p in sorted(chosen, key=lambda x: x['id']):
    dish = p['id'].replace('-', ' ')
    creator = p['creator'] or 'unknown'
    lines.append(f"LegalBlock('{p['id']}|{creator}|{lic(p)}'),")

dart = '''import '../../features/settings/presentation/legal_content.dart';
import 'dish_taxonomy.dart';

/// Where each dish photo came from.
///
/// Every tile in the plan builder is an openly licensed photograph (CC0,
/// public domain, or CC BY), found through Openverse and kept at 640×640.
/// CC BY requires the creator to be credited somewhere a person can read, so
/// these render at the foot of the Help page. `assets/images/dishes/ATTRIBUTION.md`
/// holds the full record — source page, license URL, original file.
///
/// Generated from the sourcing run on 4 September 2026; edit by re-running
/// the generator, not by hand, so the two records cannot drift.
abstract final class DishPhotoCredits {
  /// `(dish id, creator, license)`.
  static const List<(String, String, String)> entries = [
%s
  ];

  /// The credits as legal-page blocks: a heading, then one line per photo.
  static List<LegalBlock> get blocks => [
        const LegalBlock('Photo Credits', isHeading: true),
        const LegalBlock(
          'The dish photos in the plan builder are openly licensed '
          'photographs, used with thanks.',
        ),
        for (final (id, creator, license) in entries)
          LegalBlock(
            '${DishTaxonomy.byId(id)?.name ?? id} — $creator, $license',
          ),
      ];
}
''' % '\n'.join(f"    ('{p['id']}', '{(p['creator'] or 'unknown').replace(chr(39), chr(92)+chr(39))}', '{lic(p)}')," for p in sorted(chosen, key=lambda x: x['id']))
open(f'{REPO}/lib/core/nutrition/dish_photo_credits.dart', 'w').write(dart)

md = ['# Dish photo attribution', '', 'Sourced through the Openverse API on 4 September 2026. Every file is a 640×640 WebP crop of the original.', '']
for p in sorted(chosen, key=lambda x: x['id']):
    md += [f"## {p['id']}", f"- Title: {p['title']}", f"- Creator: {p['creator']} ({p['creatorUrl']})",
           f"- License: {lic(p)} — {p['licenseUrl']}", f"- Source: {p['sourceUrl']}", f"- Original: {p['originalUrl']}",
           f"- Openverse id: {p['openverseId']}", '']
open(f'{REPO}/assets/images/dishes/ATTRIBUTION.md', 'w').write('\n'.join(md))
print(f'{len(chosen)} photos applied')
