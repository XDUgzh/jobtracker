. "$PSScriptRoot\prepare.ps1"
& $script:Flutter run -d windows --no-pub
if ($LASTEXITCODE -ne 0) { throw '应用启动失败。' }
