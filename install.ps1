<#
.SYNOPSIS
  TANDEM v1.1 installer. Run from the project directory.
.PARAMETER JevKey
  May remain in command history; interactive input is recommended.
  명령 기록에 남을 수 있으니 대화형 입력을 권장합니다.
#>
[CmdletBinding()]
param(
  [string]$DocsRoot,
  [ValidateSet('claude-main','codex-main','claude-solo','codex-solo')][string]$Mode,
  [ValidateSet('ko','en')][string]$Lang,
  [string]$JevKey,
  [switch]$NoJev,
  [switch]$UseJev,
  [switch]$SkipDeps,
  [switch]$Yes,
  [switch]$Force,
  [string]$TemplateRoot
)
$ErrorActionPreference = 'Stop'
$uiLang = if ($Lang) { $Lang } elseif ((Get-UICulture).Name -like 'ko*') { 'ko' } else { 'en' }
$sourceRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = (Get-Location).Path
$version = [IO.File]::ReadAllText((Join-Path $sourceRoot 'VERSION')).Trim()
$utf8 = New-Object Text.UTF8Encoding($false)
$strictUtf8 = New-Object Text.UTF8Encoding($false,$true)
$today = Get-Date -Format 'yyyy-MM-dd'
$messages = @{
  ko = @{ done='설치 완료'; unchanged='변경 없음'; added='배치'; replaced='교체'; preserved='사용자 수정 보존, .new 생성'; removed='제거'; warning='경고'; missing='소스 파일 없음'; parse='JSON 파싱 실패, .new 생성'; jevChoice='Jev(OpenRouter) 사용 방법'; jevKeyChoice='키 입력해서 사용'; jevLaterChoice='나중에 (알림 유지)'; jevOffChoice='사용 안 함 (질문·알림 끔)'; jevOn='Jev: 켜짐. 끄려면 -NoJev'; jevOff='Jev: 꺼짐. 다시 켜려면 -UseJev'; jevPrompt='Jev(OpenRouter) API 키 (Enter로 건너뜀)'; jevWarning='-JevKey 값은 명령 기록에 남을 수 있으니 대화형 입력을 권장합니다.'; newConflict='.new 가 이미 있고 내용이 다름 — 병합 후 지워라'; encoding='UTF-8 디코딩 실패, 원본 보존'; invalidPath='manifest 삭제 경로 거부'; installCodex='Codex CLI를 지금 설치할까? [y/N]'; nextClaude='다음: claude 실행 후 /tandem 입력'; nextCodex='다음: codex 실행 후 tandem/adapt.md를 읽고 적응 진행. /hooks에서 훅 승인'; exclusive='-NoJev와 -UseJev 중 하나만 지정하세요.'; badConfig='tandem/config.json 오류'; badDocs='DocsRoot는 프로젝트 안의 상대 경로여야 합니다.'; selectMode='모드 선택'; missingLang='템플릿 언어 폴더 없음'; emptyContract='tandem/files.json에 파일 목록이 없습니다.'; unresolved='해결되지 않은 템플릿 토큰'; badDestination='잘못된 설치 대상 경로'; badManifest='tandem/manifest.json 오류'; missingMarker='블록 경계 표시 없음'; badJsonTemplate='JSON 템플릿 오류' }
  en = @{ done='Installation complete'; unchanged='No changes'; added='Installed'; replaced='Replaced'; preserved='User edit preserved; wrote .new'; removed='Removed'; warning='Warning'; missing='Missing source file'; parse='Invalid JSON; wrote .new'; jevChoice='How to use Jev (OpenRouter)'; jevKeyChoice='Enter a key and use it'; jevLaterChoice='Later (keep notices)'; jevOffChoice='Do not use (turn off prompts and notices)'; jevOn='Jev: on. Turn off with -NoJev'; jevOff='Jev: off. Turn on with -UseJev'; jevPrompt='Jev (OpenRouter) API key (Enter to skip)'; jevWarning='-JevKey may remain in command history; interactive input is recommended.'; newConflict='.new already exists with different content — merge and delete it'; encoding='UTF-8 decoding failed; original preserved'; invalidPath='Refused manifest deletion path'; installCodex='Install Codex CLI now? [y/N]'; nextClaude='Next: run claude, then /tandem'; nextCodex='Next: run codex and follow tandem/adapt.md. Approve hooks with /hooks'; exclusive='Use either -NoJev or -UseJev.'; badConfig='Invalid tandem/config.json'; badDocs='DocsRoot must be a relative path inside the project.'; selectMode='Select mode'; missingLang='Template language folder missing'; emptyContract='tandem/files.json has no files.'; unresolved='Unresolved template token'; badDestination='Invalid contract destination'; badManifest='Invalid tandem/manifest.json'; missingMarker='Missing block markers'; badJsonTemplate='Invalid JSON template' }
}
$m = $messages[$uiLang]
if ($NoJev -and $UseJev) { throw $m.exclusive }
function Native([scriptblock]$body) {
  $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
  try { & $body } finally { $ErrorActionPreference = $old }
}
function Has([string]$name) { return [bool](Get-Command $name -ErrorAction SilentlyContinue) }
function Prop($obj, [string]$name, $value) {
  if ($null -eq $obj.PSObject.Properties[$name]) { $obj | Add-Member -NotePropertyName $name -NotePropertyValue $value }
  return $obj.PSObject.Properties[$name].Value
}
function Warn([string]$message) { Write-Host "  [$($script:m.warning)] $message" -ForegroundColor Yellow }
function Note([string]$message) { Write-Host "  $message" }
function ReadUtf8([string]$path) { return [IO.File]::ReadAllText($path, $script:strictUtf8) }
function WriteUtf8([string]$path, [string]$content) {
  $dir = Split-Path -Parent $path
  if (-not (Test-Path -LiteralPath $dir)) { [void][IO.Directory]::CreateDirectory($dir) }
  $encoding = $script:utf8
  if (Test-Path -LiteralPath $path) {
    $bytes = [IO.File]::ReadAllBytes($path)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191) { $encoding = New-Object Text.UTF8Encoding($true) }
  }
  [IO.File]::WriteAllText($path, $content, $encoding)
}
function SaveText([string]$path, [string]$content) {
  if ((Test-Path -LiteralPath $path) -and (ReadUtf8 $path) -ceq $content) { return $false }
  WriteUtf8 $path $content
  return $true
}
function SaveCandidate([string]$path, [byte[]]$bytes) {
  if (Test-Path -LiteralPath $path) {
    if ((HashFile $path) -ne (HashBytes $bytes)) { Warn "$($script:m.newConflict): $path" }
    return $false
  }
  $dir = Split-Path -Parent $path
  if (-not (Test-Path -LiteralPath $dir)) { [void][IO.Directory]::CreateDirectory($dir) }
  [IO.File]::WriteAllBytes($path, $bytes)
  return $true
}
function Json($value) { return ($value | ConvertTo-Json -Depth 30) + "`n" }
function HashBytes([byte[]]$bytes) {
  $sha = [Security.Cryptography.SHA256]::Create()
  try { return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','').ToLowerInvariant() }
  finally { $sha.Dispose() }
}
function HashFile([string]$path) { return HashBytes ([IO.File]::ReadAllBytes($path)) }
function AskChoice([string]$prompt, [string[]]$choices, [string]$default) {
  if ($Yes) { return $default }
  Write-Host $prompt
  for ($i=0; $i -lt $choices.Count; $i++) { Write-Host "  $($i+1). $($choices[$i])" }
  $answer = Read-Host "[$default]"
  if ([string]::IsNullOrWhiteSpace($answer)) { return $default }
  $number = 0
  if ([int]::TryParse($answer, [ref]$number) -and $number -ge 1 -and $number -le $choices.Count) { return $choices[$number-1] }
  if ($choices -contains $answer) { return $answer }
  return $default
}

$configPath = Join-Path $root 'tandem/config.json'
$existing = $null
if (Test-Path -LiteralPath $configPath) {
  try { $existing = (ReadUtf8 $configPath) | ConvertFrom-Json }
  catch { throw $m.badConfig }
}
$preLang = if ($Lang) { $Lang } elseif ($existing -and $existing.lang -in @('ko','en')) { [string]$existing.lang } else { $uiLang }
$m = $messages[$preLang]
$previousDocsRoot = if ($existing -and $existing.docs_root) { [string]$existing.docs_root } else { '' }
if (-not $PSBoundParameters.ContainsKey('DocsRoot')) {
  if ($existing -and $existing.docs_root) { $DocsRoot = [string]$existing.docs_root } else { $DocsRoot = 'docs/tandem' }
}
$DocsRoot = $DocsRoot.TrimEnd([char[]]@('/',[char]92)).Replace([char]92, [char]47)
if ([IO.Path]::IsPathRooted($DocsRoot) -or $DocsRoot -match '(^|/)\.\.(/|$)' -or -not $DocsRoot) { throw $m.badDocs }
$modes = @('claude-main','codex-main','claude-solo','codex-solo')
if (-not $PSBoundParameters.ContainsKey('Mode')) {
  if ($existing -and $modes -contains $existing.mode) { $Mode = [string]$existing.mode }
  else { $Mode = AskChoice $m.selectMode $modes 'claude-main' }
}
if (-not $PSBoundParameters.ContainsKey('Lang')) {
  if ($existing -and @('ko','en') -contains $existing.lang) { $Lang = [string]$existing.lang }
  else {
    $defaultLang = $uiLang
    $Lang = AskChoice '언어 / Language: 1) 한국어  2) English' @('ko','en') $(if ($defaultLang -eq 'ko') {'1'} else {'2'})
    if ($Lang -eq '1') { $Lang = 'ko' }; if ($Lang -eq '2') { $Lang = 'en' }
  }
}
$m = $messages[$Lang]
if (-not $TemplateRoot) { $TemplateRoot = Join-Path $sourceRoot 'tandem/templates' }
$langRoot = Join-Path $TemplateRoot $Lang
if (-not (Test-Path -LiteralPath $langRoot)) { throw "$($m.missingLang): $langRoot" }
$contract = (ReadUtf8 (Join-Path $sourceRoot 'tandem/files.json')) | ConvertFrom-Json
if (-not $contract.files) { throw $m.emptyContract }

# Preserve existing values while filling the v1.1 schema and migrating v1.0 model names.
$project = Split-Path -Leaf $root
if (Has git) {
  try {
    $remote = Native { git config --get remote.origin.url 2>$null }
    if ($remote) { $project = [IO.Path]::GetFileNameWithoutExtension(([string]$remote).TrimEnd('/')) }
  } catch {}
}
if ($existing) { $cfg = $existing } else { $cfg = [pscustomobject]@{} }
[void](Prop $cfg 'set' 'TANDEM'); [void](Prop $cfg 'project' $project)
[void](Prop $cfg 'installed' $today); [void](Prop $cfg 'adapted' $false)
[void](Prop $cfg 'task_id_format' ''); [void](Prop $cfg 'source_of_truth' @())
if (-not $cfg.models) { $cfg | Add-Member -NotePropertyName models -NotePropertyValue ([pscustomobject]@{}) -Force }
$models = $cfg.models
foreach ($name in @('codex_top','codex_mid','codex_light','claude_lead')) { [void](Prop $models $name '') }
$legacy = @{ claude_top='claude_manager'; claude_mid='claude_critic'; claude_light='claude_dispatch' }
$defaults = @{ claude_top='opus'; claude_mid='sonnet'; claude_light='haiku' }
foreach ($name in @('claude_top','claude_mid','claude_light')) {
  $oldName = $legacy[$name]
  $value = if ($models.PSObject.Properties[$oldName] -and $models.$oldName) { $models.$oldName } else { $defaults[$name] }
  [void](Prop $models $name $value)
}
foreach ($name in @('claude_manager','claude_dispatch','claude_critic')) {
  if ($models.PSObject.Properties[$name]) { $models.PSObject.Properties.Remove($name) }
}
if (-not $cfg.jev) { $cfg | Add-Member -NotePropertyName jev -NotePropertyValue ([pscustomobject]@{}) -Force }
[void](Prop $cfg.jev 'model' 'typesafe/jev-1.13')
[void](Prop $cfg.jev 'key_env' 'TANDEM_JEV_API_KEY')
[void](Prop $cfg.jev 'min_confidence' 0.6)
[void](Prop $cfg.jev 'notify_missing_key' $true)
[void](Prop $cfg.jev 'enabled' $true)
if ($NoJev) { $cfg.jev.enabled = $false }
if ($UseJev) { $cfg.jev.enabled = $true }
if (-not $cfg.update) { $cfg | Add-Member -NotePropertyName update -NotePropertyValue ([pscustomobject]@{}) -Force }
[void](Prop $cfg.update 'repo' 'carydev/Tandem')
[void](Prop $cfg.update 'ref' 'main')
[void](Prop $cfg.update 'notify' $true)
[void](Prop $cfg 'version' $version); $cfg.version = $version
[void](Prop $cfg 'docs_root' $DocsRoot); $cfg.docs_root = $DocsRoot
[void](Prop $cfg 'mode' $Mode); $cfg.mode = $Mode
[void](Prop $cfg 'lang' $Lang); $cfg.lang = $Lang
[void](Prop $cfg 'updated' $today); $cfg.updated = $today
$changes = 0
if (SaveText $configPath (Json $cfg)) { $changes++; Note "config.json: $($m.replaced)" }

if ($cfg.jev.enabled -and $JevKey) {
  Warn $m.jevWarning
  [Environment]::SetEnvironmentVariable('TANDEM_JEV_API_KEY', $JevKey, 'User')
  [Environment]::SetEnvironmentVariable('TANDEM_JEV_API_KEY', $JevKey, 'Process')
} elseif ($cfg.jev.enabled -and -not $Yes -and -not [Environment]::GetEnvironmentVariable('TANDEM_JEV_API_KEY','User') -and -not $env:TANDEM_JEV_API_KEY) {
  $choice = AskChoice $m.jevChoice @($m.jevKeyChoice,$m.jevLaterChoice,$m.jevOffChoice) '2'
  if ($choice -eq $m.jevOffChoice) {
    $cfg.jev.enabled = $false
    if (SaveText $configPath (Json $cfg)) { $changes++; Note "config.json: $($m.replaced)" }
  } elseif ($choice -eq $m.jevKeyChoice) {
    $secure = Read-Host $m.jevPrompt -AsSecureString
    if ($secure.Length -gt 0) {
      $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
      try { $key = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
      finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
      [Environment]::SetEnvironmentVariable('TANDEM_JEV_API_KEY', $key, 'User')
      [Environment]::SetEnvironmentVariable('TANDEM_JEV_API_KEY', $key, 'Process')
    }
  }
}

if (-not $SkipDeps) {
  if ($Mode -ne 'codex-solo' -and -not (Has claude)) { Warn 'claude CLI' }
  if ($Mode -ne 'claude-solo') {
    if (-not (Has codex)) {
      Warn 'codex CLI'
      if (-not $Yes) {
        $answer = Read-Host $m.installCodex
        if ($answer -match '^[Yy]') {
          if (Has winget) { Native { winget install --id OpenAI.Codex --accept-package-agreements --accept-source-agreements } }
          elseif (Has npm) { Native { npm install -g '@openai/codex' } }
        }
      }
    }
    if (Has codex) {
      try { Native { $null = codex login status 2>&1 }; if ($LASTEXITCODE -ne 0) { Warn 'codex login' } }
      catch { Warn 'codex login' }
    }
  }
}

$langName = if ($Lang -eq 'ko') { '한국어' } else { 'English' }
$map = @{
  '{{PROJECT}}'=$cfg.project; '{{DOCS}}'=$DocsRoot; '{{VERSION}}'=$version; '{{INSTALLED}}'=$cfg.installed
  '{{MODE}}'=$Mode; '{{LANG}}'=$Lang; '{{LANG_NAME}}'=$langName
  '{{CLAUDE_TOP}}'=$models.claude_top; '{{CLAUDE_MID}}'=$models.claude_mid; '{{CLAUDE_LIGHT}}'=$models.claude_light
  '{{CLAUDE_MANAGER}}'=$models.claude_top; '{{CLAUDE_DISPATCH}}'=$models.claude_light; '{{CLAUDE_CRITIC}}'=$models.claude_mid
}
foreach ($tier in @('TOP','MID','LIGHT')) {
  $name = "codex_$($tier.ToLowerInvariant())"
  $map["{{MODEL_$tier}}"] = if ($models.$name) { $models.$name } elseif ($Lang -eq 'ko') { "MODEL_$($tier)_미확정" } else { "MODEL_$($tier)_UNSET" }
}
$map['{{CLAUDE_LEAD}}'] = if ($models.claude_lead) { $models.claude_lead } elseif ($Lang -eq 'ko') { '총괄모델_미확정' } else { 'LEAD_MODEL_UNSET' }
function Render([string]$source) {
  $text = ReadUtf8 $source
  $lines = [regex]::Split($text, '(?<=\n)')
  $keep = $true; $out = New-Object Text.StringBuilder
  foreach ($line in $lines) {
    if ($line -match '^\s*@@if\s+(.+?)\s*$') { $keep = @(($matches[1] -split '\s+') | Where-Object { $_ -eq $Mode }).Count -gt 0; continue }
    if ($line -match '^\s*@@endif\s*$') { $keep = $true; continue }
    if ($keep) { [void]$out.Append($line) }
  }
  $text = $out.ToString()
  foreach ($key in $map.Keys) { $text = $text.Replace($key, [string]$map[$key]) }
  if ($text -match '\{\{[A-Z_]+\}\}|@@(?:if|endif)') { throw "$($m.unresolved): $source" }
  return $text
}
function Dest([string]$relative) {
  $relative = $relative.Replace('{{DOCS}}', $DocsRoot).Replace('\','/')
  if ([IO.Path]::IsPathRooted($relative) -or $relative -match '(^|/)\.\.(/|$)') { throw "$($m.badDestination): $relative" }
  return $relative
}
$manifestPath = Join-Path $root 'tandem/manifest.json'
$manifest = [pscustomobject]@{ version=$version; files=[pscustomobject]@{} }
if (Test-Path -LiteralPath $manifestPath) {
  try {
    $manifest = (ReadUtf8 $manifestPath) | ConvertFrom-Json
    if (-not $manifest.files) { $manifest | Add-Member -NotePropertyName files -NotePropertyValue ([pscustomobject]@{}) -Force }
  } catch { throw $m.badManifest }
}
$wanted = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
$activeBlocks = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
$knownFiles = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
foreach ($entry in $contract.files | Where-Object { $_.kind -in @('file','copy') }) {
  [void]$knownFiles.Add((Dest ([string]$entry.dst)))
  if ($previousDocsRoot -and $entry.dst.Contains('{{DOCS}}')) {
    $previous = ([string]$entry.dst).Replace('{{DOCS}}', $previousDocsRoot.Replace('\','/'))
    [void]$knownFiles.Add($previous)
  }
}
foreach ($entry in $contract.files) {
  $dst = Dest ([string]$entry.dst)
  $full = Join-Path $root $dst
  $active = @($entry.modes) -contains $Mode
  if (-not $active) { continue }
  if ($entry.kind -eq 'block') { [void]$activeBlocks.Add($dst) }
  if ($entry.kind -notin @('file','copy')) { continue }
  $source = if ($entry.kind -eq 'copy') { Join-Path $sourceRoot $entry.src } else { Join-Path $langRoot $entry.src }
  [void]$wanted.Add($dst)
  if (-not (Test-Path -LiteralPath $source)) { Warn "$($m.missing): $source"; continue }
  $bytes = if ($entry.kind -eq 'copy') { [IO.File]::ReadAllBytes($source) } else { $utf8.GetBytes((Render $source)) }
  $newHash = HashBytes $bytes
  $oldProp = $manifest.files.PSObject.Properties[$dst]
  $oldHash = if ($oldProp) { [string]$oldProp.Value } else { '' }
  if (-not (Test-Path -LiteralPath $full)) {
    $dir = Split-Path -Parent $full; if (-not (Test-Path -LiteralPath $dir)) { [void][IO.Directory]::CreateDirectory($dir) }
    [IO.File]::WriteAllBytes($full, $bytes)
    $manifest.files | Add-Member -NotePropertyName $dst -NotePropertyValue $newHash -Force
    $changes++; Note "$($m.added): $dst"
  } else {
    $currentHash = HashFile $full
    if ($currentHash -eq $newHash) {
      $manifest.files | Add-Member -NotePropertyName $dst -NotePropertyValue $newHash -Force
    } elseif ($oldHash -and $currentHash -eq $oldHash) {
      [IO.File]::WriteAllBytes($full, $bytes)
      $manifest.files | Add-Member -NotePropertyName $dst -NotePropertyValue $newHash -Force
      $changes++; Note "$($m.replaced): $dst"
    } else {
      if (SaveCandidate "$full.new" $bytes) { $changes++; Warn "$($m.preserved): $dst" }
    }
  }
}
foreach ($prop in @($manifest.files.PSObject.Properties)) {
  if ($wanted.Contains($prop.Name)) { continue }
  $relative = $prop.Name.Replace('\','/')
  $full = $null
  try {
    if (-not $knownFiles.Contains($relative) -or [IO.Path]::IsPathRooted($relative) -or $relative -match '(^|/)\.{1,2}(/|$)' -or $relative.Contains(':')) { throw 'Unexpected manifest path' }
    $full = [IO.Path]::GetFullPath((Join-Path $root $relative))
    $rootPrefix = [IO.Path]::GetFullPath($root).TrimEnd([char[]]@('/',[char]92)) + [IO.Path]::DirectorySeparatorChar
    if (-not $full.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'Outside project root' }
    $partPath = $root
    foreach ($part in ($relative -split '/')) {
      $partPath = Join-Path $partPath $part
      if ((Test-Path -LiteralPath $partPath) -and ((Get-Item -LiteralPath $partPath -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Reparse point in manifest path' }
    }
  } catch { Warn "$($m.invalidPath): $($prop.Name)"; continue }
  if (-not (Test-Path -LiteralPath $full) -or (HashFile $full) -eq $prop.Value) {
    if (Test-Path -LiteralPath $full) { Remove-Item -LiteralPath $full -Force; $changes++; Note "$($m.removed): $($prop.Name)" }
    $manifest.files.PSObject.Properties.Remove($prop.Name)
  } else { Warn "$($m.preserved): $($prop.Name)" }
}
$manifest.version = $version
if (SaveText $manifestPath (Json $manifest)) { $changes++ }

$blockPattern = '(?s)<!-- TANDEM:BEGIN -->.*?<!-- TANDEM:END -->'
foreach ($entry in $contract.files | Where-Object { $_.kind -eq 'block' }) {
  $dst = Dest ([string]$entry.dst); $full = Join-Path $root $dst
  if ($activeBlocks.Contains($dst)) {
    $source = Join-Path $langRoot $entry.src
    if (-not (Test-Path -LiteralPath $source)) { Warn "$($m.missing): $source"; continue }
    $block = (Render $source).TrimEnd()
    if ($block -notmatch '<!-- TANDEM:BEGIN -->' -or $block -notmatch '<!-- TANDEM:END -->') { throw "$($m.missingMarker): $source" }
    if (Test-Path -LiteralPath $full) {
      try { $current = ReadUtf8 $full }
      catch {
        if (SaveCandidate "$full.new" ($utf8.GetBytes($block + "`n"))) { $changes++ }
        Warn "$($m.encoding): $dst"
        continue
      }
      if ([regex]::IsMatch($current, $blockPattern)) {
        $evaluator = [Text.RegularExpressions.MatchEvaluator]{ param($match) $block }
        $result = [regex]::Replace($current, $blockPattern, $evaluator, 1)
      } else { $result = $current + "`n`n" + $block + "`n" }
    } else { $result = $block + "`n" }
    if (SaveText $full $result) { $changes++; Note "$($m.replaced): $dst" }
  } elseif (Test-Path -LiteralPath $full) {
    try { $current = ReadUtf8 $full }
    catch { Warn "$($m.encoding): $dst"; continue }
    if ([regex]::IsMatch($current, $blockPattern)) {
      $result = [regex]::Replace($current, $blockPattern, '', 1)
      if (SaveText $full $result) { $changes++; Note "$($m.removed): $dst block" }
    }
  }
}

function HasCheckHook($items) {
  foreach ($item in @($items)) {
    foreach ($hook in @($item.hooks)) { if ($hook.command -like '*tandem/tools/check.ps1*') { return $true } }
  }
  return $false
}
function RemoveCheckHooks($document) {
  if (-not $document.PSObject.Properties['hooks'] -or -not $document.hooks -or -not $document.hooks.PSObject.Properties['SessionStart']) { return $false }
  $remaining = @()
  $changed = $false
  foreach ($item in @($document.hooks.SessionStart)) {
    $oldHooks = @($item.hooks)
    $keepHooks = @($oldHooks | Where-Object { $_.command -notlike '*tandem/tools/check.ps1*' })
    if ($keepHooks.Count -ne $oldHooks.Count) { $changed = $true }
    if ($keepHooks.Count -gt 0) {
      if ($keepHooks.Count -ne $oldHooks.Count) { $item.hooks = @($keepHooks) }
      $remaining += $item
    } elseif ($oldHooks.Count -eq 0) { $remaining += $item }
  }
  if ($changed) {
    if ($remaining.Count -gt 0) { $document.hooks.SessionStart = @($remaining) }
    else { $document.hooks.PSObject.Properties.Remove('SessionStart') }
    if ($document.hooks.PSObject.Properties.Count -eq 0) { $document.PSObject.Properties.Remove('hooks') }
  }
  return $changed
}
function HookEntry([string]$agent) {
  return [pscustomobject]@{ matcher='startup'; hooks=@([pscustomobject]@{
    type='command'; command="powershell -NoProfile -ExecutionPolicy Bypass -File tandem/tools/check.ps1 -Agent $agent"; timeout=15
  }) }
}
foreach ($entry in $contract.files | Where-Object { $_.kind -in @('settings','codex-hooks') }) {
  $dst = Dest ([string]$entry.dst); $full = Join-Path $root $dst
  $active = @($entry.modes) -contains $Mode
  if (-not $active -and -not (Test-Path -LiteralPath $full)) { continue }
  $source = Join-Path $langRoot $entry.src
  if ($active) {
    if (-not (Test-Path -LiteralPath $source)) { Warn "$($m.missing): $source"; continue }
    $template = Render $source
    try { $incoming = $template | ConvertFrom-Json }
    catch { throw "$($m.badJsonTemplate): $source" }
  }
  if (Test-Path -LiteralPath $full) {
    try { $current = (ReadUtf8 $full) | ConvertFrom-Json }
    catch {
      if ($active -and (SaveCandidate "$full.new" ($utf8.GetBytes($template)))) { $changes++ }
      Warn "$($m.parse): $dst"
      continue
    }
  } else { $current = [pscustomobject]@{} }
  if ($active -and $entry.kind -eq 'settings') {
    $envPart = Prop $current 'env' ([pscustomobject]@{})
    foreach ($p in $incoming.env.PSObject.Properties) { $envPart | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value -Force }
    $permissions = Prop $current 'permissions' ([pscustomobject]@{})
    $allow = @(Prop $permissions 'allow' @()) + @($incoming.permissions.allow) + @('Bash(powershell -NoProfile -ExecutionPolicy Bypass -File tandem/tools/*)') | Select-Object -Unique
    $permissions.allow = @($allow)
  }
  $wantHook = ($entry.kind -eq 'settings' -and $Mode -in @('claude-main','claude-solo')) -or
              ($entry.kind -eq 'codex-hooks' -and $Mode -in @('codex-main','codex-solo'))
  $removedHook = $false
  if (-not $wantHook) { $removedHook = RemoveCheckHooks $current }
  if ($wantHook) {
    $hooks = Prop $current 'hooks' ([pscustomobject]@{})
    $sessions = @(Prop $hooks 'SessionStart' @())
    if (-not (HasCheckHook $sessions)) {
      $agent = if ($entry.kind -eq 'settings') { 'claude' } else { 'codex' }
      $hooks.SessionStart = @($sessions) + @(HookEntry $agent)
    }
  }
  if ($active -or $removedHook) {
    if (SaveText $full (Json $current)) { $changes++; Note "$($m.replaced): $dst" }
  }
}

$gitignore = Join-Path $root '.gitignore'
$ignoreText = ''
if (Test-Path -LiteralPath $gitignore) {
  try { $ignoreText = ReadUtf8 $gitignore }
  catch {
    $candidate = ".codex-last/`ntandem/.cache/`n"
    if (SaveCandidate "$gitignore.new" ($utf8.GetBytes($candidate))) { $changes++ }
    Warn "$($m.encoding): .gitignore"
    $ignoreText = $null
  }
}
if ($null -ne $ignoreText) {
foreach ($pattern in @('.codex-last/','tandem/.cache/')) {
  if (@($ignoreText -split '\r?\n') -notcontains $pattern) {
    if ($ignoreText -and -not $ignoreText.EndsWith("`n")) { $ignoreText += "`n" }
    $ignoreText += "$pattern`n"
  }
}
if (SaveText $gitignore $ignoreText) { $changes++; Note "$($m.replaced): .gitignore" }
}

if ($changes -eq 0) { Note $m.unchanged }
Write-Host $m.done -ForegroundColor Green
Write-Host $(if ($cfg.jev.enabled) { $m.jevOn } else { $m.jevOff })
if ($Mode -like 'claude-*') { Write-Host $m.nextClaude } else { Write-Host $m.nextCodex }
exit 0
