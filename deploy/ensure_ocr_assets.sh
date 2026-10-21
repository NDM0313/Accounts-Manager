#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OCR="$ROOT/web/ocr"
LANGD="$OCR/lang"
mkdir -p "$LANGD"
need() { [[ -s "$1" ]] || return 0; return 1; }
if [[ ! -s "$OCR/tesseract.min.js" ]]; then
  curl -fsSL -o "$OCR/tesseract.min.js" "https://cdn.jsdelivr.net/npm/tesseract.js@5.1.1/dist/tesseract.min.js"
  curl -fsSL -o "$OCR/worker.min.js" "https://cdn.jsdelivr.net/npm/tesseract.js@5.1.1/dist/worker.min.js"
  curl -fsSL -o "$OCR/tesseract-core.wasm.js" "https://cdn.jsdelivr.net/npm/tesseract.js-core@5.1.1/tesseract-core.wasm.js"
fi
if [[ ! -s "$LANGD/eng.traineddata" ]]; then
  curl -fsSL -o "$LANGD/eng.traineddata" "https://cdn.jsdelivr.net/gh/naptha/tessdata@gh-pages/4.0.0/eng.traineddata"
fi
echo "OCR assets ready under web/ocr"
