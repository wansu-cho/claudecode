"""웹 내보내기 결과(build/web)를 인터넷에 올리기 좋게 정리합니다.

- index.wasm(약 38MB)을 gzip으로 압축해 engine.wasm(약 9MB)으로 만듭니다.
- index.pck(게임 데이터)는 gamedata.wasm이라는 이름으로 복사합니다.
  (아티팩트는 .gz, .pck 파일을 올릴 수 없고 .wasm은 올릴 수 있기 때문입니다)
- index.html에 작은 스크립트를 넣어, 브라우저가 index.wasm / index.pck를 요청하면
  위 파일을 대신 받고, gzip이면 브라우저 안에서 압축을 풀도록 합니다.
결과는 build/web_pub 폴더에 생깁니다.
- index.html: 일반 웹 서버용
- artifact.html: claude.ai 아티팩트용 (<html>, <head>, <body> 태그를 뺀 형태.
  아티팩트가 이 틀을 직접 씌우기 때문입니다)

사용: python3 tools/make_web.py
"""
import gzip
import pathlib
import shutil

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "build" / "web"
DST = ROOT / "build" / "web_pub"

SHIM = """<script>
// index.wasm, index.pck 대신 engine.wasm(gzip 압축), gamedata.wasm을 받습니다.
(function () {
  const origFetch = window.fetch.bind(window);
  const MAP = { 'index.wasm': ['engine.wasm', 'application/wasm'], 'index.pck': ['gamedata.wasm', 'application/octet-stream'] };
  window.fetch = function (input, init) {
    const url = (typeof input === 'string') ? input : input.url;
    const m = url && url.match(/(index\\.(wasm|pck))(\\?|$)/);
    if (m) {
      const [file, type] = MAP[m[1]];
      return origFetch(url.replace(m[1], file), init).then(async function (res) {
        if (!res.ok) return res;
        let buf = await res.arrayBuffer();
        const head = new Uint8Array(buf, 0, 2);
        if (head[0] === 0x1f && head[1] === 0x8b) {
          const stream = new Blob([buf]).stream().pipeThrough(new DecompressionStream('gzip'));
          buf = await new Response(stream).arrayBuffer();
        }
        return new Response(buf, { status: 200, headers: { 'Content-Type': type } });
      });
    }
    return origFetch(input, init);
  };
})();
</script>
"""


def strip_skeleton(html: str) -> str:
    import re
    html = re.sub(r"<!DOCTYPE[^>]*>", "", html, flags=re.I)
    html = re.sub(r"</?(html|head|body)[^>]*>", "", html, flags=re.I)
    html = re.sub(r'<meta charset="utf-8">', "", html)
    html = re.sub(r'<meta name="viewport"[^>]*>', "", html)
    # 페이지 위아래 여백(안전 영역)을 빼고 게임 화면을 꽉 채웁니다.
    html = html.replace("html, body, #canvas {", ":root { padding: 0 !important; }\nhtml, body { height: 100%; }\nhtml, body, #canvas {", 1)
    html = html.replace('"ensureCrossOriginIsolationHeaders":true', '"ensureCrossOriginIsolationHeaders":false')
    return html.strip() + "\n"


def main() -> None:
    if DST.exists():
        shutil.rmtree(DST)
    DST.mkdir(parents=True)
    for f in SRC.iterdir():
        if f.name == "index.wasm":
            with open(f, "rb") as src, gzip.open(DST / "engine.wasm", "wb", compresslevel=9) as dst:
                shutil.copyfileobj(src, dst)
        elif f.name == "index.pck":
            shutil.copy(f, DST / "gamedata.wasm")
        elif f.name == "index.html":
            html = f.read_text(encoding="utf-8")
            html = html.replace('<script src="index.js"></script>', SHIM + '\t\t<script src="index.js"></script>', 1)
            (DST / "index.html").write_text(html, encoding="utf-8")
            (DST / "artifact.html").write_text(strip_skeleton(html), encoding="utf-8")
        elif not f.name.endswith(".gz") and not f.name.endswith(".import"):
            shutil.copy(f, DST / f.name)
    for f in sorted(DST.iterdir()):
        print(f"{f.name:32s} {f.stat().st_size / 1e6:7.2f} MB")


if __name__ == "__main__":
    main()
