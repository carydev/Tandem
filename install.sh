#!/usr/bin/env bash
# TANDEM - Claude 지휘 + Codex 실무 에이전트 하네스 설치 (macOS / Linux / WSL)
# 사용: ./install.sh [문서폴더]   기본값 docs/tandem
set -euo pipefail

VERSION="1.0"
SKIP_DEPS=0; ASSUME_YES=0; DOCS="docs/tandem"
for a in "$@"; do
  case "$a" in
    --skip-deps) SKIP_DEPS=1 ;;
    -y|--yes)    ASSUME_YES=1 ;;
    -h|--help)   echo "사용: ./install.sh [문서폴더] [--skip-deps] [-y]"; exit 0 ;;
    *)           DOCS="$a" ;;
  esac
done
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TPL="$HERE/tandem/templates"
ROOT="$(pwd)"
[ -d "$TPL" ] || { echo "tandem/templates 를 찾을 수 없다. 압축을 푼 폴더에서 실행해라."; exit 1; }

g(){ printf '  \033[32m[OK]\033[0m %s\n' "$1"; }
y(){ printf '  \033[33m[!]\033[0m  %s\n' "$1"; }
r(){ printf '  \033[31m[X]\033[0m  %s\n' "$1"; }
c(){ printf '\033[36m%s\033[0m\n' "$1"; }

echo; c "TANDEM v$VERSION"; echo "설치 위치: $ROOT"; echo
c "환경 점검"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  g "git 저장소"
  [ -z "$(git status --porcelain)" ] || y "커밋 안 된 변경이 있다. 설치 전에 커밋해 두면 되돌리기 쉽다."
  PROJECT="$(basename "$(git rev-parse --show-toplevel)")"
  REMOTE="$(git config --get remote.origin.url 2>/dev/null || true)"
  [ -n "$REMOTE" ] && PROJECT="$(basename "${REMOTE%.git}")"
else
  y "git 저장소가 아니다. 되돌리기 수단이 없으니 주의해라."
  PROJECT="$(basename "$ROOT")"
fi
ask(){ [ "$ASSUME_YES" -eq 1 ] && return 0
  local ans=""
  if ( exec </dev/tty ) 2>/dev/null; then
    printf '  %s [Y/n] ' "$1"; read -r ans </dev/tty || return 1
  elif [ -t 0 ]; then printf '  %s [Y/n] ' "$1"; read -r ans || return 1
  else return 1; fi
  [ -z "$ans" ] || [ "$ans" = "y" ] || [ "$ans" = "Y" ]; }

if command -v claude >/dev/null 2>&1; then g "claude CLI"
else y "claude CLI 를 PATH 에서 못 찾았다."; echo "       설치: https://claude.com/claude-code"; fi

HAS_CODEX=0; CODEX_AUTH=0
command -v codex >/dev/null 2>&1 && HAS_CODEX=1

if [ "$HAS_CODEX" -eq 0 ] && [ "$SKIP_DEPS" -eq 0 ]; then
  y "codex CLI 가 없다. 이 하네스는 Codex 없이는 동작하지 않는다."
  METHOD=""
  command -v brew >/dev/null 2>&1 && METHOD="brew"
  [ -z "$METHOD" ] && command -v npm >/dev/null 2>&1 && METHOD="npm"
  if [ -n "$METHOD" ] && ask "지금 설치할까? ($METHOD 사용)"; then
    echo "  설치 중..."
    if [ "$METHOD" = "brew" ]; then brew install --cask codex || true
    else npm install -g @openai/codex || true; fi
    hash -r 2>/dev/null || true
    if command -v codex >/dev/null 2>&1; then HAS_CODEX=1; g "codex CLI 설치 완료"
    else y "설치는 됐을 수 있으나 PATH 에 아직 없다. 새 셸에서 다시 실행해라."; fi
  elif [ -z "$METHOD" ]; then
    r "brew 도 npm 도 없다. 아래 중 하나로 직접 설치해라."
    echo "       npm install -g @openai/codex     (Node.js 22+ 필요)"
    echo "       brew install --cask codex"
  fi
elif [ "$HAS_CODEX" -eq 1 ]; then g "codex CLI"; fi

if [ "$HAS_CODEX" -eq 1 ] && [ "$SKIP_DEPS" -eq 0 ]; then
  if codex login status >/dev/null 2>&1; then g "codex 로그인됨"; CODEX_AUTH=1
  else
    y "codex 에 로그인돼 있지 않다."
    if ask "지금 로그인할까? (브라우저가 열린다)"; then
      codex login || true
      if codex login status >/dev/null 2>&1; then g "codex 로그인 완료"; CODEX_AUTH=1
      else y "로그인이 확인되지 않았다. 나중에 'codex login' 을 실행해라."; fi
    else echo "       나중에: codex login"; fi
  fi
fi

echo; c "프로젝트: $PROJECT"; echo "문서 폴더: $DOCS"; echo; c "파일 배치"
TODAY="$(date +%Y-%m-%d)"
KEPT=0; PLACED=0

sub(){ sed -e "s|{{PROJECT}}|$PROJECT|g" -e "s|{{DOCS}}|$DOCS|g" -e "s|{{VERSION}}|$VERSION|g" \
           -e "s|{{INSTALLED}}|$TODAY|g" \
           -e "s|{{MODEL_TOP}}|MODEL_TOP_미확정|g" -e "s|{{MODEL_MID}}|MODEL_MID_미확정|g" \
           -e "s|{{MODEL_LIGHT}}|MODEL_LIGHT_미확정|g" -e "s|{{CLAUDE_LEAD}}|총괄모델_미확정|g" \
           -e "s|{{CLAUDE_MANAGER}}|opus|g" -e "s|{{CLAUDE_DISPATCH}}|haiku|g" \
           -e "s|{{CLAUDE_CRITIC}}|sonnet|g" "$1"; }

put(){ local src="$1" dst="$ROOT/$2"; mkdir -p "$(dirname "$dst")"
  local tmp; tmp="$(mktemp)"; sub "$src" > "$tmp"
  if [ -f "$dst" ]; then
    if cmp -s "$tmp" "$dst"; then rm -f "$tmp"; return; fi
    mv "$tmp" "$dst.new"; KEPT=$((KEPT+1)); echo "       $2 -> .new"
  else mv "$tmp" "$dst"; PLACED=$((PLACED+1)); fi; }

for f in tandem-manager tandem-dispatch tandem-critic; do put "$TPL/claude/agents/$f.md" ".claude/agents/$f.md"; done
for f in tandem tandem-status; do put "$TPL/claude/commands/$f.md" ".claude/commands/$f.md"; done
put "$TPL/codex/config.toml" ".codex/config.toml"
for f in "$TPL"/codex/agents/*.toml; do put "$f" ".codex/agents/$(basename "$f")"; done
for f in lead-charter model-routing delegation operating-model harness-status; do put "$TPL/docs/$f.md" "$DOCS/$f.md"; done
for d in log reports tasks briefings; do put "$TPL/docs/$d/README.md" "$DOCS/$d/README.md"; done
put "$HERE/tandem/adapt.md" "tandem/adapt.md"
g "$PLACED 개 배치"
[ "$KEPT" -gt 0 ] && y "$KEPT 개는 이미 있어서 .new 로 저장했다. /tandem 이 병합안을 제시한다."

for d in tasks briefings reports/work/parts reports/critique reports/review reports/setup; do
  mkdir -p "$ROOT/$DOCS/$d"; : > "$ROOT/$DOCS/$d/.gitkeep"; done
if [ -f "$ROOT/$DOCS/log/runs.jsonl" ]; then g "실행 로그 유지 (기존 기록 보존)"
else mkdir -p "$ROOT/$DOCS/log"; : > "$ROOT/$DOCS/log/runs.jsonl"; g "실행 로그 생성"; fi

block(){ local src="$TPL/$1" dst="$ROOT/$2" tmp; tmp="$(mktemp)"; sub "$src" > "$tmp"
  if [ -f "$dst" ] && grep -q 'TANDEM:BEGIN' "$dst"; then
    awk -v f="$tmp" 'BEGIN{while((getline l < f)>0) b=b l "\n"} /TANDEM:BEGIN/{print b; s=1; next} /TANDEM:END/{s=0; next} !s' "$dst" > "$dst.tmp" && mv "$dst.tmp" "$dst"
    g "$2 의 TANDEM 블록 갱신"
  elif [ -f "$dst" ]; then printf '\n' >> "$dst"; cat "$tmp" >> "$dst"; g "$2 에 TANDEM 블록 추가"
  else cp "$tmp" "$dst"; g "$2 생성"; fi; rm -f "$tmp"; }
block "CLAUDE.tandem.md" "CLAUDE.md"
block "AGENTS.tandem.md" "AGENTS.md"

S="$ROOT/.claude/settings.json"; mkdir -p "$ROOT/.claude"
if [ -f "$S" ] && command -v python3 >/dev/null 2>&1; then
  TMPL="$(mktemp)"; sub "$TPL/settings.tandem.json" > "$TMPL"
  python3 - "$S" "$TMPL" <<'PY' && g ".claude/settings.json 병합" || y ".claude/settings.json 병합 실패"
import json,sys
cur=json.load(open(sys.argv[1],encoding='utf-8')); new=json.load(open(sys.argv[2],encoding='utf-8'))
cur.setdefault('env',{}).update(new['env'])
a=cur.setdefault('permissions',{}).setdefault('allow',[])
for x in new['permissions']['allow']:
    if x not in a: a.append(x)
json.dump(cur,open(sys.argv[1],'w',encoding='utf-8'),ensure_ascii=False,indent=2)
PY
  rm -f "$TMPL"
elif [ -f "$S" ]; then sub "$TPL/settings.tandem.json" > "$S.new"; y ".claude/settings.json.new 로 저장했다. 직접 병합해라."
else sub "$TPL/settings.tandem.json" > "$S"; g ".claude/settings.json 생성"; fi

grep -q '^\.codex-last/' "$ROOT/.gitignore" 2>/dev/null || { printf '\n# TANDEM\n.codex-last/\n' >> "$ROOT/.gitignore"; g ".gitignore 에 .codex-last/ 추가"; }

mkdir -p "$ROOT/tandem"
if [ -f "$ROOT/tandem/config.json" ]; then g "tandem/config.json 유지 (기존 설정 보존)"
else cat > "$ROOT/tandem/config.json" <<JSON
{
  "set": "TANDEM",
  "version": "$VERSION",
  "project": "$PROJECT",
  "docs_root": "$DOCS",
  "installed": "$TODAY",
  "adapted": false,
  "models": { "codex_top": "", "codex_mid": "", "codex_light": "",
              "claude_lead": "", "claude_manager": "opus",
              "claude_dispatch": "haiku", "claude_critic": "sonnet" },
  "task_id_format": "",
  "source_of_truth": []
}
JSON
g "tandem/config.json 생성"; fi

echo; printf '\033[32m설치 완료\033[0m\n'; echo
c "다음 한 줄:"; echo; echo "    claude"; echo
c "  세션이 뜨면 입력:"; echo; echo "    /tandem"; echo
echo "  적응 세션이 환경을 확인하고 이 프로젝트에 맞게 고친 뒤 검증까지 한다."
echo "  끝나면 보고하고 멈춘다. 커밋은 네가 직접 한다."; echo
if [ "$HAS_CODEX" -eq 0 ]; then
  r "Codex CLI 가 아직 없다. /tandem 이 1단계에서 멈춘다."
  echo "       npm install -g @openai/codex   또는   brew install --cask codex"; echo
elif [ "$CODEX_AUTH" -eq 0 ] && [ "$SKIP_DEPS" -eq 0 ]; then
  y "codex 로그인이 아직 안 돼 있다. /tandem 전에 'codex login' 을 실행해라."; echo
fi
exit 0
