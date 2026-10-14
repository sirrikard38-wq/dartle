# Draws the app icons: a black tile with a white dartboard.
#   powershell -ExecutionPolicy Bypass -File tool/make_icons.ps1
#
#  * web/icons/          the installable web app's icons (manifest, iPhone, favicon)
#  * android-app/assets/ the source art the Android app's icons and splash screen
#                        are made from (by @capacitor/assets, in the GitHub build)
Add-Type -AssemblyName System.Drawing

$root = Join-Path $PSScriptRoot '..'
$web = Join-Path $root 'web\icons'
$android = Join-Path $root 'android-app\assets'
New-Item -ItemType Directory -Force $web, $android | Out-Null

function New-Icon([int]$size, [double]$scale, [string]$path, [bool]$transparent = $false) {
  $bmp = New-Object System.Drawing.Bitmap $size, $size
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = 'AntiAlias'
  if ($transparent) { $g.Clear([System.Drawing.Color]::Transparent) } else { $g.Clear([System.Drawing.Color]::Black) }

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
  $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
  Write-Output "wrote $(Split-Path $path -Leaf) ($size x $size)"
}

# The web app.
New-Icon 192 0.92 (Join-Path $web 'icon-192.png')
New-Icon 512 0.92 (Join-Path $web 'icon-512.png')
New-Icon 512 0.72 (Join-Path $web 'icon-maskable-512.png')      # extra margin: platforms crop it
New-Icon 180 0.92 (Join-Path $web 'apple-touch-icon.png')
New-Icon 32 0.96 (Join-Path $web 'favicon-32.png')

# The Android app (the names @capacitor/assets looks for).
New-Icon 1024 0.92 (Join-Path $android 'icon-only.png')
New-Icon 1024 0.60 (Join-Path $android 'icon-foreground.png') $true   # adaptive icon: stays in the safe zone
$bg = New-Object System.Drawing.Bitmap 1024, 1024
$gb = [System.Drawing.Graphics]::FromImage($bg); $gb.Clear([System.Drawing.Color]::Black); $gb.Dispose()
$bg.Save((Join-Path $android 'icon-background.png'), [System.Drawing.Imaging.ImageFormat]::Png); $bg.Dispose()
Write-Output 'wrote icon-background.png (1024 x 1024)'
New-Icon 2732 0.16 (Join-Path $android 'splash.png')
New-Icon 2732 0.16 (Join-Path $android 'splash-dark.png')
