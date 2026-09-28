param([string]$OutputDirectory = '')
. "$PSScriptRoot\prepare.ps1"
& $script:Flutter build windows --release --no-pub
if ($LASTEXITCODE -ne 0) { throw 'Release 构建失败。' }
if (!$OutputDirectory) { $OutputDirectory = Join-Path $repo 'dist\JobTracker-Windows-x64' }
$destination = [IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Force -Path $destination | Out-Null
Copy-Item -Path "$repo\build\windows\x64\runner\Release\*" -Destination $destination -Recurse -Force -Exclude 'native_assets.json'
# Bundle the redistributable C++ runtime supplied by Visual Studio.
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if (Test-Path -LiteralPath $vswhere) {
    $vs = & $vswhere -latest -property installationPath
    $redist = Get-ChildItem -Path "$vs\VC\Redist\MSVC\*\x64\Microsoft.VC143.CRT" -Directory -ErrorAction SilentlyContinue | Select-Object -Last 1
    if ($redist) { Copy-Item -Path (Join-Path $redist.FullName '*.dll') -Destination $destination -Force }
}
Copy-Item -LiteralPath "$repo\docs\使用说明.txt" -Destination $destination -Force
Write-Host "发布目录：$destination"
Write-Host '分发时请复制整个目录；不要只复制 EXE。'
