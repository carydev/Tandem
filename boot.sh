#!/usr/bin/env bash
# TANDEM 원격 설치 부트스트랩 (macOS / Linux / WSL)
#
#   curl -fsSL https://raw.githubusercontent.com/carydev/Tandem/main/boot.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/carydev/Tandem/main/boot.sh | bash -s -- docs/ops
#
# 저장소를 임시 폴더로 내려받아 install.sh 를 현재 폴더에 대해 실행하고 정리한다.
set -euo pipefail

REPO="${TANDEM_REPO:-carydev/Tandem}"     # 포크했으면 TANDEM_REPO 로 덮어쓴다
REF="${TANDEM_REF:-main}"
TARGET="$(pwd)"

command -v curl >/dev/null 2>&1 || { echo "curl 이 필요하다."; exit 1; }
command -v tar  >/dev/null 2>&1 || { echo "tar 가 필요하다."; exit 1; }

printf '\n\033[36mTANDEM 내려받는 중: %s@%s\033[0m\n' "$REPO" "$REF"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
curl -fsSL "https://codeload.github.com/$REPO/tar.gz/$REF" | tar xz -C "$TMP"

SRC="$(find "$TMP" -maxdepth 2 -name install.sh -print -quit)"
[ -n "$SRC" ] || { echo "내려받은 파일에서 install.sh 를 찾을 수 없다."; exit 1; }
SRC="$(dirname "$SRC")"

chmod +x "$SRC/install.sh"
cd "$TARGET"
# curl | bash 로 실행하면 stdin 이 파이프다. install.sh 의 질문은 /dev/tty 로 읽는다.
exec "$SRC/install.sh" "$@"
