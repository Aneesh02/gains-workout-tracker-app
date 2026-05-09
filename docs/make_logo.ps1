Add-Type -AssemblyName System.Drawing

$size = 512
$cx = 256
$cy = 256

$bmp = New-Object System.Drawing.Bitmap($size, $size)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.Clear([System.Drawing.Color]::FromArgb(255, 42, 45, 53))

function DrawCircle($graphics, $x, $y, $r, $color) {
    $brush = New-Object System.Drawing.SolidBrush($color)
    $graphics.FillEllipse($brush, $x - $r, $y - $r, $r * 2, $r * 2)
    $brush.Dispose()
}

DrawCircle $g $cx $cy 215 ([System.Drawing.Color]::FromArgb(255, 40, 114, 204))
DrawCircle $g $cx $cy 190 ([System.Drawing.Color]::FromArgb(255, 42, 45, 53))
DrawCircle $g $cx $cy 154 ([System.Drawing.Color]::FromArgb(255, 74, 158, 255))
DrawCircle $g $cx $cy 103 ([System.Drawing.Color]::FromArgb(255, 107, 184, 255))

$b1 = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 40, 114, 204))
$g.FillRectangle($b1, 0, 243, 512, 26)
$b1.Dispose()

$b2 = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 107, 184, 255))
$g.FillRectangle($b2, 0, 243, 512, 6)
$b2.Dispose()

DrawCircle $g $cx $cy 36 ([System.Drawing.Color]::FromArgb(255, 42, 45, 53))

$g.Dispose()
$bmp.Save("$PSScriptRoot\logo.png", [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Host "Done: $PSScriptRoot\logo.png"
