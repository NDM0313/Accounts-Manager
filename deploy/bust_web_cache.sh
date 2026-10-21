#!/usr/bin/env bash
# Patch Flutter web build so Safari/CF cannot serve a stale main.dart.js.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WEB="$ROOT/build/web"
COMMIT="$(git -C "$ROOT" rev-parse --short HEAD)"
[[ -f "$WEB/index.html" && -f "$WEB/flutter_bootstrap.js" ]] || {
  echo "Missing $WEB — run flutter build web first" >&2
  exit 1
}
python3 - "$WEB" "$COMMIT" <<'PY'
import pathlib, re, sys
web, commit = pathlib.Path(sys.argv[1]), sys.argv[2]
idx = web / "index.html"
boot = web / "flutter_bootstrap.js"
idx_text = idx.read_text()
idx_text = re.sub(
    r'(src="flutter_bootstrap\.js)(\?v=[^"]*)?(")',
    rf'\1?v={commit}\3',
    idx_text,
)
idx.write_text(idx_text)
t = boot.read_text()
t = re.sub(r'main\.dart\.js(\?v=[^"\']*)?', f'main.dart.js?v={commit}', t)
boot.write_text(t)
print(f"cache-bust commit={commit}")
PY
