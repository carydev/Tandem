<# TANDEM remote bootstrap. Keep this file ASCII without a BOM for iwr | iex. #>
[CmdletBinding()]
param(
  [string]$DocsRoot,
  [ValidateSet('claude-main','codex-main','claude-solo','codex-solo')][string]$Mode,
  [ValidateSet('ko','en')][string]$Lang,
  [string]$JevKey,
  [switch]$NoJev,
  [switch]$UseJev,
  [string]$Repo = 'carydev/Tandem',
  [string]$Ref = 'main',
  [switch]$SkipDeps,
  [switch]$Yes,
  [switch]$Force,
  [switch]$Plan,
  [switch]$Clean
)
$ErrorActionPreference = 'Stop'
$selectedLang = if ($Lang) { $Lang } elseif ((Get-UICulture).Name -like 'ko*') { 'ko' } else { 'en' }
$messages = @{
  ko = @{ download=[regex]::Unescape('\u0054\u0041\u004e\u0044\u0045\u004d\u0020\ub2e4\uc6b4\ub85c\ub4dc\u0020\uc911'); downloadError=[regex]::Unescape('\u0054\u0041\u004e\u0044\u0045\u004d\uc744\u0020\ub2e4\uc6b4\ub85c\ub4dc\ud558\uc9c0\u0020\ubabb\ud588\uc2b5\ub2c8\ub2e4\u002e'); extractError=[regex]::Unescape('\ub2e4\uc6b4\ub85c\ub4dc\ud55c\u0020\uc555\ucd95\u0020\ud30c\uc77c\uc744\u0020\ud480\uc9c0\u0020\ubabb\ud588\uc2b5\ub2c8\ub2e4\u002e'); missing=[regex]::Unescape('\ub2e4\uc6b4\ub85c\ub4dc\ud55c\u0020\uc555\ucd95\u0020\ud30c\uc77c\uc5d0\u0020\u0069\u006e\u0073\u0074\u0061\u006c\u006c\u002e\u0070\u0073\u0031\uc774\u0020\uc5c6\uc2b5\ub2c8\ub2e4\u002e') }
  en = @{ download='Downloading TANDEM'; downloadError='Could not download TANDEM.'; extractError='Could not extract the downloaded archive.'; missing='install.ps1 not found in downloaded archive.' }
}
$m = $messages[$selectedLang]
$target = (Get-Location).Path
$tempDir = Join-Path ([IO.Path]::GetTempPath()) ('tandem-' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($tempDir)
try {
  $zip = Join-Path $tempDir 'src.zip'
  Write-Host $m.download
  try { Invoke-WebRequest -UseBasicParsing -Uri "https://codeload.github.com/$Repo/zip/$Ref" -OutFile $zip }
  catch { throw $m.downloadError }
  try { Expand-Archive -Path $zip -DestinationPath $tempDir -Force }
  catch { throw $m.extractError }
  $source = Get-ChildItem -Path $tempDir -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'install.ps1') } | Select-Object -First 1
  if (-not $source) { throw $m.missing }
  $arguments = @{}
  foreach ($name in @('DocsRoot','Mode','Lang','JevKey','NoJev','UseJev','SkipDeps','Yes','Force','Plan','Clean')) {
    if ($PSBoundParameters.ContainsKey($name)) { $arguments[$name] = $PSBoundParameters[$name] }
  }
  Push-Location $target
  try { & (Join-Path $source.FullName 'install.ps1') @arguments }
  finally { Pop-Location }
}
finally { Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue }
