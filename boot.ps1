<#
  TANDEM remote bootstrap (Windows / PowerShell)

  One-line install:
    iwr -useb https://raw.githubusercontent.com/carydev/Tandem/main/boot.ps1 | iex

  With options:
    & ([scriptblock]::Create((iwr -useb https://raw.githubusercontent.com/carydev/Tandem/main/boot.ps1))) -DocsRoot docs/ops

  Downloads the repo to a temp folder, runs install.ps1 against the current folder, cleans up.

  Keep this file ASCII-only and saved WITHOUT a BOM.
  A BOM breaks `iwr | iex` on Windows PowerShell 5.1 ("Unexpected attribute 'CmdletBinding'").
#>
[CmdletBinding()]
param(
  [string]$DocsRoot = "docs/tandem",
  [string]$Repo     = "carydev/Tandem",   # change this if you fork
  [string]$Ref      = "main",             # branch or tag, e.g. v1.0
  [switch]$SkipDeps,
  [switch]$Yes,
  [switch]$Force
)

$ErrorActionPreference = "Stop"
$target = (Get-Location).Path
Write-Host ""
Write-Host "Downloading TANDEM: $Repo@$Ref" -ForegroundColor Cyan

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("tandem-" + [guid]::NewGuid().ToString("N").Substring(0,8))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
try {
  $zip = Join-Path $tmp "src.zip"
  Invoke-WebRequest -UseBasicParsing -Uri "https://codeload.github.com/$Repo/zip/$Ref" -OutFile $zip
  Expand-Archive -Path $zip -DestinationPath $tmp -Force

  $src = Get-ChildItem -Path $tmp -Directory | Where-Object { Test-Path (Join-Path $_.FullName "install.ps1") } | Select-Object -First 1
  if (-not $src) { throw "install.ps1 not found in the downloaded archive." }

  Push-Location $target
  try {
    $a = @{ DocsRoot = $DocsRoot }
    if ($SkipDeps) { $a.SkipDeps = $true }
    if ($Yes)      { $a.Yes      = $true }
    if ($Force)    { $a.Force    = $true }
    & (Join-Path $src.FullName "install.ps1") @a
  } finally { Pop-Location }
}
finally { Remove-Item -Path $tmp -Recurse -Force -ErrorAction SilentlyContinue }
