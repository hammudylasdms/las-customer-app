#!/usr/bin/env bash
set -euo pipefail

app_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$app_root"

if [[ "$(uname -s)" != Darwin ]]; then
  echo 'This native build requires macOS with Xcode.' >&2
  exit 2
fi

export PORTAL_ORIGIN="${PORTAL_ORIGIN:-https://dms.lastoptechnik.com}"
swift scripts/prepare_branding.swift
python3 - <<'PY'
import os
from urllib.parse import urlsplit
u = urlsplit(os.environ['PORTAL_ORIGIN'])
if (u.scheme != 'https' or not u.hostname or u.username or u.password
        or u.path not in ('', '/') or u.query or u.fragment):
    raise SystemExit('PORTAL_ORIGIN must be an HTTPS origin without credentials, path or query.')
try:
    u.port
except ValueError as exc:
    raise SystemExit('Invalid portal port') from exc
PY

xcodebuild -version
flutter --version
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub
flutter build ios --simulator --debug --no-codesign --no-pub \
  --dart-define=ENABLE_PUSH=false \
  "--dart-define=PORTAL_ORIGIN=$PORTAL_ORIGIN"
