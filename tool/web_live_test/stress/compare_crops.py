"""Flag text crops that differ from the majority.

The crops sit on an animated starfield, so exact hashes never match. Only
bright pixels (the white text) are compared: each crop becomes a mask of
pixels brighter than 200, and a crop is an outlier when its mask differs
from the per-pixel majority mask by more than THRESHOLD pixels.
Usage: python3 compare_crops.py crops/ > report.md
"""
import glob
import os
import sys

from PIL import Image

THRESHOLD = 40
root = sys.argv[1]
bad_total = 0
for kind in ("relic", "forge"):
    paths = sorted(glob.glob(os.path.join(root, f"{kind}-*.png")))
    if not paths:
        continue
    masks = [[1 if max(p) > 200 else 0 for p in Image.open(f).convert("RGB").getdata()] for f in paths]
    majority = [1 if sum(col) * 2 > len(masks) else 0 for col in zip(*masks)]
    outliers = []
    for f, m in zip(paths, masks):
        diff = sum(a != b for a, b in zip(m, majority))
        if diff > THRESHOLD:
            outliers.append((os.path.basename(f), diff))
    bad_total += len(outliers)
    print(f"### {kind}: {len(outliers)} of {len(paths)} crops differ from the majority")
    for name, diff in outliers:
        print(f"- {name}: {diff} pixels")
print(f"\nRESULT {bad_total} glitched crops")
