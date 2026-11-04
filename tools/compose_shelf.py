"""책방 비밀 책장 그림 정리: 책장 오른쪽 끝에 함께 그려진 안락의자 조각을 지웁니다.
(책장이 밀려 움직일 때 의자 조각이 따라가지 않게)

art_src/backgrounds/secret_shelf_raw.webp → art_src/backgrounds/secret_shelf.png
"""
import pathlib

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
SHELF_LEFT = [901, 1665]          # 반쯤 밀림, 다 열림 그림에서 책장 왼쪽 끝 (원본 픽셀)
a = np.array(Image.open(ROOT / "art_src/backgrounds/secret_shelf_raw.webp").convert("RGB"))
for left in SHELF_LEFT:
    a[836:949, left + 185:left + 200] = (0, 255, 0)
Image.fromarray(a).save(ROOT / "art_src/backgrounds/secret_shelf.png")
print("secret_shelf.png 만듦")
