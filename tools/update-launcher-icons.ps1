$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

$projectRoot = Split-Path -Parent $PSScriptRoot
$source = Join-Path $projectRoot 'assets\images\LogoOfApp.png'
$resRoot = Join-Path $projectRoot 'android\app\src\main\res'

if (-not (Test-Path $source)) {
    throw "Source image not found: $source"
}

$sizes = @{
    'mipmap-mdpi' = 48
    'mipmap-hdpi' = 72
    'mipmap-xhdpi' = 96
    'mipmap-xxhdpi' = 144
    'mipmap-xxxhdpi' = 192
}

foreach ($entry in $sizes.GetEnumerator()) {
    $folder = Join-Path $resRoot $entry.Key
    $output = Join-Path $folder 'ic_launcher.png'

    if (-not (Test-Path $folder)) {
        throw "Missing resource folder: $folder"
    }

    $image = [System.Drawing.Image]::FromFile($source)
    try {
        $bitmap = New-Object System.Drawing.Bitmap $entry.Value, $entry.Value
        try {
            $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
            try {
                $graphics.Clear([System.Drawing.Color]::Transparent)
                $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
                $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                $graphics.DrawImage($image, 0, 0, $entry.Value, $entry.Value)
                $bitmap.Save($output, [System.Drawing.Imaging.ImageFormat]::Png)
            } finally {
                $graphics.Dispose()
            }
        } finally {
            $bitmap.Dispose()
        }
    } finally {
        $image.Dispose()
    }
}

Write-Host 'Launcher icons updated from assets/images/LogoOfApp.png'
