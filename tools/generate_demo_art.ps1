# Original geometric artwork for fictional review games. No remote assets.
Add-Type -AssemblyName System.Drawing
$artRoot = Join-Path $PSScriptRoot '../assets/art'
[System.IO.Directory]::CreateDirectory($artRoot) | Out-Null
for ($index = 0; $index -lt 12; $index++) {
    $canvas = [System.Drawing.Bitmap]::new(900, 650)
    $graphics = [System.Drawing.Graphics]::FromImage($canvas)
    $graphics.SmoothingMode = 'AntiAlias'
    $hue = @('#342360','#144D60','#474437','#4D234B')[$index % 4]
    $gradient = [System.Drawing.Drawing2D.LinearGradientBrush]::new([System.Drawing.Rectangle]::new(0,0,900,650), [System.Drawing.ColorTranslator]::FromHtml($hue), [System.Drawing.Color]::FromArgb(7,11,26), 90)
    $graphics.FillRectangle($gradient, 0, 0, 900, 650)
    $random = [System.Random]::new(100 + $index)
    $star = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(140,220,225,255))
    for ($point = 0; $point -lt 110; $point++) { $x = $random.Next(900); $y = $random.Next(490); $graphics.FillEllipse($star,$x,$y,2,2) }
    $moon = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255,190,172 + ($index % 4)*15,255))
    $graphics.FillEllipse($moon, 515 - ($index % 3)*90, 70, 205, 205)
    $pen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(100,220,202,255),2)
    $graphics.DrawEllipse($pen, 460 - ($index % 3)*90, 160, 330, 65)
    for ($layer = 0; $layer -lt 3; $layer++) {
        $points = [System.Drawing.Point[]]@([System.Drawing.Point]::new(0,650),[System.Drawing.Point]::new(0,420 + $layer*55))
        for ($x = 0; $x -le 1000; $x += 100) { $points += [System.Drawing.Point]::new($x, $random.Next(310,450) + $layer*70) }
        $points += [System.Drawing.Point]::new(900,650)
        $brush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 22 - $layer*5, 32 - $layer*6, 58 - $layer*9))
        $graphics.FillPolygon($brush,$points); $brush.Dispose()
    }
    $glow = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(140,132,220,235),3)
    $graphics.DrawBezier($glow, 430,650, 300,550, 650,490, 570,420)
    $canvas.Save((Join-Path $artRoot "$($index + 1).png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $gradient.Dispose(); $star.Dispose(); $moon.Dispose(); $pen.Dispose(); $glow.Dispose(); $graphics.Dispose(); $canvas.Dispose()
}
