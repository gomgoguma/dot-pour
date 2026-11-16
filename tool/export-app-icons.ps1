# Export the generated logo into native launcher sizes. Windows PowerShell/.NET.
# The source image is preserved; this script only resizes/composes platform assets.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$projectRoot = Split-Path -Parent $PSScriptRoot
$logoPath = Join-Path $projectRoot 'assets/brand/dot-pour-drop.png'
$sourceLogo = [System.Drawing.Bitmap]::new($logoPath)

function New-IconImage([int]$Size, [bool]$Opaque, [double]$Scale) {
    $format = if ($Opaque) { [System.Drawing.Imaging.PixelFormat]::Format24bppRgb } else { [System.Drawing.Imaging.PixelFormat]::Format32bppArgb }
    $bitmap = [System.Drawing.Bitmap]::new($Size, $Size, $format)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $background = if ($Opaque) { [System.Drawing.Color]::FromArgb(247, 245, 239) } else { [System.Drawing.Color]::Transparent }
        $graphics.Clear($background)
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $edge = [int][Math]::Round($Size * $Scale)
        $offset = [int][Math]::Round(($Size - $edge) / 2)
        $graphics.DrawImage($sourceLogo, [System.Drawing.Rectangle]::new($offset, $offset, $edge, $edge))
    } finally { $graphics.Dispose() }
    return $bitmap
}

function Write-IconPng([string]$RelativePath, [int]$Size, [bool]$Opaque, [double]$Scale) {
    $path = Join-Path $projectRoot $RelativePath
    [System.IO.Directory]::CreateDirectory((Split-Path -Parent $path)) | Out-Null
    $bitmap = New-IconImage $Size $Opaque $Scale
    try { $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png) }
    finally { $bitmap.Dispose() }
}

try {
    $densities = @{ 'mdpi'=1; 'hdpi'=1.5; 'xhdpi'=2; 'xxhdpi'=3; 'xxxhdpi'=4 }
    foreach ($density in $densities.GetEnumerator()) {
        Write-IconPng "android/app/src/main/res/mipmap-$($density.Key)/ic_launcher.png" ([int](48 * $density.Value)) $true 0.86
        # Keep the visible drop within the adaptive icon's circular safe area.
        Write-IconPng "android/app/src/main/res/mipmap-$($density.Key)/ic_launcher_foreground.png" ([int](108 * $density.Value)) $false 0.78
    }
    $contents = Get-Content -Raw (Join-Path $projectRoot 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json') | ConvertFrom-Json
    foreach ($entry in ($contents.images | Sort-Object filename -Unique)) {
        $size = [double]::Parse(($entry.size -split 'x')[0], [System.Globalization.CultureInfo]::InvariantCulture)
        $multiplier = [int](($entry.scale -split 'x')[0])
        Write-IconPng "ios/Runner/Assets.xcassets/AppIcon.appiconset/$($entry.filename)" ([int]($size * $multiplier)) $true 0.86
    }
    # ICO with PNG entries for every common Windows shell/window size.
    $sizes = @(16, 24, 32, 48, 64, 128, 256)
    $frames = foreach ($size in $sizes) {
        $bitmap = New-IconImage $size $false 1.0
        $stream = [System.IO.MemoryStream]::new()
        try {
            $bitmap.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
            ,$stream.ToArray()
        } finally { $bitmap.Dispose(); $stream.Dispose() }
    }
    $file = [System.IO.File]::Create((Join-Path $projectRoot 'windows/runner/resources/app_icon.ico'))
    $writer = [System.IO.BinaryWriter]::new($file)
    try {
        $writer.Write([uint16]0); $writer.Write([uint16]1); $writer.Write([uint16]$sizes.Count)
        $offset = 6 + 16 * $sizes.Count
        for ($i = 0; $i -lt $sizes.Count; $i++) {
            $dimension = if ($sizes[$i] -eq 256) { 0 } else { $sizes[$i] }
            $writer.Write([byte]$dimension); $writer.Write([byte]$dimension)
            $writer.Write([byte]0); $writer.Write([byte]0)
            $writer.Write([uint16]1); $writer.Write([uint16]32)
            $writer.Write([uint32]$frames[$i].Length); $writer.Write([uint32]$offset)
            $offset += $frames[$i].Length
        }
        foreach ($frame in $frames) { $writer.Write([byte[]]$frame) }
    } finally { $writer.Dispose(); $file.Dispose() }
} finally { $sourceLogo.Dispose() }
Write-Output 'Exported Android, iOS and Windows launcher icons.'
