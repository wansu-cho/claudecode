"""천문대 마스코트 32x32 도트 스프라이트 시트 생성기.

실행: python3 make_mascot.py
출력: mascot_spritesheet.png (192x32, 6프레임), mascot_preview_x8.png (확대 미리보기)

프레임 순서: idle 0,1 / walk 0,1,2,3  (각 32x32, 가로로 나열)
윤곽선(검남색)은 코드가 자동으로 둘러 주므로 그림에는 그리지 않습니다.
"""
from PIL import Image

SIZE = 32
OUTLINE = (27, 27, 58, 255)

PALETTE = {
    "Y": (255, 216, 74),   # 별·모자 띠(노랑)
    "H": (59, 63, 160),    # 모자 본색(남색)
    "h": (91, 98, 214),    # 모자 밝은 면
    "N": (107, 63, 42),    # 머리카락
    "S": (255, 217, 181),  # 피부
    "s": (240, 180, 138),  # 피부 그늘
    "P": (255, 154, 168),  # 볼터치
    "K": (27, 27, 58),     # 입
    "E": (27, 27, 58),     # 눈
    "W": (255, 255, 255),  # 눈 반짝임
    "B": (46, 111, 216),   # 망토
    "b": (31, 74, 160),    # 망토 그늘
    "G": (90, 58, 42),     # 장화
    "T": (214, 162, 58),   # 망원경 황동
    "t": (156, 111, 30),   # 망원경 그늘
    "C": (140, 220, 255),  # 렌즈
}

# (줄, 시작 x, 그림) — 점(.)은 투명
HEAD = [
    (1, 21, "Y"),
    (2, 20, "YYY"),
    (3, 19, "YYYYY"),
    (4, 20, "YYY"),
    (5, 18, "hHH"),
    (6, 16, "hhHHHH"),
    (7, 13, "hhhHHYHHHH"),
    (8, 10, "hhhhYHHHHHHHHH"),
    (9, 5, "YYYYYYYYYYYYYYYYYYYYYY"),
    (10, 7, "NNNNNNNNNNNNNNNNNN"),
    (11, 7, "NNNNNNNNNNNNNNNNNN"),
    (12, 7, "NNSSNNNSSSSNNNSSNN"),
    (13, 7, "NSSSSSSSSSSSSSSSSN"),
    (14, 7, "SSSSSSSSSSSSSSSSSS"),
    (15, 7, "SSSEEESSSSSSEEESSS"),
    (16, 7, "SSSWEESSSSSSWEESSS"),
    (17, 7, "SSSEEESSSSSSEEESSS"),
    (18, 7, "SPPSSSSSSSSSSSSPPS"),
    (19, 7, "SSSSSSSKSSKSSSSSSS"),
    (20, 7, "SSSSSSSSKKSSSSSSSS"),
    (21, 8, "ssssssssssssssss"),
]
BODY = [
    (22, 11, "BBBBBBBBBB"),
    (23, 9, "BBBBBBBBBBBBBB"),
    (24, 9, "BBBBBBYYBBBBBB"),
    (25, 9, "SBBBBBBBBBBBBS"),
    (26, 11, "bbbbbbbbbb"),
]
SCOPE = [  # 오른손에 든 망원경
    (24, 23, "tT"),
    (23, 24, "TT"),
    (22, 25, "TT"),
    (22, 27, "TT"),
    (21, 28, "TTC"),
    (20, 28, "CC"),
]
LEG_L = [(27, 12, "GGG"), (28, 11, "GGGG")]
LEG_R = [(27, 17, "GGG"), (28, 17, "GGGG")]


def stamp(canvas, rows, dx=0, dy=0):
    for y, x0, text in rows:
        for i, ch in enumerate(text):
            if ch == ".":
                continue
            x, yy = x0 + i + dx, y + dy
            if 0 <= x < SIZE and 0 <= yy < SIZE:
                canvas[(x, yy)] = PALETTE[ch] + (255,)


def add_outline(canvas):
    out = dict(canvas)
    for (x, y) in canvas:
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if (nx, ny) not in canvas and 0 <= nx < SIZE and 0 <= ny < SIZE:
                out[(nx, ny)] = OUTLINE
    return out


def frame(head_dy=0, body_dy=0, left_dy=0, right_dy=0):
    """몸 각 부분을 위아래로 옮겨 동작을 만든다. 겹칠 때는 뒤에 그린 것이 위."""
    c = {}
    stamp(c, LEG_L, dy=left_dy)
    stamp(c, LEG_R, dy=right_dy)
    stamp(c, BODY, dy=body_dy)
    stamp(c, SCOPE, dy=body_dy)
    stamp(c, HEAD, dy=head_dy)
    c = add_outline(c)
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    for (x, y), color in c.items():
        img.putpixel((x, y), color)
    return img


def build():
    # 위쪽 여백 2칸을 쓰도록 전체를 아래로 2칸 내린다.
    shift = 2
    specs = [
        dict(),                                   # idle 0
        dict(head_dy=1),                          # idle 1 (숨 쉬기: 머리만 1칸 내려앉음)
        dict(left_dy=-1),                         # walk 0 (왼발 들기)
        dict(head_dy=1, body_dy=1),               # walk 1 (몸이 살짝 내려감)
        dict(right_dy=-1),                        # walk 2 (오른발 들기)
        dict(head_dy=1, body_dy=1),               # walk 3
    ]
    sheet = Image.new("RGBA", (SIZE * len(specs), SIZE), (0, 0, 0, 0))
    for i, spec in enumerate(specs):
        f = frame(**spec)
        shifted = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        shifted.paste(f, (0, shift))
        sheet.paste(shifted, (i * SIZE, 0))
    return sheet


if __name__ == "__main__":
    sheet = build()
    sheet.save("mascot_spritesheet.png")
    big = sheet.resize((sheet.width * 8, sheet.height * 8), Image.NEAREST)
    bg = Image.new("RGBA", big.size, (24, 26, 48, 255))  # 어두운 밤하늘 배경
    bg.alpha_composite(big)
    bg.save("mascot_preview_x8.png")
    print("saved", sheet.size)
