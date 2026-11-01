"""제미나이로 만든 초록 배경 캐릭터 시트를 게임용 그림 묶음(아틀라스)으로 바꿉니다.

하는 일
  1. 칸 구분선(짙은 초록 선)을 찾아 칸을 나눕니다.
  2. 초록 배경을 투명하게 하고, 가장자리에 남은 초록 기운을 지웁니다.
  3. 사람마다 키를 맞춥니다. (대기 1번째 칸의 키를 TARGET_H 픽셀로)
  4. 같은 동작 줄에서는 발끝을 같은 높이에 맞추고, 칸 가운데를 몸의 가운데로 삼습니다.
  5. 모든 칸을 같은 크기로 한 장에 모아 PNG로, 칸 정보는 JSON으로 저장합니다.

사용: python3 tools/sprite_sheet.py hero
      python3 tools/sprite_sheet.py keti
원본: art_src/sheets/<이름>.webp  →  결과: assets/sprites/<이름>.png, <이름>.json
"""
import json
import pathlib
import sys

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
TARGET_H = 168           # 아이 캐릭터의 키 (원본 픽셀). 게임에서는 약 46칸 높이로 그립니다.
PAD = 4

## 시트마다: 줄마다 [동작 이름, 칸 수, 초당 프레임, 발끝 맞춤 여부]의 목록 (한 줄에 동작 여러 개 가능)
##   height: 키 배율 (아이 = 1.0, 테오는 형이라 1.15)
SHEETS = {
    "hero": {
        "rows": [[["idle", 4, 4, True]], [["walk", 6, 10, True]], [["jump", 3, 0, True]],
                 [["look", 1, 0, True]], [["scope", 1, 0, True]], [["face", 5, 0, False]]],
        "height": 1.0,
    },
    "keti": {
        "rows": [[["idle", 4, 4, True]], [["walk", 6, 10, True]], [["wake", 4, 3, True]], [["face", 5, 0, False]]],
        "height": 1.0,
    },
    "teo": {
        "rows": [[["idle", 4, 4, True]], [["walk", 6, 10, True]], [["wake", 4, 3, True], ["point", 1, 0, True]],
                 [["face", 5, 0, False]]],
        "height": 1.15,
    },
    "dolsoe": {
        "rows": [[["idle", 4, 4, True]], [["walk", 6, 10, True]], [["wake", 4, 3, True], ["point", 1, 0, True]],
                 [["face", 5, 0, False]]],
        "height": 1.3,
    },
    "bori": {
        "rows": [[["idle", 4, 4, True]], [["walk", 6, 10, True]], [["wake", 4, 3, True], ["count", 1, 0, True]],
                 [["face", 5, 0, False]]],
        "height": 1.0,
    },
    "ina": {
        "rows": [[["idle", 4, 4, True]], [["walk", 6, 10, True]], [["wake", 4, 3, True], ["gaze", 1, 0, True]],
                 [["face", 5, 0, False]]],
        "height": 1.0,
    },
}


def _runs(flags):
    out, start = [], None
    for i, f in enumerate(flags):
        if f and start is None:
            start = i
        elif not f and start is not None:
            out.append((start, i - 1))
            start = None
    if start is not None:
        out.append((start, len(flags) - 1))
    return out


def grid_cells(a):
    """짙은 초록 칸 구분선 사이의 칸 경계 [(시작, 끝)]"""
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    line = (g > r + 30) & (g > b + 30) & (g < 170)
    rows = _runs(line.mean(axis=1) > 0.5)
    cols = _runs(line.mean(axis=0) > 0.5)
    between = lambda ls: [(ls[i][1] + 3, ls[i + 1][0] - 3) for i in range(len(ls) - 1)]
    return between(rows), between(cols)


def key_out(c):
    """초록 배경 → 투명, 가장자리의 초록 기운 제거"""
    c = c.astype(np.int32)
    r, g, b = c[..., 0], c[..., 1], c[..., 2]
    bg = (g > r + 45) & (g > b + 45) & (g > 120)
    alpha = np.where(bg, 0, 255)
    # 초록이 번진 가장자리: 초록을 빨강·파랑 중 큰 값으로 낮춤
    spill = (g > np.maximum(r, b) + 10) & ~bg
    c[..., 1] = np.where(spill, np.maximum(r, b) + 10, g)
    # 1픽셀 두께의 초록 테두리는 지움
    near = np.zeros_like(bg)
    near[1:, :] |= bg[:-1, :]
    near[:-1, :] |= bg[1:, :]
    near[:, 1:] |= bg[:, :-1]
    near[:, :-1] |= bg[:, 1:]
    alpha = np.where(near & spill, 0, alpha)
    return np.dstack([np.clip(c, 0, 255), alpha]).astype(np.uint8)


def build(name):
    spec = SHEETS[name]
    src = np.array(Image.open(ROOT / "art_src" / "sheets" / f"{name}.webp").convert("RGB"))
    rows, cols = grid_cells(src)
    frames = {}                       # (줄, 칸) -> RGBA 배열
    for ri, segs in enumerate(spec["rows"]):
        y0, y1 = rows[ri]
        for k in range(sum(seg[1] for seg in segs)):
            x0, x1 = cols[k]
            frames[(ri, k)] = key_out(src[y0:y1, x0:x1])

    # 키 맞춤: 대기 1번째 칸의 키
    a0 = frames[(0, 0)][..., 3] > 0
    ys = np.where(a0.any(axis=1))[0]
    scale = TARGET_H * spec["height"] / (ys.max() - ys.min() + 1)

    out_frames = []                   # [이미지, 발끝 y(축소 후), 가운데 x]
    anims = {}
    for ri, segs in enumerate(spec["rows"]):
        col = 0
        for anim, count, fps, feet in segs:
            imgs = []
            for k in range(col, col + count):
                im = Image.fromarray(frames[(ri, k)], "RGBA")
                im = im.resize((round(im.width * scale), round(im.height * scale)), Image.LANCZOS)
                imgs.append(im)
            col += count
            bottoms = [np.where(np.array(im)[..., 3].any(axis=1) > 0)[0].max() for im in imgs]
            base = max(bottoms) if feet else None
            idx = []
            for k, im in enumerate(imgs):
                idx.append(len(out_frames))
                out_frames.append([im, base if feet else bottoms[k], im.width / 2.0])
            anims[anim] = {"frames": idx, "fps": fps}

    # 모든 칸을 같은 크기로: 발끝(앵커)을 같은 자리에
    above = max(f[1] for f in out_frames) + PAD
    below = max(f[0].height - f[1] for f in out_frames) + PAD
    half = max(max(f[2], f[0].width - f[2]) for f in out_frames) + PAD
    fw, fh = int(np.ceil(half * 2)), int(np.ceil(above + below))
    cols_n = 6
    rows_n = (len(out_frames) + cols_n - 1) // cols_n
    atlas = Image.new("RGBA", (fw * cols_n, fh * rows_n), (0, 0, 0, 0))
    for i, (im, feet_y, cx) in enumerate(out_frames):
        ox = (i % cols_n) * fw + round(half - cx)
        oy = (i // cols_n) * fh + round(above - feet_y)
        atlas.alpha_composite(im, (ox, oy))
    out_dir = ROOT / "assets" / "sprites"
    out_dir.mkdir(parents=True, exist_ok=True)
    atlas.save(out_dir / f"{name}.png", optimize=True)
    meta = {
        "frame_w": fw, "frame_h": fh, "cols": cols_n,
        "anchor": [round(half), round(above)],      # 칸 안에서 발끝 가운데 위치
        "body_h": round(TARGET_H * spec["height"]),
        "height": spec["height"],                   # 아이 키를 1로 했을 때 이 사람의 키
        "anims": anims,
    }
    (out_dir / f"{name}.json").write_text(json.dumps(meta, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"{name}: {len(out_frames)}칸, 칸 크기 {fw}×{fh}, 그림 {atlas.width}×{atlas.height}, 배율 {scale:.3f}")


if __name__ == "__main__":
    for n in sys.argv[1:] or SHEETS.keys():
        build(n)
