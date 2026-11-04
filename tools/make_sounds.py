"""게임 소리를 코드로 만듭니다. (내려받은 소리가 아니라 직접 합성하므로 저작권 걱정이 없습니다)

결과: assets/sounds/<이름>.wav (22050 Hz, 16비트, 모노)
사용: python3 tools/make_sounds.py
"""
import math
import pathlib
import wave

import numpy as np

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "sounds"
SR = 22050
rng = np.random.default_rng(2141)


def t(sec):
    return np.arange(int(SR * sec)) / SR


def env(n, attack=0.005, decay=0.2):
    x = np.arange(n) / SR
    a = np.clip(x / max(attack, 1e-4), 0, 1)
    return a * np.exp(-x / decay)


def lowpass(x, k):
    """간단한 한 극 저역 통과 (k: 0~1, 작을수록 부드러움)"""
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += k * (v - acc)
        y[i] = acc
    return y


def tone(freq, sec, decay=0.4, harm=(1.0, 0.3, 0.12)):
    x = t(sec)
    s = sum(a * np.sin(2 * math.pi * freq * (i + 1) * x) for i, a in enumerate(harm))
    return s * env(len(x), 0.004, decay)


def save(name, x, gain=0.8):
    x = x / (np.max(np.abs(x)) + 1e-9) * gain
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
    print(name, f"{len(x) / SR:.2f}초")


def mix(*parts):
    n = max(len(p) for _, p in parts)
    out = np.zeros(n)
    for start, p in parts:
        s = int(start * SR)
        out[s:s + len(p)] += p[: max(0, n - s)]
    return out


# 발소리: 나무 바닥을 딛는 짧고 낮은 소리
step = lowpass(rng.normal(0, 1, int(SR * 0.09)), 0.12) * env(int(SR * 0.09), 0.002, 0.025)
step += 0.6 * np.sin(2 * math.pi * 90 * t(0.09)) * env(int(SR * 0.09), 0.001, 0.03)
save("step", step, 0.35)

# 누르기 (단추, 대사 넘기기)
save("click", tone(1400, 0.06, 0.015, (1.0, 0.2)), 0.35)

# 깨달음: 맑은 종소리 세 음 (도-미-솔-도)
save("aha", mix((0, tone(1047, 1.2, 0.5)), (0.09, tone(1319, 1.1, 0.5)), (0.18, tone(1568, 1.0, 0.5)), (0.27, tone(2093, 1.2, 0.6))), 0.6)

# 퀴즈 맞음 / 틀림
save("correct", mix((0, tone(880, 0.3, 0.12)), (0.08, tone(1320, 0.4, 0.18))), 0.5)
save("wrong", mix((0, tone(330, 0.25, 0.1, (1.0, 0.5, 0.3))), (0.1, tone(262, 0.3, 0.12, (1.0, 0.5, 0.3)))), 0.4)

# 사진 찍기: 셔터
shutter = mix((0, rng.normal(0, 1, int(SR * 0.03)) * env(int(SR * 0.03), 0.001, 0.008)),
              (0.06, rng.normal(0, 1, int(SR * 0.05)) * env(int(SR * 0.05), 0.001, 0.012)))
save("shutter", lowpass(shutter, 0.5), 0.5)

# 일지·책 넘기기
page_n = int(SR * 0.35)
page = lowpass(rng.normal(0, 1, page_n), 0.25) * np.sin(np.linspace(0, math.pi, page_n)) ** 2
save("page", page, 0.35)

# 손님이 물건에서 깨어남: 반짝이며 올라가는 소리
sparkle = mix(*[(i * 0.05, tone(880 * 2 ** (i / 6), 0.5, 0.18, (1.0, 0.15))) for i in range(10)])
save("wake", sparkle, 0.45)

# 책장이 밀리는 소리: 낮은 덜컹임
rn = int(SR * 1.4)
rumble = lowpass(rng.normal(0, 1, rn), 0.02) * (0.6 + 0.4 * np.sin(np.linspace(0, 40, rn)) ** 2)
rumble *= np.minimum(1, np.linspace(0, 6, rn)) * np.minimum(1, np.linspace(6, 0, rn))
save("shelf", rumble, 0.6)

# 되감기: 높아지며 빨려 들어가는 바람 소리
wn = int(SR * 3.0)
sweep = np.zeros(wn)
noise = rng.normal(0, 1, wn)
acc = 0.0
for i in range(wn):
    k = 0.02 + 0.25 * (i / wn) ** 2
    acc += k * (noise[i] - acc)
    sweep[i] = acc
sweep *= np.sin(np.linspace(0, math.pi, wn))
save("rewind", sweep, 0.5)

# 밤바다 배경음 (20초, 끝과 처음이 이어지게): 느린 파도 + 낮은 바람
an = int(SR * 20)
waves = lowpass(rng.normal(0, 1, an), 0.03)
x = np.arange(an) / SR
swell = 0.35 + 0.65 * (0.5 + 0.5 * np.sin(2 * math.pi * x / 6.67)) ** 3     # 20초에 세 번 밀려옴
wind = lowpass(rng.normal(0, 1, an), 0.004) * 3.0
amb = waves * swell + 0.4 * wind
fade = int(SR * 2)
amb[:fade] = amb[:fade] * np.linspace(0, 1, fade) + amb[-fade:] * np.linspace(1, 0, fade)   # 이음매 맞추기
amb = amb[:-fade]
save("night_sea", amb, 0.35)
