<# TANDEM remote bootstrap. Keep this file ASCII without a BOM for iwr | iex. #>
[CmdletBinding()]
param(
  [string]$DocsRoot,
  [ValidateSet('claude-main','codex-main','claude-solo','codex-solo')][string]$Mode,
  [ValidateSet('ko','en')][string]$Lang,
  [string]$JevKey,
  [switch]$NoJev,
  [string]$Repo = 'carydev/Tandem',
  [string]$Ref = 'main',
  [switch]$SkipDeps,
  [switch]$Yes,
  [switch]$Force
)
$ErrorActionPreference = 'Stop'
$target = (Get-Location).Path
$tempDir = Join-Path ([IO.Path]::GetTempPath()) ('tandem-' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($tempDir)
try {
  $zip = Join-Path $tempDir 'src.zip'
  Invoke-WebRequest -UseBasicParsing -Uri "https://codeload.github.com/$Repo/zip/$Ref" -OutFile $zip
  Expand-Archive -Path $zip -DestinationPath $tempDir -Force
  $source = Get-ChildItem -Path $tempDir -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'install.ps1') } | Select-Object -First 1
  if (-not $source) { throw 'install.ps1 not found in downloaded archive.' }
  $arguments = @{}
  foreach ($name in @('DocsRoot','Mode','Lang','JevKey','NoJev','SkipDeps','Yes','Force')) {
    if ($PSBoundParameters.ContainsKey($name)) { $arguments[$name] = $PSBoundParameters[$name] }
  }
  Push-Location $target
  try { & (Join-Path $source.FullName 'install.ps1') @arguments }
  finally { Pop-Location }
}
finally { Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue }
