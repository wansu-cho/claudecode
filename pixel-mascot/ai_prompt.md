# 천문대 마스코트 – 이미지 AI용 프롬프트 (v1)

## 프롬프트 (영문, 그대로 붙여 넣기)

```
Retro mobile RPG pixel art sprite of a single original chibi girl character, drawn on a 64x64 pixel grid and shown enlarged so that every pixel is a clear, sharp 16x16 square block. Style reference: 2010s mobile action-RPG pixel sprites. Not 8-bit; cute, clean and polished.

Character: an observatory mascot. Super-chibi proportions: the head including hair is about 60-65% of the total height; the whole character is about 50 pixels tall and about 40 pixels wide. She stands in a relaxed idle pose, facing the viewer with a very slight 3/4 turn.
- Hair: very dark navy (not pure black), one long thick braid hanging over her shoulder, with a lighter blue-violet highlight streak on top of the head.
- Eyes: large, with dark brown irises, a thick dark upper lash line and two white highlight pixels in each eye. Small blush marks, tiny smile.
- Hat: a dark indigo beret tilted to one side with a small gold star badge (about 3x3 pixels).
- Outfit: an open dark blue coat with gold trim over a white short top, dark shorts, mismatched socks (one cream, one navy), small brown boots.
- Prop: a small brass telescope held in one hand.

Pixel art rules: visible chunky pixels, nothing smaller than one block. Every outline is exactly 1 pixel wide and is a darker shade of the color it surrounds (dark brown around skin, dark navy around hair and coat), never pure black. Flat cel shading with 3 to 4 tones per material (shadow, base, light), light coming from the upper left. At most 32 colors in total. No anti-aliasing, no gradients, no blur, no dithering, no texture, no glow.

Composition: exactly one character, centered, full body visible, with a margin around her. Flat solid pure magenta background (#FF00FF) filling the whole image, with no floor, no cast shadow, no text and no frame.
```

## 사용 순서

1. 이미지 AI에서 정사각형 1024×1024로 여러 장 만든다.
2. 마음에 드는 한 장을 고른다.
3. `python3 pixelize.py 고른그림.png mascot_64.png` 로 64×64 도트로 정리한다.
   (배경이 자홍색이 아니면 모서리 색을 배경으로 인식해 지운다. `--tol` 로 지우는 정도를 조절.)
4. 결과(`mascot_64.png`, `mascot_64_x8.png`)를 보고 고칠 곳을 정한다.
