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
    "yard": (260, 113.6),        # 흙 단면은 잘라 내고 길과 풀까지만 (땅은 ground 조각으로 이어 깖)
    "harbor": (340, 170),
    "ext_left": (260, 220),      # 천문대 외벽 (밖에서 볼 때): 왼쪽 동, 가운데 홀, 오른쪽 동
    "ext_center": (160, 220),
    "ext_right": (260, 220),
    "ground": (258.2, 90.2),       # 땅 단면 (옆으로 이어 붙임)
    "seawall": (60, 120),        # 바닷가 돌 축대
    "roof": (256, 110),          # 옥상 바닥·난간 (옆으로 이어 붙임)
    "roof_stair": (41.8, 61.6),  # 옥상 나선 계단 출구 (계단실)
    "roof_deck": (84.7, 38.5),   # 해넘이 전망대 (계단 3칸 높은 데크)
    "roof_chair": (28.9, 20.9),  # 맨눈 관측 의자
    "dome": (182.7, 152.5),      # 돔 (문 포함)
    "orrery_sun": (60, 60),      # ── 관측 화면 부품 (크기 = 화면 640×360 기준 픽셀) ──
    "orrery_earth": (30, 60.5),
    "orrery_base": (272, 149),
    "pend_dial": (240, 240),
    "pend_bob": (20, 20),
    "lx200": (53.1, 62.0),       # 돔 안의 망원경 (게임 좌표)
    "m42": (300, 300),           # 16인치로 본 오리온대성운 (검은 배경, 더하기 합성)
    "shelf_half": (54.0, 58.5),  # 책방 비밀 책장: 반쯤 밀림 (뒤에 지하 계단 입구)
    "shelf_open": (71.1, 58.5),  # 책방 비밀 책장: 다 열림
    "boat": (175.3, 123.6),      # 돌쇠의 배 (아래 끝 = 물 닿는 선)
    "ferry": (283.5, 83.6),      # 섬 연락선
}
## 원본에서 잘라 쓸 부분 (왼쪽, 위, 오른쪽, 아래) — 옥상은 난간 기둥 가운데에서 잘라야 이음매가 맞음
## 한 원본 그림에서 여러 부품을 잘라 쓸 때: 부품 이름 -> 원본 이름
SOURCE = {"shelf_half": "secret_shelf", "shelf_open": "secret_shelf","orrery_sun": "orrery_parts", "orrery_earth": "orrery_parts", "orrery_base": "orrery_parts",
          "pend_dial": "pendulum_parts", "pend_bob": "pendulum_parts"}
CROPS = {
    "orrery_sun": (148, 324, 496, 672),
    "orrery_earth": (680, 382, 795, 614),
    "orrery_base": (978, 260, 1852, 739),
    "pend_dial": (110, 62, 984, 938),
    "pend_bob": (1486, 462, 1560, 537),
    "lx200": (854, 609, 1146, 950),
    "yard": (0, 0, 1430, 625),
    "ground": (5, 0, 1425, 496),     # 가장자리의 어두운 테두리선을 잘라야 이음매가 안 보임
    "roof": (10, 0, 1418, 605),
    "roof_stair": (290, 609, 521, 948),
    "roof_deck": (631, 736, 1097, 948),
    "roof_chair": (1207, 833, 1366, 948),
    "dome": (497, 110, 1502, 949),
    "boat": (518, 168, 1482, 848),
    "shelf_half": (803, 627, 1100, 949),
    "shelf_open": (1469, 627, 1860, 949),
    "ferry": (220, 388, 1779, 848),
}


def build(name):
    src = next(p for d in ("backgrounds", "views") for p in (ROOT / "art_src" / d).glob(SOURCE.get(name, name) + ".*"))
    a = np.array(Image.open(src).convert("RGB")).astype(np.int32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    green = (g > r + 60) & (g > b + 60) & (g > 150)
    alpha = np.where(green, 0, 255)
    spill = (g > np.maximum(r, b) + 15) & ~green          # 초록이 번진 가장자리
    a[..., 1] = np.where(spill, np.maximum(r, b) + 15, g)
    img = Image.fromarray(np.dstack([np.clip(a, 0, 255), alpha]).astype(np.uint8), "RGBA")
    if name in CROPS:
        img = img.crop(CROPS[name])
    w, h = SIZES[name]
    img = img.resize((round(w * PX_PER_UNIT), round(h * PX_PER_UNIT)), Image.LANCZOS)
    out = ROOT / "assets" / src.parent.name / f"{name}.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    img.save(out, optimize=True)
    print(f"{name}: {img.width}×{img.height} (게임 좌표 {w}×{h})")


if __name__ == "__main__":
    for n in sys.argv[1:] or SIZES.keys():
        build(n)
