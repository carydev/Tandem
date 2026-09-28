<#
.SYNOPSIS
  TANDEM - Claude 지휘 + Codex 실무 에이전트 하네스를 현재 프로젝트에 설치한다.
.DESCRIPTION
  파일을 배치하고 슬래시 커맨드를 등록한다. 기존 파일은 덮어쓰지 않고 .new 로 남긴다.
  설치 후 Claude Code 에서 /tandem 을 실행해 프로젝트에 맞게 적응시킨다.
.PARAMETER DocsRoot
  운영 문서를 둘 폴더. 기본값 docs/tandem
.PARAMETER Force
  이미 설치돼 있어도 템플릿을 다시 배치한다. 기존 파일은 여전히 .new 로 간다.
.PARAMETER SkipDeps
  Codex CLI 설치와 로그인 확인을 건너뛴다.
.PARAMETER Yes
  설치 여부를 묻지 않고 진행한다. 무인 실행용.
.EXAMPLE
  .\install.ps1
.EXAMPLE
  .\install.ps1 -DocsRoot docs/ops
#>
[CmdletBinding()]
param(
  [string]$DocsRoot = "docs/tandem",
  [switch]$Force,
  [switch]$SkipDeps,
  [switch]$Yes
)

$ErrorActionPreference = "Stop"
$VERSION = "1.0"

function Say([string]$m, [string]$c = "Gray") { Write-Host $m -ForegroundColor $c }
function Ok ([string]$m) { Write-Host "  [OK] $m" -ForegroundColor Green }
function Warn([string]$m) { Write-Host "  [!]  $m" -ForegroundColor Yellow }
function Bad ([string]$m) { Write-Host "  [X]  $m" -ForegroundColor Red }

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$tpl  = Join-Path $here "tandem\templates"
if (-not (Test-Path $tpl)) { Bad "tandem\templates 를 찾을 수 없다. 압축을 푼 폴더에서 실행해라."; exit 1 }

$root = (Get-Location).Path
Say ""
Say "TANDEM v$VERSION" Cyan
Say "설치 위치: $root"
Say ""

# ── 환경 점검 ────────────────────────────────
Say "환경 점검" Cyan
$isGit = $false
try { git rev-parse --is-inside-work-tree 2>$null | Out-Null; $isGit = ($LASTEXITCODE -eq 0) } catch {}
if ($isGit) {
  Ok "git 저장소"
  $dirty = git status --porcelain
  if ($dirty) { Warn "커밋 안 된 변경이 있다. 설치 전에 커밋해 두면 되돌리기 쉽다." }
} else {
  Warn "git 저장소가 아니다. 되돌리기 수단이 없으니 주의해라."
}

function Ask([string]$q) {
  if ($Yes) { return $true }
  $a = Read-Host "  $q [Y/n]"
  return ($a -eq "" -or $a -match '^[Yy]')
}
function Has([string]$c) { return [bool](Get-Command $c -ErrorAction SilentlyContinue) }
# 외부 명령 실행. codex 등은 정상 출력도 stderr 로 내보내는데, 5.1 은 Stop 상태에서 이를 오류로 보고 멈춘다.
function Native([scriptblock]$b) {
  $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  try { & $b } finally { $ErrorActionPreference = $prev }
}
function Rehash { $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
                              [System.Environment]::GetEnvironmentVariable("Path","User") }

if (Has claude) { Ok "claude CLI" } else {
  Warn "claude CLI 를 PATH 에서 못 찾았다."
  Say "       설치: https://claude.com/claude-code"
}

# ── Codex CLI: 설치 ─────────────────────────
$hasCodex = Has codex
if (-not $hasCodex -and -not $SkipDeps) {
  Warn "codex CLI 가 없다. 이 하네스는 Codex 없이는 동작하지 않는다."
  $method = $null
  if (Has winget) { $method = "winget" } elseif (Has npm) { $method = "npm" }
  if ($method -and (Ask "지금 설치할까? ($method 사용)")) {
    Say "  설치 중..." 
    try {
      if ($method -eq "winget") {
        Native { winget install --id OpenAI.Codex --accept-package-agreements --accept-source-agreements }
      } else {
        Native { npm install -g "@openai/codex" }
      }
      Rehash
      $hasCodex = Has codex
      if ($hasCodex) { Ok "codex CLI 설치 완료" }
      else { Warn "설치는 됐을 수 있으나 PATH 에 아직 없다. 새 터미널에서 다시 실행해라." }
    } catch { Bad "설치 실패: $_" }
  } elseif (-not $method) {
    Bad "winget 도 npm 도 없다. 아래 중 하나로 직접 설치해라."
    Say "       npm install -g @openai/codex        (Node.js 22+ 필요)"
    Say "       winget install OpenAI.Codex"
  }
} elseif ($hasCodex) { Ok "codex CLI" }

# ── Codex CLI: 로그인 ───────────────────────
$codexAuth = $false
if ($hasCodex -and -not $SkipDeps) {
  Native { $null = codex login status 2>&1 }
  if ($LASTEXITCODE -eq 0) { Ok "codex 로그인됨"; $codexAuth = $true }
  else {
    Warn "codex 에 로그인돼 있지 않다."
    if (Ask "지금 로그인할까? (브라우저가 열린다)") {
      Native { codex login }
      Native { $null = codex login status 2>&1 }
      if ($LASTEXITCODE -eq 0) { Ok "codex 로그인 완료"; $codexAuth = $true }
      else { Warn "로그인이 확인되지 않았다. 나중에 'codex login' 을 실행해라." }
    } else { Say "       나중에: codex login" }
  }
}

# ── 프로젝트 이름 ────────────────────────────
$project = Split-Path -Leaf $root
if ($isGit) {
  try {
    $remote = git config --get remote.origin.url 2>$null
    if ($remote) { $project = [System.IO.Path]::GetFileNameWithoutExtension($remote.TrimEnd('/')) }
  } catch {}
}
Say ""
Say "프로젝트: $project" Cyan
Say "문서 폴더: $DocsRoot"
Say ""

# ── 치환값 ──────────────────────────────────
$map = @{
  "{{PROJECT}}"          = $project
  "{{DOCS}}"             = $DocsRoot
  "{{VERSION}}"          = $VERSION
  "{{INSTALLED}}"        = (Get-Date -Format "yyyy-MM-dd")
  "{{MODEL_TOP}}"        = "MODEL_TOP_미확정"
  "{{MODEL_MID}}"        = "MODEL_MID_미확정"
  "{{MODEL_LIGHT}}"      = "MODEL_LIGHT_미확정"
  "{{CLAUDE_LEAD}}"      = "총괄모델_미확정"
  "{{CLAUDE_MANAGER}}"   = "opus"
  "{{CLAUDE_DISPATCH}}"  = "haiku"
  "{{CLAUDE_CRITIC}}"    = "sonnet"
}

$script:placed = @(); $script:kept = @(); $script:skipped = @()

function Put([string]$src, [string]$dst) {
  $full = Join-Path $root $dst
  $dir  = Split-Path -Parent $full
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

  $text = Get-Content -Path $src -Raw -Encoding UTF8
  foreach ($k in $map.Keys) { $text = $text.Replace($k, $map[$k]) }

  $target = $full
  if (Test-Path $full) {
    if (-not $Force) {
      $existing = Get-Content -Path $full -Raw -Encoding UTF8
      if ($existing -eq $text) { $script:skipped += $dst; return }
    }
    $target = "$full.new"
    $script:kept += $dst
  } else {
    $script:placed += $dst
  }
  # BOM 없는 UTF8
  [System.IO.File]::WriteAllText($target, $text, (New-Object System.Text.UTF8Encoding $false))
}

Say "파일 배치" Cyan

# 역할과 커맨드
Put "$tpl\claude\agents\tandem-manager.md"   ".claude/agents/tandem-manager.md"
Put "$tpl\claude\agents\tandem-dispatch.md"  ".claude/agents/tandem-dispatch.md"
Put "$tpl\claude\agents\tandem-critic.md"    ".claude/agents/tandem-critic.md"
Put "$tpl\claude\commands\tandem.md"         ".claude/commands/tandem.md"
Put "$tpl\claude\commands\tandem-status.md"  ".claude/commands/tandem-status.md"

# Codex
Put "$tpl\codex\config.toml"                 ".codex/config.toml"
Get-ChildItem "$tpl\codex\agents\*.toml" | ForEach-Object { Put $_.FullName ".codex/agents/$($_.Name)" }

# 운영 문서
Put "$tpl\docs\lead-charter.md"       "$DocsRoot/lead-charter.md"
Put "$tpl\docs\model-routing.md"      "$DocsRoot/model-routing.md"
Put "$tpl\docs\delegation.md"         "$DocsRoot/delegation.md"
Put "$tpl\docs\operating-model.md"    "$DocsRoot/operating-model.md"
Put "$tpl\docs\harness-status.md"     "$DocsRoot/harness-status.md"
Put "$tpl\docs\log\README.md"         "$DocsRoot/log/README.md"
Put "$tpl\docs\reports\README.md"     "$DocsRoot/reports/README.md"
Put "$tpl\docs\tasks\README.md"       "$DocsRoot/tasks/README.md"
Put "$tpl\docs\briefings\README.md"   "$DocsRoot/briefings/README.md"

# 적응 지시서
Put "$here\tandem\adapt.md" "tandem/adapt.md"

Ok "$($script:placed.Count) 개 배치"
if ($script:skipped.Count) { Ok "$($script:skipped.Count) 개 변경 없음" }
if ($script:kept.Count) {
  Warn "$($script:kept.Count) 개는 이미 있어서 .new 로 저장했다. /tandem 이 병합안을 제시한다."
  $script:kept | ForEach-Object { Say "       $_" }
}

# ── 빈 폴더와 로그 ───────────────────────────
foreach ($d in @("$DocsRoot/tasks","$DocsRoot/briefings","$DocsRoot/reports/work/parts",
                 "$DocsRoot/reports/critique","$DocsRoot/reports/review","$DocsRoot/reports/setup")) {
  $p = Join-Path $root $d
  if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
  $gk = Join-Path $p ".gitkeep"
  if (-not (Test-Path $gk)) { New-Item -ItemType File -Path $gk -Force | Out-Null }
}
$logFile = Join-Path $root "$DocsRoot/log/runs.jsonl"
if (-not (Test-Path $logFile)) {
  New-Item -ItemType File -Path $logFile -Force | Out-Null
  Ok "실행 로그 생성"
} else { Ok "실행 로그 유지 (기존 기록 보존)" }

# ── CLAUDE.md / AGENTS.md 블록 ──────────────
function Block([string]$tplFile, [string]$dstFile) {
  $text = Get-Content -Path (Join-Path $tpl $tplFile) -Raw -Encoding UTF8
  foreach ($k in $map.Keys) { $text = $text.Replace($k, $map[$k]) }
  $full = Join-Path $root $dstFile
  if (Test-Path $full) {
    $cur = Get-Content -Path $full -Raw -Encoding UTF8
    if ($cur -match '(?s)<!-- TANDEM:BEGIN -->.*?<!-- TANDEM:END -->') {
      $repl = [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $text.TrimEnd() }
      $new = [regex]::Replace($cur, '(?s)<!-- TANDEM:BEGIN -->.*?<!-- TANDEM:END -->', $repl)
      [System.IO.File]::WriteAllText($full, $new, (New-Object System.Text.UTF8Encoding $false))
      Ok "$dstFile 의 TANDEM 블록 갱신"
    } else {
      [System.IO.File]::AppendAllText($full, "`r`n$text", (New-Object System.Text.UTF8Encoding $false))
      Ok "$dstFile 에 TANDEM 블록 추가"
    }
  } else {
    [System.IO.File]::WriteAllText($full, $text, (New-Object System.Text.UTF8Encoding $false))
    Ok "$dstFile 생성"
  }
}
Block "CLAUDE.tandem.md" "CLAUDE.md"
Block "AGENTS.tandem.md" "AGENTS.md"

# ── settings.json 병합 ──────────────────────
$sPath = Join-Path $root ".claude\settings.json"
$sTpl  = Get-Content -Path (Join-Path $tpl "settings.tandem.json") -Raw -Encoding UTF8
foreach ($k in $map.Keys) { $sTpl = $sTpl.Replace($k, $map[$k]) }
$sNew  = $sTpl | ConvertFrom-Json

if (Test-Path $sPath) {
  try {
    $cur = Get-Content -Path $sPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not $cur.env) { $cur | Add-Member -NotePropertyName env -NotePropertyValue ([pscustomobject]@{}) -Force }
    foreach ($p in $sNew.env.PSObject.Properties) {
      $cur.env | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value -Force
    }
    if (-not $cur.permissions) { $cur | Add-Member -NotePropertyName permissions -NotePropertyValue ([pscustomobject]@{allow=@()}) -Force }
    if (-not $cur.permissions.allow) { $cur.permissions | Add-Member -NotePropertyName allow -NotePropertyValue @() -Force }
    $allow = @($cur.permissions.allow) + @($sNew.permissions.allow) | Select-Object -Unique
    $cur.permissions.allow = $allow
    [System.IO.File]::WriteAllText($sPath, ($cur | ConvertTo-Json -Depth 20), (New-Object System.Text.UTF8Encoding $false))
    Ok ".claude/settings.json 병합"
  } catch {
    [System.IO.File]::WriteAllText("$sPath.new", $sTpl, (New-Object System.Text.UTF8Encoding $false))
    Warn ".claude/settings.json 파싱 실패. .new 로 저장했다."
  }
} else {
  $dir = Split-Path -Parent $sPath
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  [System.IO.File]::WriteAllText($sPath, $sTpl, (New-Object System.Text.UTF8Encoding $false))
  Ok ".claude/settings.json 생성"
}

# ── .gitignore ──────────────────────────────
$gi = Join-Path $root ".gitignore"
$giText = if (Test-Path $gi) { Get-Content -Path $gi -Raw -Encoding UTF8 } else { "" }
if ($giText -notmatch '(?m)^\.codex-last/') {
  [System.IO.File]::AppendAllText($gi, "`r`n# TANDEM`r`n.codex-last/`r`n", (New-Object System.Text.UTF8Encoding $false))
  Ok ".gitignore 에 .codex-last/ 추가"
}

# ── config.json ─────────────────────────────
$cfgPath = Join-Path $root "tandem\config.json"
if ((Test-Path $cfgPath) -and -not $Force) {
  Ok "tandem/config.json 유지 (기존 설정 보존)"
} else {
  $cfg = [ordered]@{
    set        = "TANDEM"
    version    = $VERSION
    project    = $project
    docs_root  = $DocsRoot
    installed  = (Get-Date -Format "yyyy-MM-dd")
    adapted    = $false
    models     = [ordered]@{ codex_top=""; codex_mid=""; codex_light="";
                             claude_lead=""; claude_manager="opus";
                             claude_dispatch="haiku"; claude_critic="sonnet" }
    task_id_format = ""
    source_of_truth = @()
  }
  [System.IO.File]::WriteAllText($cfgPath, ($cfg | ConvertTo-Json -Depth 10), (New-Object System.Text.UTF8Encoding $false))
  Ok "tandem/config.json 생성"
}

# ── 안내 ────────────────────────────────────
Say ""
Say "설치 완료" Green
Say ""
Say "다음 한 줄:" Cyan
Say ""
Say "    claude" White
Say ""
Say "  세션이 뜨면 입력:" Cyan
Say ""
Say "    /tandem" White
Say ""
Say "  적응 세션이 환경을 확인하고 이 프로젝트에 맞게 고친 뒤 검증까지 한다." 
Say "  끝나면 보고하고 멈춘다. 커밋은 네가 직접 한다."
Say ""
if (-not $hasCodex) {
  Bad "Codex CLI 가 아직 없다. /tandem 이 1단계에서 멈춘다."
  Say "       npm install -g @openai/codex   또는   winget install OpenAI.Codex"
  Say ""
} elseif (-not $codexAuth -and -not $SkipDeps) {
  Warn "codex 로그인이 아직 안 돼 있다. /tandem 전에 'codex login' 을 실행해라."
  Say ""
}
