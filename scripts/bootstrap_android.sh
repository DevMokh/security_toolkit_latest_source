#!/usr/bin/env bash
set -euo pipefail

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter is required. Install the Flutter stable SDK first." >&2
  exit 1
fi

if [ ! -f android/app/src/main/AndroidManifest.xml ]; then
  echo "Custom AndroidManifest.xml is missing." >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

cp -a lib "$TMP_DIR/lib"
cp pubspec.yaml "$TMP_DIR/pubspec.yaml"
cp android/app/src/main/AndroidManifest.xml "$TMP_DIR/AndroidManifest.xml"

rm -rf android
flutter create --platforms=android --org com.security --project-name security_toolkit --overwrite .

rm -rf lib
cp -a "$TMP_DIR/lib" lib
cp "$TMP_DIR/pubspec.yaml" pubspec.yaml
cp "$TMP_DIR/AndroidManifest.xml" android/app/src/main/AndroidManifest.xml

python3 - <<'PY'
from pathlib import Path
import re

for candidate in (Path("android/app/build.gradle.kts"), Path("android/app/build.gradle")):
    if not candidate.exists():
        continue
    source = candidate.read_text(encoding="utf-8")
    if candidate.suffix == ".kts":
        source = re.sub(
            r'applicationId\s*=\s*["\'][^"\']+["\']',
            'applicationId = "com.security.toolkit"',
            source,
            count=1,
        )
        source = re.sub(
            r'namespace\s*=\s*["\'][^"\']+["\']',
            'namespace = "com.security.toolkit"',
            source,
            count=1,
        )
        source = re.sub(
            r'minSdk\s*=\s*(?:flutter\.minSdkVersion|\d+)',
            'minSdk = 24',
            source,
            count=1,
        )
    else:
        source = re.sub(
            r'applicationId\s+["\'][^"\']+["\']',
            'applicationId "com.security.toolkit"',
            source,
            count=1,
        )
        source = re.sub(
            r'namespace\s+["\'][^"\']+["\']',
            'namespace "com.security.toolkit"',
            source,
            count=1,
        )
        source = re.sub(
            r'minSdkVersion\s+(?:flutter\.minSdkVersion|\d+)',
            'minSdkVersion 24',
            source,
            count=1,
        )
    candidate.write_text(source, encoding="utf-8")

main_activity = next(Path("android/app/src/main").rglob("MainActivity.kt"), None)
if main_activity is not None:
    kotlin_source = main_activity.read_text(encoding="utf-8")
    kotlin_source = re.sub(
        r'^package\s+[^\n]+',
        'package com.security.toolkit',
        kotlin_source,
        count=1,
        flags=re.MULTILINE,
    )
    target = Path("android/app/src/main/kotlin/com/security/toolkit/MainActivity.kt")
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(kotlin_source, encoding="utf-8")
    if main_activity != target:
        main_activity.unlink()
PY

echo "Android platform generated. Application ID and namespace: com.security.toolkit"
