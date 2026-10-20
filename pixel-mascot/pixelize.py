"""AI가 만든 캐릭터 그림을 64x64 도트 스프라이트로 정리한다.

사용: python3 pixelize.py 입력.png [출력.png] [--height 52] [--colors 32] [--canvas 64]

하는 일
 1. 배경 지우기: 가장자리에서 시작해 배경색(모서리 색)과 비슷한 영역만 투명하게 만든다.
    (그림 안쪽에 같은 색이 있어도 지워지지 않는다. 이미 투명 PNG면 그 투명도를 쓴다.)
 2. 캐릭터만 잘라 높이를 --height 칸에 맞춰 줄인다. 배경과 섞여 생기는 테두리 번짐을 막기 위해
    캐릭터 영역만으로 평균을 낸다.
 3. 색을 --colors 개로 줄이고, 반투명 없이 완전 투명/불투명 두 가지로 만든다.
 4. 캔버스(--canvas)의 아래쪽 가운데에 놓아 저장한다.
"""
import argparse
from collections import deque

import numpy as np
from PIL import Image


def background_mask(rgb, alpha, tol, keep_inner=False):
    """True = 배경. 이미 투명한 곳과 배경색 영역.
    기본은 그림 속 어디든 배경색과 비슷하면 지운다(팔과 머리 사이 구멍 등).
    keep_inner=True면 가장자리에서 이어진 영역만 지운다."""
    h, w, _ = rgb.shape
    bg = alpha < 128
    corners = np.array([rgb[0, 0], rgb[0, w - 1], rgb[h - 1, 0], rgb[h - 1, w - 1]], dtype=float)
    key = np.median(corners, axis=0)
    close = np.linalg.norm(rgb.astype(float) - key, axis=2) < tol
    close &= alpha >= 128
    if not keep_inner:
        bg |= close
    elif not bg.any() and close[0, 0]:
        seen = np.zeros((h, w), bool)
        q = deque()
        for x in range(w):
            for y in (0, h - 1):
                if close[y, x] and not seen[y, x]:
                    seen[y, x] = True
                    q.append((y, x))
        for y in range(h):
            for x in (0, w - 1):
                if close[y, x] and not seen[y, x]:
                    seen[y, x] = True
                    q.append((y, x))
        while q:
            y, x = q.popleft()
            for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
                if 0 <= ny < h and 0 <= nx < w and close[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    q.append((ny, nx))
        bg |= seen
    return bg


def pixelize(src, height=52, colors=32, canvas=64, tol=100, keep_inner=False):
    im = Image.open(src).convert("RGBA")
    arr = np.array(im)
    rgb, alpha = arr[..., :3], arr[..., 3]
    fg = ~background_mask(rgb, alpha, tol, keep_inner)
    # 가장자리 번짐(배경색이 섞인 경계)을 줄이기 위해 도트 한 칸의 1/4 정도 안쪽으로 깎는다
    from PIL import ImageFilter
    r = max(1, round(0.25 * max(fg.shape) / height / 1.2))
    fg = np.array(Image.fromarray((fg * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(2 * r + 1))) > 127

    ys, xs = np.where(fg)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    rgb, fg = rgb[y0:y1, x0:x1].astype(float), fg[y0:y1, x0:x1].astype(float)

    h, w = fg.shape
    scale = height / h
    tw, th = max(1, round(w * scale)), height
    if tw > canvas - 2:
        scale = (canvas - 2) / w
        tw, th = canvas - 2, max(1, round(h * scale))

    def box(a):
        return np.array(Image.fromarray(a.astype(np.float32), "F").resize((tw, th), Image.BOX))

    cov = box(fg)
    small = np.stack([box(rgb[..., c] * fg) for c in range(3)], axis=2)
    small = small / np.maximum(cov[..., None], 1e-6)
    keep = cov >= 0.5

    flat = Image.fromarray(np.clip(small, 0, 255).astype(np.uint8), "RGB")
    flat = flat.quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    out = np.zeros((th, tw, 4), np.uint8)
    out[..., :3] = np.array(flat)
    out[..., 3] = np.where(keep, 255, 0)

    sheet = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    sheet.paste(Image.fromarray(out, "RGBA"), ((canvas - tw) // 2, canvas - th - 2))
    return sheet


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("dst", nargs="?")
    ap.add_argument("--height", type=int, default=52)
    ap.add_argument("--colors", type=int, default=32)
    ap.add_argument("--canvas", type=int, default=64)
    ap.add_argument("--keep-inner", action="store_true", help="가장자리와 이어진 배경만 지우기")
    ap.add_argument("--tol", type=int, default=100, help="배경색으로 볼 색 차이(클수록 더 많이 지움)")
    a = ap.parse_args()
    dst = a.dst or a.src.rsplit(".", 1)[0] + "_64.png"
    res = pixelize(a.src, a.height, a.colors, a.canvas, a.tol, a.keep_inner)
    res.save(dst)
    big = res.resize((res.width * 8, res.height * 8), Image.NEAREST)
    bg = Image.new("RGBA", big.size, (24, 26, 48, 255))
    bg.alpha_composite(big)
    bg.save(dst.rsplit(".", 1)[0] + "_x8.png")
    print("saved", dst, res.size)
