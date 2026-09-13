# Script de generation automatique des icones Android et Web pour Lupus Arena
param(
    [string]$SourcePath = ""
)

Add-Type -AssemblyName System.Drawing

# 1. Detection du fichier source
$candidates = @(
    $SourcePath,
    "C:\Users\hp\.gemini\antigravity-ide\brain\27f69c18-2f67-4bed-a62f-472049a718d3\.user_uploaded\media_1788955475154.png",
    ".\assets\images\app_icon_source.png"
)

$src = ""
foreach ($cand in $candidates) {
    if ($cand -and (Test-Path $cand)) {
        $src = $cand
        break
    }
}

if (-not $src) {
    Write-Error "Fichier source introuvable. Veuillez specifier le chemin de l'image."
    exit 1
}

Write-Host "=================================================" -ForegroundColor Cyan
Write-Host " [LUPUS ARENA] GENERATION DES ICONES ANDROID & WEB " -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "Image source trouvee : $src" -ForegroundColor Green

# Sauvegarde de la source brute dans assets/images/app_icon_source.png
$assetsDir = ".\assets\images"
if (-not (Test-Path $assetsDir)) {
    New-Item -ItemType Directory -Path $assetsDir -Force | Out-Null
}
Copy-Item -Path $src -Destination "$assetsDir\app_icon_source.png" -Force

# Fonction de redimensionnement de qualite superieure (Bicubic + Smoothing)
function Generate-Icon {
    param(
        [System.Drawing.Image]$sourceImg,
        [int]$width,
        [int]$height,
        [string]$destinationPath
    )

    $parentDir = Split-Path -Parent $destinationPath
    if (-not (Test-Path $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }

    $destBmp = New-Object System.Drawing.Bitmap $width, $height
    $g = [System.Drawing.Graphics]::FromImage($destBmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)

    $g.DrawImage($sourceImg, 0, 0, $width, $height)
    $g.Dispose()

    # Si le fichier existe deja, on supprime d'abord pour eviter les locks
    if (Test-Path $destinationPath) {
        Remove-Item -Path $destinationPath -Force
    }

    $destBmp.Save($destinationPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $destBmp.Dispose()

    Write-Host "  [OK] $destinationPath ($width x $height)" -ForegroundColor Gray
}

# Chargement de l'image en memoire pour eviter tout lock
$fileBytes = [System.IO.File]::ReadAllBytes($src)
$ms = New-Object System.IO.MemoryStream(,$fileBytes)
$img = [System.Drawing.Image]::FromStream($ms)

# 2. Icones Android (Mipmap Standard & Round)
Write-Host "`nGeneration des icones Android (mipmap standard & round)..." -ForegroundColor Yellow
Generate-Icon $img 48 48   "android\app\src\main\res\mipmap-mdpi\ic_launcher.png"
Generate-Icon $img 48 48   "android\app\src\main\res\mipmap-mdpi\ic_launcher_round.png"
Generate-Icon $img 72 72   "android\app\src\main\res\mipmap-hdpi\ic_launcher.png"
Generate-Icon $img 72 72   "android\app\src\main\res\mipmap-hdpi\ic_launcher_round.png"
Generate-Icon $img 96 96   "android\app\src\main\res\mipmap-xhdpi\ic_launcher.png"
Generate-Icon $img 96 96   "android\app\src\main\res\mipmap-xhdpi\ic_launcher_round.png"
Generate-Icon $img 144 144 "android\app\src\main\res\mipmap-xxhdpi\ic_launcher.png"
Generate-Icon $img 144 144 "android\app\src\main\res\mipmap-xxhdpi\ic_launcher_round.png"
Generate-Icon $img 192 192 "android\app\src\main\res\mipmap-xxxhdpi\ic_launcher.png"
Generate-Icon $img 192 192 "android\app\src\main\res\mipmap-xxxhdpi\ic_launcher_round.png"

# 3. Icones Web & PWA
Write-Host "`nGeneration des icones Web (Favicon & PWA)..." -ForegroundColor Yellow
Generate-Icon $img 512 512 "web\favicon.png"
Generate-Icon $img 192 192 "web\icons\Icon-192.png"
Generate-Icon $img 512 512 "web\icons\Icon-512.png"
Generate-Icon $img 192 192 "web\icons\Icon-maskable-192.png"
Generate-Icon $img 512 512 "web\icons\Icon-maskable-512.png"
Generate-Icon $img 512 512 "web\icons\lupus_seal.png"
Copy-Item -Path "web\favicon.png" -Destination "web\favicon.ico" -Force

# 4. Assets du jeu Flutter
Write-Host "`nActualisation des assets Flutter..." -ForegroundColor Yellow
Generate-Icon $img 512 512 "assets\images\lupus_seal.png"
Generate-Icon $img 512 512 "assets\images\app_icon.png"

# 5. Mise a jour du cache build (pour hot reload / web server)
if (Test-Path "build\flutter_assets\assets\images") {
    Generate-Icon $img 512 512 "build\flutter_assets\assets\images\lupus_seal.png"
}
if (Test-Path "build\web") {
    Copy-Item -Path "web\favicon.png" -Destination "build\web\favicon.png" -Force
    Copy-Item -Path "web\favicon.ico" -Destination "build\web\favicon.ico" -Force
    Copy-Item -Path "web\icons\*" -Destination "build\web\icons\" -Recurse -Force
}

$img.Dispose()
$ms.Dispose()

Write-Host "`nSucces : Toutes les icones Android et Web ont ete mises a jour !" -ForegroundColor Green
Write-Host "Pour recharger sur le serveur Web, tapez 'R' (Hot restart) dans votre terminal Flutter." -ForegroundColor Cyan
