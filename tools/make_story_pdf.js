// docs/story_src.html → docs/별지기의_마지막_밤_스토리기획서.pdf (크로미엄으로 인쇄)
// 사용: node tools/make_story_pdf.js   (Google Fonts의 Noto Sans/Serif KR을 씀)
const path = require('path');
const { chromium } = require('playwright');
const ROOT = path.resolve(__dirname, '..');
(async () => {
  const b = await chromium.launch();
  const page = await b.newPage();
  await page.goto('file://' + path.join(ROOT, 'docs', 'story_src.html'), { waitUntil: 'networkidle' });
  await page.evaluate(() => document.fonts.ready);
  const out = path.join(ROOT, 'docs', '별지기의_마지막_밤_스토리기획서.pdf');
  await page.pdf({
    path: out, format: 'A4', printBackground: true, displayHeaderFooter: true,
    headerTemplate: '<div></div>',
    footerTemplate: '<div style="font-size:8px;width:100%;text-align:center;color:#888">별지기의 마지막 밤 · 스토리 기획서 v3 · <span class="pageNumber"></span></div>',
    margin: { top: '16mm', bottom: '16mm', left: '15mm', right: '15mm' },
  });
  await b.close();
  console.log(out);
})();
