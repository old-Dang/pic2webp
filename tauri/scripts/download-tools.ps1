# Pic2WebP Windows 工具下载脚本
# 运行方式：右键 "以 PowerShell 运行" 或 .\download-tools.ps1

$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "=== Pic2WebP 工具下载 ===" -ForegroundColor Green
Write-Host ""

# cwebp (必需) - 已包含在 tools/ 目录
$cwebpPath = Join-Path $toolsDir "cwebp.exe"
if (Test-Path $cwebpPath) {
    Write-Host "✓ cwebp.exe 已就绪" -ForegroundColor Green
} else {
    Write-Host "正在下载 cwebp.exe..." -ForegroundColor Yellow
    # L3: bump this when new libwebp releases are available
    $libwebpVersion = "1.6.0"
    $url = "https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-$libwebpVersion-windows-x64.zip"
    $zip = Join-Path $env:TEMP "libwebp-windows.zip"
    Invoke-WebRequest -Uri $url -OutFile $zip
    Expand-Archive -Path $zip -DestinationPath $env:TEMP -Force
    Move-Item "$env:TEMP\libwebp-1.6.0-windows-x64\bin\cwebp.exe" $cwebpPath -Force
    Remove-Item "$env:TEMP\libwebp-1.6.0-windows-x64" -Recurse -Force
    Remove-Item $zip -Force
    Write-Host "✓ cwebp.exe 下载完成" -ForegroundColor Green
}

Write-Host ""
Write-Host "可选工具（缺失自动跳过，不影响核心功能）：" -ForegroundColor Cyan

# jpegoptim (可选)
$jpegPath = Join-Path $toolsDir "jpegoptim.exe"
if (-not (Test-Path $jpegPath)) {
    Write-Host "  - jpegoptim.exe: 跳过（可选）" -ForegroundColor DarkGray
}

# pngquant (可选)
$pngPath = Join-Path $toolsDir "pngquant.exe"
if (-not (Test-Path $pngPath)) {
    Write-Host "  - pngquant.exe: 跳过（可选）" -ForegroundColor DarkGray
}

# oxipng (可选)
$oxiPath = Join-Path $toolsDir "oxipng.exe"
if (-not (Test-Path $oxiPath)) {
    Write-Host "  - oxipng.exe: 跳过（可选）" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "=== 完成 ===" -ForegroundColor Green
Write-Host "运行 npm run tauri build 即可打包" -ForegroundColor Yellow
