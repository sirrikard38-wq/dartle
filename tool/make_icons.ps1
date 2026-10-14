# Draws the app icons into web/icons/ : a black tile with a white dartboard.
#   powershell -ExecutionPolicy Bypass -File tool/make_icons.ps1
Add-Type -AssemblyName System.Drawing

$out = Join-Path $PSScriptRoot '..\web\icons'
New-Item -ItemType Directory -Force $out | Out-Null

function New-Icon([int]$size, [double]$scale, [string]$name) {
  $bmp = New-Object System.Drawing.Bitmap $size, $size
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = 'AntiAlias'
  $g.Clear([System.Drawing.Color]::Black)

  $c = $size / 2.0
  $R = $size * 0.5 * $scale            # outer radius of the board
  $light = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(242, 242, 242))
  $dark = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(118, 118, 118))
  $black = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::Black)

  function Disc($r, $brush) { $g.FillEllipse($brush, [single]($c - $r), [single]($c - $r), [single](2 * $r), [single](2 * $r)) }

  # 20 wedges, the 20 at the top.
  for ($i = 0; $i -lt 20; $i++) {
    $start = -90 + 18 * $i - 9
    $brush = if ($i % 2 -eq 0) { $light } else { $dark }
    $g.FillPie($brush, [single]($c - $R), [single]($c - $R), [single](2 * $R), [single](2 * $R), [single]$start, [single]18)
  }
  # The dark rings that carve out the double and treble rings.
  foreach ($ring in @(@(0.93, 0.045), @(0.62, 0.045), @(0.55, 0.045))) {
    $r = $R * $ring[0]; $w = $R * $ring[1]
    $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::Black), ([single]$w)
    $g.DrawEllipse($pen, [single]($c - $r), [single]($c - $r), [single](2 * $r), [single](2 * $r))
  }
  # Bull and outer bull.
  Disc ($R * 0.2) $black
  Disc ($R * 0.17) $light
  Disc ($R * 0.075) $black

  $g.Dispose()
  $path = Join-Path $out $name
  $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
  Write-Output "wrote $name ($size x $size)"
}

New-Icon 192 0.92 'icon-192.png'
New-Icon 512 0.92 'icon-512.png'
New-Icon 512 0.72 'icon-maskable-512.png'      # extra margin: platforms crop it
New-Icon 180 0.92 'apple-touch-icon.png'
New-Icon 32 0.96 'favicon-32.png'
