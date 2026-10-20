"""천문대 마스코트 64x64 도트 스프라이트 시트 생성기 (v2).

실행: python3 make_mascot.py
출력: mascot_spritesheet.png (512x64, 8프레임), mascot_preview.png (확대 미리보기)

프레임 순서: idle 0~3, walk 0~3 (각 64x64, 가로로 나열)

만드는 방식
 1. 부위(머리카락·얼굴·모자·몸…)를 도형으로 칠할 자리를 정한다.
 2. 각 부위의 가장자리 위치로 밝은 면/기본색/그늘을 자동으로 나눈다.
 3. 앞에 있는 부위의 가장자리에는 '그 부위의 가장 어두운 색'으로 윤곽선을 두른다
    (검은 선 하나가 아니라 재질별로 색이 다른 선택적 윤곽선).
 4. 눈·볼터치·입은 마지막에 한 칸씩 직접 찍는다.
"""
import math
from PIL import Image, ImageDraw

SIZE = 64

# 색 단계: o=윤곽선, s=그늘, b=기본, l=밝은 면, h=반짝임
RAMPS = {
    "hair": dict(o=(40, 30, 84), s=(70, 58, 140), b=(104, 92, 196), l=(142, 132, 228), h=(204, 198, 252)),
    "skin": dict(o=(168, 92, 92), s=(240, 176, 150), b=(255, 208, 176), l=(255, 228, 204), h=(255, 242, 226)),
    "hat": dict(o=(22, 24, 64), s=(34, 40, 104), b=(52, 64, 150), l=(84, 102, 204), h=(120, 138, 232)),
    "gold": dict(o=(150, 90, 14), s=(222, 150, 30), b=(255, 206, 62), l=(255, 232, 120), h=(255, 248, 190)),
    "coat": dict(o=(18, 26, 70), s=(28, 54, 126), b=(44, 86, 186), l=(76, 128, 232), h=(130, 176, 250)),
    "cream": dict(o=(112, 120, 170), s=(196, 204, 232), b=(238, 242, 255), l=(255, 255, 255), h=(255, 255, 255)),
    "boot": dict(o=(48, 26, 22), s=(82, 50, 38), b=(120, 76, 54), l=(160, 110, 80), h=(190, 140, 104)),
    "brass": dict(o=(84, 50, 12), s=(150, 100, 30), b=(214, 162, 58), l=(246, 208, 110), h=(255, 236, 170)),
    "lens": dict(o=(40, 70, 130), s=(70, 140, 210), b=(130, 210, 250), l=(190, 238, 255), h=(255, 255, 255)),
}

IRIS_DARK, IRIS_MID, IRIS_GOLD, IRIS_LIGHT = (122, 72, 24), (200, 120, 30), (240, 170, 40), (255, 214, 92)
LASH, WHITE, CHEEK, MOUTH = (58, 32, 44), (255, 255, 255), (255, 140, 150), (140, 50, 60)

# 앞머리 아랫선 높이(가운데에서 바깥쪽으로 |dx| = 0,1,2…). 16칸 이상은 옆머리.
BANG_EDGE = [24, 25, 27, 29, 29, 28, 27, 29, 30, 29, 28, 30, 31, 32, 36, 39]

# 레이어 순서: 클수록 앞. 앞 부위 가장자리에 윤곽선이 그려진다.
TAILS, BOOT, COAT, COLLAR, ARM, SCOPE, HAND, FACE, HAIR, HAT, PIN, DETAIL = range(12)


def mask(draw_fn):
    im = Image.new("L", (SIZE, SIZE), 0)
    draw_fn(ImageDraw.Draw(im))
    px = im.load()
    return {(x, y) for y in range(SIZE) for x in range(SIZE) if px[x, y]}


def ellipse(cx, cy, rx, ry):
    return mask(lambda d: d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=255))


def poly(points):
    return mask(lambda d: d.polygon(points, fill=255))


def thick_line(p, q, w):
    return mask(lambda d: d.line([p, q], fill=255, width=w))


def rect(x0, y0, x1, y1):
    return {(x, y) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1)}


def shift(m, dx=0, dy=0):
    return {(x + dx, y + dy) for x, y in m}


def bezier(p0, p1, p2, p3, t):
    u = 1 - t
    return tuple(u ** 3 * a + 3 * u * u * t * b + 3 * u * t * t * c + t ** 3 * d
                 for a, b, c, d in zip(p0, p1, p2, p3))


def tail_mask(side, sway):
    """쌍갈래 머리. side=-1 왼쪽, +1 오른쪽. 끝으로 갈수록 가늘어진다."""
    s = side
    p0 = (32 + s * 16, 26)
    p1 = (32 + s * 28, 28)
    p2 = (32 + s * 26 + sway, 42)
    p3 = (32 + s * 19 + 2 * sway, 47)

    def draw(d):
        for i in range(0, 51):
            t = i / 50
            cx, cy = bezier(p0, p1, p2, p3, t)
            r = 6.5 * (1 - t) + 2.5 * t
            d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
    return mask(draw)


def ray_tone(m, x, y, near=3):
    """왼쪽 위에서 오는 빛: 오른쪽 아래 가장자리는 그늘, 왼쪽 위 가장자리는 밝게."""
    def steps(dx, dy):
        k = 0
        while (x + dx * (k + 1), y + dy * (k + 1)) in m and k < 8:
            k += 1
        return k
    if steps(1, 1) < near:
        return "s"
    if steps(-1, -1) < near:
        return "l"
    return "b"


class Canvas:
    def __init__(self):
        self.px = {}  # (x,y) -> (order, ramp, tone, color_or_None)

    def paint(self, m, ramp, order, near=3, tone_fn=None, visible=None):
        for (x, y) in m:
            if not (0 <= x < SIZE and 0 <= y < SIZE):
                continue
            if visible is not None and (x, y) not in visible:
                continue
            tone = tone_fn(x, y) if tone_fn else ray_tone(m, x, y, near)
            self.px[(x, y)] = (order, ramp, tone, None)

    def dot(self, x, y, color):
        if 0 <= x < SIZE and 0 <= y < SIZE:
            self.px[(x, y)] = (DETAIL, None, None, color)

    def recolor(self, pts, tone, orders):
        for p in pts:
            e = self.px.get(p)
            if e and e[0] in orders:
                self.px[p] = (e[0], e[1], tone, None)

    def render(self):
        img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        for (x, y), (order, ramp, tone, color) in self.px.items():
            if color is not None:
                img.putpixel((x, y), color + (255,))
                continue
            edge = False
            for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                e = self.px.get(n)
                if e is None or e[0] < order:
                    edge = True
                    break
            img.putpixel((x, y), RAMPS[ramp]["o" if edge else tone] + (255,))
        return img


def star(cx, cy):
    return {(cx, cy - 2), (cx - 1, cy - 1), (cx, cy - 1), (cx + 1, cy - 1),
            (cx - 2, cy), (cx - 1, cy), (cx, cy), (cx + 1, cy), (cx + 2, cy),
            (cx - 1, cy + 1), (cx, cy + 1), (cx + 1, cy + 1), (cx - 1, cy + 2), (cx + 1, cy + 2)}


def eye(c, x0, y0, left, blink):
    if blink:
        for x in range(x0 - 1, x0 + 6):
            c.dot(x, y0 + 3, LASH)
        c.dot(x0 - 1 if left else x0 + 5, y0 + 4, LASH)
        return
    lash_xs = range(x0 - 1, x0 + 5) if left else range(x0, x0 + 6)
    for x in lash_xs:
        c.dot(x, y0, LASH)
    c.dot(x0 - 1 if left else x0 + 5, y0 + 1, LASH)
    rows = [IRIS_DARK, IRIS_MID, IRIS_GOLD, IRIS_GOLD, IRIS_LIGHT]
    for i, col in enumerate(rows):
        for x in range(x0, x0 + 5):
            c.dot(x, y0 + 1 + i, col)
    for x in range(x0 + 1, x0 + 4):
        c.dot(x, y0 + 6, IRIS_LIGHT)
    for (hx, hy) in ((x0 + 1, y0 + 1), (x0 + 2, y0 + 1), (x0 + 1, y0 + 2), (x0 + 2, y0 + 2)):
        c.dot(hx, hy, WHITE)
    c.dot(x0 + 3, y0 + 5, WHITE)


def frame(head_dy=0, body_dy=0, sway=0, blink=False, leg_l=0, leg_r=0):
    c = Canvas()

    # 쌍갈래 머리(맨 뒤)
    for side in (-1, 1):
        c.paint(tail_mask(side, sway), "hair", TAILS)

    # 다리·장화
    for x0, lift in ((26, leg_l), (34, leg_r)):
        c.paint(shift(rect(x0 + 1, 54, x0 + 4, 60), 0, lift), "skin", BOOT)
        c.paint(shift(rect(x0, 59, x0 + 5, 62), 0, lift), "boot", BOOT + 0)

    # 몸(망토 코트)·옷깃·팔
    coat = shift(poly([(24, 44), (40, 44), (43, 56), (21, 56)]), 0, body_dy)
    c.paint(coat, "coat", COAT)
    c.paint(shift(poly([(27, 43), (37, 43), (32, 49)]), 0, body_dy), "cream", COLLAR)
    c.paint(shift(ellipse(21, 50, 3, 5), 0, body_dy), "coat", ARM)
    c.paint(shift(thick_line((41, 46), (46, 54), 5), 0, body_dy), "coat", ARM)

    # 망원경
    barrel = thick_line((46, 55), (53, 53), 5) | thick_line((53, 53), (59, 51), 7)
    c.paint(shift(barrel, 0, body_dy), "brass", SCOPE)
    for (x, y, k) in ((60, 49, "l"), (60, 50, "b"), (60, 51, "b"), (60, 52, "s"), (61, 50, "b"), (61, 51, "s")):
        c.dot(x, y + body_dy, RAMPS["lens"][k])
    c.paint(shift(ellipse(46, 56, 3, 3), 0, body_dy), "skin", HAND)

    # 얼굴·앞머리
    cap = ellipse(32, 27, 18, 15)
    hair_front = {(x, y) for (x, y) in cap
                  if y < (BANG_EDGE[abs(x - 32)] if abs(x - 32) < len(BANG_EDGE) else 40)}
    face_full = ellipse(32, 31, 15, 12)
    face = face_full - hair_front
    c.paint(shift(face, 0, head_dy), "skin", FACE, tone_fn=lambda x, y: ray_tone(shift(face_full, 0, head_dy), x, y))
    # 앞머리가 드리운 그림자
    under = {(x, y + k) for (x, y) in hair_front for k in (1, 2)} & face
    c.recolor(shift(under, 0, head_dy), "s", {FACE})

    c.paint(shift(hair_front, 0, head_dy), "hair", HAIR, near=3)
    # 머리카락 빛 줄기와 가닥 구분선
    gloss = mask(lambda d: (d.arc([15, 14, 49, 40], 198, 262, width=2),
                            d.arc([18, 17, 46, 38], 205, 245, width=1)))
    c.recolor(shift(gloss & hair_front, 0, head_dy), "h", {HAIR})
    for x in (22, 27, 37, 42):
        e = BANG_EDGE[abs(x - 32)]
        c.recolor(shift({(x, e - 1 - k) for k in range(4)} & hair_front, 0, head_dy), "s", {HAIR})

    # 모자와 별 핀
    c.paint(shift(ellipse(36, 12, 12, 6), 0, head_dy), "hat", HAT)
    # 작은 장식(별 핀·머리끈)은 윤곽선 없이 밝은 노랑으로 직접 찍는다
    gold = RAMPS["gold"]
    for (x, y) in star(42, 10):
        c.dot(x, y + head_dy, gold["l"] if (x, y) == (42, 10) else gold["b"])
    for (x, y) in ((44, 11), (43, 12), (41, 12)):
        c.dot(x, y + head_dy, gold["s"])
    for cx in (16, 48):
        for (x, y) in ((cx, 23), (cx - 1, 24), (cx, 24), (cx + 1, 24), (cx, 25)):
            c.dot(x, y + head_dy, gold["b"])
        c.dot(cx, 24 + head_dy, gold["l"])

    # 얼굴 세부(눈·볼터치·입)
    eye(c, 23, 30 + head_dy, True, blink)
    eye(c, 37, 30 + head_dy, False, blink)
    for (x, y) in rect(21, 38, 23, 39) | rect(41, 38, 43, 39):
        c.dot(x, y + head_dy, CHEEK)
    for (x, y) in ((30, 39), (31, 40), (32, 40), (33, 40), (34, 39)):
        c.dot(x, y + head_dy, MOUTH)
    # 단추
    for (x, y) in rect(31, 51, 32, 52) | rect(31, 54, 32, 55):
        c.dot(x, y + body_dy, RAMPS["gold"]["b"])

    return c.render()


FRAMES = [
    dict(),                                              # idle 0
    dict(head_dy=1, sway=1),                             # idle 1 (숨 들이쉼)
    dict(blink=True),                                    # idle 2 (눈 깜빡)
    dict(head_dy=1, sway=-1),                            # idle 3
    dict(leg_l=-2, sway=1),                              # walk 0 (왼발 들기)
    dict(head_dy=1, body_dy=1),                          # walk 1
    dict(leg_r=-2, sway=-1),                             # walk 2 (오른발 들기)
    dict(head_dy=1, body_dy=1),                          # walk 3
]


def build():
    sheet = Image.new("RGBA", (SIZE * len(FRAMES), SIZE), (0, 0, 0, 0))
    for i, spec in enumerate(FRAMES):
        sheet.paste(frame(**spec), (i * SIZE, 0))
    return sheet


def preview(sheet, scale=6, cols=4):
    n = sheet.width // SIZE
    rows = (n + cols - 1) // cols
    w = SIZE * scale
    bg = Image.new("RGBA", (w * cols, w * rows), (24, 26, 48, 255))
    for i in range(n):
        cell = sheet.crop((i * SIZE, 0, (i + 1) * SIZE, SIZE)).resize((w, w), Image.NEAREST)
        bg.alpha_composite(cell, ((i % cols) * w, (i // cols) * w))
    return bg


if __name__ == "__main__":
    sheet = build()
    sheet.save("mascot_spritesheet.png")
    preview(sheet).save("mascot_preview.png")
    sheet.crop((0, 0, SIZE, SIZE)).resize((512, 512), Image.NEAREST).save("mascot_idle0_x8.png")
    print("saved", sheet.size)
