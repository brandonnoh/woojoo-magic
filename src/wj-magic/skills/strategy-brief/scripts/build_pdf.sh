#!/usr/bin/env bash
# strategy-brief: HTML → A4 PDF 빌드 (Chrome headless)
# usage: build_pdf.sh <input.html> [output.pdf]
set -euo pipefail

IN="${1:?input html required}"
OUT="${2:-${IN%.html}.pdf}"

# Chrome 실행 파일 자동 탐색 (macOS / Linux)
CHROME=""
for c in \
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  "/Applications/Chromium.app/Contents/MacOS/Chromium" \
  "$(command -v google-chrome || true)" \
  "$(command -v chromium || true)" \
  "$(command -v chromium-browser || true)"; do
  if [ -n "$c" ] && [ -x "$c" ]; then CHROME="$c"; break; fi
done
[ -z "$CHROME" ] && { echo "Chrome/Chromium not found" >&2; exit 1; }

ABS="file://$(cd "$(dirname "$IN")" && pwd)/$(basename "$IN")"

"$CHROME" --headless --disable-gpu --no-pdf-header-footer \
  --print-to-pdf="$OUT" "$ABS" 2>/dev/null

echo "PDF: $OUT"

# 검증용 이미지 렌더 (pdftoppm 있으면)
if command -v pdftoppm >/dev/null 2>&1; then
  BASE="${OUT%.pdf}_page"
  pdftoppm -png -r 110 "$OUT" "$BASE" 2>/dev/null
  echo "preview: ${BASE}-N.png  (read 툴로 열어 레이아웃을 반드시 확인할 것)"
fi

# 페이지 수
python3 -c "import re;d=open('$OUT','rb').read();print('pages:',len(re.findall(rb'/Type\\s*/Page[^s]',d)))" 2>/dev/null || true
