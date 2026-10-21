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
import pathlib, sys
web, commit = pathlib.Path(sys.argv[1]), sys.argv[2]
idx = web / "index.html"
boot = web / "flutter_bootstrap.js"
idx.write_text(
    idx.read_text().replace(
        'src="flutter_bootstrap.js"',
        f'src="flutter_bootstrap.js?v={commit}"',
    ).replace(
        f'src="flutter_bootstrap.js?v={commit}?v=',
        f'src="flutter_bootstrap.js?v=',
    )
)
t = boot.read_text()
t = t.replace('"main.dart.js"', f'"main.dart.js?v={commit}"')
t = t.replace("'main.dart.js'", f"'main.dart.js?v={commit}'")
boot.write_text(t)
print(f"cache-bust commit={commit}")
PY
