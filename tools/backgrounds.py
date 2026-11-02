"""제미나이로 그린 배경(방 하나씩)을 게임용으로 정리합니다.

- 창문 안, 하늘처럼 #00FF00으로 칠한 곳은 투명하게 만듭니다. (게임이 실제 하늘을 그 자리에 그림)
- 캐릭터와 같은 픽셀 밀도(게임 좌표 1칸 = 4.2픽셀, 플레이어 키 40칸 = 168픽셀)로 크기를 맞춥니다.

사용: python3 tools/backgrounds.py            (모두)
      python3 tools/backgrounds.py office     (하나만)
원본: art_src/backgrounds/<이름>.webp(.png)  →  결과: assets/backgrounds/<이름>.png
"""
import pathlib
import sys

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
PX_PER_UNIT = 168 / 40           # tools/sprite_sheet.py의 TARGET_H(168) ÷ 플레이어 키(40)

## 배경마다 게임 속 크기 (게임 좌표: 가로, 세로) — scripts/world.gd의 BACKGROUNDS와 같게
SIZES = {
    "office": (260, 110),
    "lecture": (260, 110),
    "storage": (260, 110),
    "bookshop": (260, 110),
    "hall": (160, 220),
}


def build(name):
    src = next(p for p in (ROOT / "art_src" / "backgrounds").glob(name + ".*"))
    a = np.array(Image.open(src).convert("RGB")).astype(np.int32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    green = (g > r + 60) & (g > b + 60) & (g > 150)
    alpha = np.where(green, 0, 255)
    spill = (g > np.maximum(r, b) + 15) & ~green          # 초록이 번진 가장자리
    a[..., 1] = np.where(spill, np.maximum(r, b) + 15, g)
    img = Image.fromarray(np.dstack([np.clip(a, 0, 255), alpha]).astype(np.uint8), "RGBA")
    w, h = SIZES[name]
    img = img.resize((round(w * PX_PER_UNIT), round(h * PX_PER_UNIT)), Image.LANCZOS)
    out = ROOT / "assets" / "backgrounds" / f"{name}.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    img.save(out, optimize=True)
    print(f"{name}: {img.width}×{img.height} (게임 좌표 {w}×{h})")


if __name__ == "__main__":
    for n in sys.argv[1:] or SIZES.keys():
        build(n)
