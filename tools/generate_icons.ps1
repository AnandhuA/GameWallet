Add-Type -AssemblyName System.Drawing
$repoRoot = Split-Path $PSScriptRoot -Parent
function Save-AtlasIcon([string]$relativePath, [int]$size) {
    $bitmap = [System.Drawing.Bitmap]::new($size, $size)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = 'AntiAlias'
    $graphics.Clear([System.Drawing.ColorTranslator]::FromHtml('#171320'))
    $brush = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml('#B49CFF'))
    $graphics.FillEllipse($brush, $size*.13, $size*.13, $size*.74, $size*.74)
    $pen = [System.Drawing.Pen]::new([System.Drawing.ColorTranslator]::FromHtml('#201833'), $size*.045)
    $graphics.DrawEllipse($pen, $size*.26, $size*.3, $size*.48, $size*.33)
    $graphics.DrawLine($pen, $size*.33,$size*.46,$size*.47,$size*.46)
    $graphics.DrawLine($pen, $size*.4,$size*.39,$size*.4,$size*.53)
    $dot = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml('#201833'))
    $graphics.FillEllipse($dot,$size*.57,$size*.4,$size*.055,$size*.055)
    $graphics.FillEllipse($dot,$size*.64,$size*.48,$size*.055,$size*.055)
    $bitmap.Save((Join-Path $repoRoot $relativePath), [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose(); $brush.Dispose(); $pen.Dispose(); $dot.Dispose(); $bitmap.Dispose()
}
Save-AtlasIcon 'web/favicon.png' 64
foreach ($size in @(192,512)) { Save-AtlasIcon "web/icons/Icon-$size.png" $size; Save-AtlasIcon "web/icons/Icon-maskable-$size.png" $size }
$densities = @{mdpi=48;hdpi=72;xhdpi=96;xxhdpi=144;xxxhdpi=192}
foreach ($density in $densities.Keys) { Save-AtlasIcon "android/app/src/main/res/mipmap-$density/ic_launcher.png" $densities[$density] }
$contents = Get-Content (Join-Path $repoRoot 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json') -Raw | ConvertFrom-Json
foreach ($image in $contents.images) {
    $size = [double]($image.size.Split('x')[0]) * [double]($image.scale.Replace('x',''))
    Save-AtlasIcon "ios/Runner/Assets.xcassets/AppIcon.appiconset/$($image.filename)" ([int]$size)
}
# Windows supports PNG-compressed ICO entries.
Save-AtlasIcon 'assets/art/icon.png' 256
$png = [System.IO.File]::ReadAllBytes((Join-Path $repoRoot 'assets/art/icon.png'))
$writer = [System.IO.BinaryWriter]::new([System.IO.File]::Create((Join-Path $repoRoot 'windows/runner/resources/app_icon.ico')))
$writer.Write([UInt16]0); $writer.Write([UInt16]1); $writer.Write([UInt16]1)
$writer.Write([byte]0); $writer.Write([byte]0); $writer.Write([byte]0); $writer.Write([byte]0)
$writer.Write([UInt16]1); $writer.Write([UInt16]32); $writer.Write([UInt32]$png.Length); $writer.Write([UInt32]22); $writer.Write($png); $writer.Dispose()
