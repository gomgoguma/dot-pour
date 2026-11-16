$ErrorActionPreference = 'Stop'
$taskRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$taskMetadata = Get-Content -Raw -LiteralPath (Join-Path $taskRoot '.flutter-plugins-dependencies') | ConvertFrom-Json
$taskLinks = Join-Path $taskRoot 'windows\flutter\ephemeral\.plugin_symlinks'
New-Item -ItemType Directory -Force -Path $taskLinks | Out-Null
foreach ($taskPlugin in $taskMetadata.plugins.windows) {
    $taskLink = Join-Path $taskLinks $taskPlugin.name
    if (-not (Test-Path -LiteralPath $taskLink)) {
        $taskTarget = (Resolve-Path -LiteralPath $taskPlugin.path).Path
        New-Item -ItemType Junction -Path $taskLink -Target $taskTarget | Out-Null
    }
}
Write-Output 'Windows plugin junctions are ready.'
