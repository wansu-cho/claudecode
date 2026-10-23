# 별지기의 마지막 밤 (시제품)

어린이천문대 아이들이 수업 뒤 집에서 혼자 하는 **시간 루프 천문 탐험 게임**입니다.
같은 겨울밤이 반복되는 섬 천문대에서, 실제 밤하늘을 관측해 증거를 모으고 유물에서 깨어난 사람들을 아침으로 보내 줍니다.

- 기획 내용과 시제품 정답: [docs/기획서.md](docs/기획서.md)
- 엔진: Godot 4.5 (GDScript)
- 그림은 아직 임시입니다. (정식 그림은 제미나이로 만든 뒤 정리해서 넣을 예정)

## 실행 방법

1. Godot 4.5를 실행하고 **가져오기(Import)**로 이 폴더의 `project.godot`을 엽니다.
2. **F5**를 누르면 시작합니다.

## 조작

| 동작 | 키보드 | 폰 |
|---|---|---|
| 이동 | ← → 또는 A D | 화면 왼쪽을 누른 채 좌우로 끌기 |
| 점프 | Space, W, ↑ | 화면 오른쪽 탭 |
| 확인, 대화 | E, Enter | [눌러서 …] 말풍선 탭 |
| 관측 일지 | J | 위쪽 버튼 |
| 전체 화면 | F11 | — |

## 웹 버전 만들기

1. Godot 메뉴 **프로젝트 → 내보내기 → Web**으로 `build/web/`에 내보냅니다. (`export_presets.cfg`에 설정이 들어 있습니다)
2. `python3 tools/make_web.py`를 실행하면 `build/web_pub/`에 올리기 좋은 파일이 생깁니다.
   - 엔진 파일(38MB)을 압축해 `engine.wasm`(9MB)으로 만들고, 브라우저에서 풀어 씁니다.

## 폴더 구성

| 위치 | 내용 |
|---|---|
| `scripts/story.gd` | **이야기, 대사, 관측 일지 글이 모두 여기 있습니다.** 대사를 고칠 때는 이 파일만 고치면 됩니다. |
| `scripts/game.gd` | 시각, 몇 번째 밤, 관측 일지, 저장 |
| `scripts/astro.gd` | 실제 별 위치 계산 (2026년 12월 20일, 북위 34°) |
| `scripts/sky_painter.gd` | 밤하늘 그리기 |
| `scripts/world.gd` | 섬 풍경, 걷기, 등장인물 시간표 |
| `scripts/main.gd` | 게임 흐름, 대화와 증거 제시 |
| `scripts/views/` | 망원경 화면, 푸코 진자 화면 |
| `scripts/ui/` | 대사창, 관측 일지, 위아래 정보 띠, 안내판 |
| `scripts/sprites.gd` | 임시 캐릭터 그림 |
| `scripts/ui/touch_pad.gd` | 폰용 가상 키패드 (왼쪽 끌기 이동, 오른쪽 탭 점프) |
| `tools/make_web.py` | 웹 버전 정리 도구 |
| `tests/autoplay.gd` | 자동 점검 (시제품을 처음부터 끝까지 풀어 봄) |
| `legacy/` | 예전 수업용 게임 「프로젝트 골든 레코드」 (Godot에서는 무시됨) |

## 자동 점검

```
godot --path . --script res://tests/autoplay.gd
```

끝까지 문제없이 풀리면 `AUTOPLAY OK`가 출력됩니다.
