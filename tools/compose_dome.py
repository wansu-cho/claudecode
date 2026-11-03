"""돔 그림의 틈 속 망원경을 LX200(슈미트-카세그레인식) 그림으로 바꿉니다.

art_src/backgrounds/dome_raw.webp (돔) + art_src/views/lx200.webp (망원경)
  → art_src/backgrounds/dome.png  (그다음 tools/backgrounds.py dome 실행)
"""
import pathlib

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
SLIT = (914, 120, 1058, 575)      # 돔 틈 안쪽 (왼쪽, 위, 오른쪽, 아래) — 이 안에만 망원경을 그림
SHIFT = (-29, -309)               # 망원경 그림을 옮기는 양 (경통이 틈 가운데에 보이게)

dome = np.array(Image.open(ROOT / "art_src/backgrounds/dome_raw.webp").convert("RGB"))
x0, y0, x1, y1 = SLIT
d = dome.astype(int)
navy = (d[..., 2] > d[..., 0] + 15) & (d[..., 2] > d[..., 1] + 8) & (d.sum(axis=2) < 170)
# 줄마다 틈 안쪽의 왼쪽·오른쪽 끝: 망원경에 가리지 않은 줄에서 재고 직선으로 이어 줌
rows, lefts, rights = [], [], []
for y in range(y0, y1):
    xs = np.where(navy[y, 880:1110])[0] + 880
    if len(xs) > 40:
        rows.append(y); lefts.append(xs.min()); rights.append(xs.max())
kl = np.polyfit(rows, lefts, 1)
kr = np.polyfit(rows, [max(r, 0) for r in rights], 1)
edge = {}
for y in range(y0, y1):
    l = int(round(np.polyval(kl, y))) + 1
    r = int(round(np.polyval(kr, y))) - 1
    edge[y] = (l, r)
    xs = np.where(navy[y, l:r])[0]
    color = np.median(d[y, l + xs], axis=0) if len(xs) else d[y - 1, l]
    dome[y, l:r] = color.astype(np.uint8)          # 옛 망원경 지우기
tel = np.array(Image.open(ROOT / "art_src/views/lx200.webp").convert("RGB")).astype(int)
g = (tel[..., 1] > tel[..., 0] + 60) & (tel[..., 1] > tel[..., 2] + 60)
ys, xs = np.where(~g)
for y, x in zip(ys, xs):
    tx, ty = x + SHIFT[0], y + SHIFT[1]
    if y0 <= ty < y1 and edge[ty][0] <= tx < edge[ty][1]:
        dome[ty, tx] = tel[y, x]
Image.fromarray(dome).save(ROOT / "art_src/backgrounds/dome.png")
print("dome.png 만듦")
