param(
    [string]$SourcePath = ''
)

Add-Type -AssemblyName System.Drawing
$repoRoot = Split-Path $PSScriptRoot -Parent
if ([string]::IsNullOrWhiteSpace($SourcePath)) {
    $SourcePath = Join-Path $repoRoot 'assets/branding/app-icon.png'
}
$sourceImage = [System.Drawing.Image]::FromFile((Resolve-Path -LiteralPath $SourcePath).Path)

# Resize the supplied artwork without redrawing it. RGB output keeps iOS icons opaque.
function Save-AppIcon([string]$RelativePath, [int]$Size, [double]$Padding = 0) {
    $bitmap = [System.Drawing.Bitmap]::new($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $attributes = [System.Drawing.Imaging.ImageAttributes]::new()
    try {
        $graphics.Clear([System.Drawing.ColorTranslator]::FromHtml('#040D12'))
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $attributes.SetWrapMode([System.Drawing.Drawing2D.WrapMode]::TileFlipXY)
        $available = $Size * (1 - 2 * $Padding)
        $scale = [Math]::Min($available / $sourceImage.Width, $available / $sourceImage.Height)
        $width = [int][Math]::Round($sourceImage.Width * $scale)
        $height = [int][Math]::Round($sourceImage.Height * $scale)
        $rectangle = [System.Drawing.Rectangle]::new([int](($Size - $width) / 2), [int](($Size - $height) / 2), $width, $height)
        $graphics.DrawImage($sourceImage, $rectangle, 0, 0, $sourceImage.Width, $sourceImage.Height, [System.Drawing.GraphicsUnit]::Pixel, $attributes)
        $target = Join-Path $repoRoot $RelativePath
        [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($target)) | Out-Null
        $bitmap.Save($target, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $attributes.Dispose()
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}

try {
    Save-AppIcon 'web/favicon.png' 64
    foreach ($size in @(192, 512)) {
        Save-AppIcon "web/icons/Icon-$size.png" $size
        Save-AppIcon "web/icons/Icon-maskable-$size.png" $size .12
    }
    $densities = @{mdpi = 48; hdpi = 72; xhdpi = 96; xxhdpi = 144; xxxhdpi = 192}
    foreach ($density in $densities.Keys) {
        Save-AppIcon "android/app/src/main/res/mipmap-$density/ic_launcher.png" $densities[$density]
    }
    $catalog = Get-Content (Join-Path $repoRoot 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json') -Raw | ConvertFrom-Json
    foreach ($image in $catalog.images) {
        $size = [int]([double]($image.size.Split('x')[0]) * [double]($image.scale.Replace('x', '')))
        Save-AppIcon "ios/Runner/Assets.xcassets/AppIcon.appiconset/$($image.filename)" $size
    }
    Save-AppIcon 'assets/art/icon.png' 256

    # Windows ICO entries include crisp sizes for Explorer, taskbars and HiDPI displays.
    $sizes = @(16, 24, 32, 48, 64, 128, 256)
    $entries = [System.Collections.Generic.List[byte[]]]::new()
    foreach ($size in $sizes) {
        $bitmap = [System.Drawing.Bitmap]::new($size, $size)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $stream = [System.IO.MemoryStream]::new()
        try {
            $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.DrawImage($sourceImage, 0, 0, $size, $size)
            $bitmap.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
            $entries.Add($stream.ToArray())
        } finally {
            $stream.Dispose()
            $graphics.Dispose()
            $bitmap.Dispose()
        }
    }
    $writer = [System.IO.BinaryWriter]::new([System.IO.File]::Create((Join-Path $repoRoot 'windows/runner/resources/app_icon.ico')))
    try {
        $writer.Write([UInt16]0)
        $writer.Write([UInt16]1)
        $writer.Write([UInt16]$sizes.Count)
        $offset = 6 + 16 * $sizes.Count
        for ($i = 0; $i -lt $sizes.Count; $i++) {
            $dimension = if ($sizes[$i] -eq 256) { 0 } else { $sizes[$i] }
            $writer.Write([byte]$dimension)
            $writer.Write([byte]$dimension)
            $writer.Write([byte]0)
            $writer.Write([byte]0)
            $writer.Write([UInt16]1)
            $writer.Write([UInt16]32)
            $writer.Write([UInt32]$entries[$i].Length)
            $writer.Write([UInt32]$offset)
            $offset += $entries[$i].Length
        }
        foreach ($entry in $entries) { $writer.Write([byte[]]$entry) }
    } finally {
        $writer.Dispose()
    }
} finally {
    $sourceImage.Dispose()
}
Write-Output 'Generated Android, iOS, web and Windows icons from the supplied Game Wallet artwork.'
