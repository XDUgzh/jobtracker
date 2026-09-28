$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repo
$flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
if ($flutterCommand) {
    $script:Flutter = $flutterCommand.Source
} else {
    $script:Flutter = Join-Path $env:LOCALAPPDATA 'JobTrackerDev\flutter\bin\flutter.bat'
}
if (!(Test-Path -LiteralPath $script:Flutter)) { throw '请安装 Flutter stable，并把 flutter/bin 添加到 PATH。' }
if (!$env:PUB_CACHE) {
    $savedCache = [Environment]::GetEnvironmentVariable('PUB_CACHE', 'User')
    if ($savedCache) { $env:PUB_CACHE = $savedCache }
}
$pubOutput = & $script:Flutter pub get 2>&1
$pubExit = $LASTEXITCODE
$pubOutput | ForEach-Object { Write-Host $_ }
if ($pubExit -ne 0) {
    if (($pubOutput -join "`n") -notmatch 'symlink support') { throw '依赖下载失败，请检查以上错误。' }
    # Junctions support desktop plugins without changing machine-wide developer settings.
    $manifest = Get-Content '.flutter-plugins-dependencies' -Raw | ConvertFrom-Json
    $linkRoot = Join-Path $repo 'windows\flutter\ephemeral\.plugin_symlinks'
    New-Item -ItemType Directory -Force -Path $linkRoot | Out-Null
    foreach ($plugin in $manifest.plugins.windows) {
        $linkPath = Join-Path $linkRoot $plugin.name
        if (!(Test-Path -LiteralPath $linkPath)) {
            $targetPath = $plugin.path -replace '\\\\', '\'
            New-Item -ItemType Junction -Path $linkPath -Target $targetPath | Out-Null
        }
    }
    & $script:Flutter pub get
    if ($LASTEXITCODE -ne 0) { throw '插件配置失败。请在 Windows 设置中启用开发者模式，然后重试。' }
}
