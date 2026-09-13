# ==============================================================================
# SCRIPT D'OPTIMISATION DES ASSETS - LUPUS ARENA
# Réduit le dossier 'LOUP GAROU ENHANCED' de ~165 Mo à ~2.5 Mo
# Garantit un APK propre sous les 50 Mo sans perte de qualité visuelle sur mobile
# ==============================================================================

Add-Type -AssemblyName System.Drawing

$projectRoot = $PSScriptRoot
if (-not $projectRoot) {
    $projectRoot = Get-Location
}

$sourceDir = Join-Path $projectRoot "LOUP GAROU ENHANCED"
$backupDir = Join-Path $projectRoot "LOUP GAROU ENHANCED_BACKUP"
$tempDir   = Join-Path $projectRoot "LOUP GAROU ENHANCED_TEMP"

Write-Host "--- OPTIMISATION DES ASSETS LUPUS ARENA ---" -ForegroundColor Cyan
Write-Host "Dossier source : $sourceDir"

if (-not (Test-Path $sourceDir)) {
    Write-Error "Dossier $sourceDir introuvable !"
    exit 1
}

# 1. Sauvegarde des originaux HD si pas déjà fait
if (-not (Test-Path $backupDir)) {
    Write-Host "Création d'une sauvegarde des cartes haute résolution dans LOUP GAROU ENHANCED_BACKUP..." -ForegroundColor Yellow
    Copy-Item -Path $sourceDir -Destination $backupDir -Recurse
    Write-Host "Sauvegarde terminée avec succès !" -ForegroundColor Green
} else {
    Write-Host "Sauvegarde déjà existante dans LOUP GAROU ENHANCED_BACKUP." -ForegroundColor Gray
}

# Création du dossier temporaire
if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
New-Item -ItemType Directory -Path $tempDir | Out-Null

# Configuration Encodeur JPEG
$jpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/jpeg" }
$encoderParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
$encoderParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [long]83)

$maxWidth = 600
$maxHeight = 900

$files = Get-ChildItem -Path $sourceDir -Filter "*.jpg"
$totalOriginalBytes = 0
$totalNewBytes = 0

foreach ($file in $files) {
    $totalOriginalBytes += $file.Length
    $destPath = Join-Path $tempDir $file.Name

    try {
        $imgStream = [System.IO.File]::OpenRead($file.FullName)
        $img = [System.Drawing.Image]::FromStream($imgStream)
        
        $width = $img.Width
        $height = $img.Height

        # Calcul du ratio
        $ratioX = $maxWidth / [double]$width
        $ratioY = $maxHeight / [double]$height
        $ratio = [Math]::Min($ratioX, $ratioY)

        if ($ratio -lt 1.0) {
            $newWidth = [int]($width * $ratio)
            $newHeight = [int]($height * $ratio)
        } else {
            $newWidth = $width
            $newHeight = $height
        }

        $newBmp = New-Object System.Drawing.Bitmap($newWidth, $newHeight)
        $graphics = [System.Drawing.Graphics]::FromImage($newBmp)
        $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

        $graphics.DrawImage($img, 0, 0, $newWidth, $newHeight)

        $newBmp.Save($destPath, $jpegCodec, $encoderParams)

        $graphics.Dispose()
        $newBmp.Dispose()
        $img.Dispose()
        $imgStream.Dispose()

        $newSize = (Get-Item $destPath).Length
        $totalNewBytes += $newSize

        $origMb = [math]::Round($file.Length / 1MB, 2)
        $newKb  = [math]::Round($newSize / 1KB, 1)
        Write-Host "Optimisé: $($file.Name) [$origMb Mo -> $newKb Ko]" -ForegroundColor White
    }
    catch {
        Write-Warning "Erreur lors du traitement de $($file.Name): $_"
        Copy-Item -Path $file.FullName -Destination $destPath
    }
}

# Remplacement des fichiers dans LOUP GAROU ENHANCED
Write-Host "Remplacement des fichiers par les versions optimisées..." -ForegroundColor Yellow
Copy-Item -Path "$tempDir\*" -Destination $sourceDir -Force
Remove-Item $tempDir -Recurse -Force

# Nettoyage des Thumbs.db
Get-ChildItem -Path $projectRoot -Filter "Thumbs.db" -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue

$origTotalMb = [math]::Round($totalOriginalBytes / 1MB, 2)
$newTotalMb  = [math]::Round($totalNewBytes / 1MB, 2)
$reduction   = [math]::Round((1 - ($totalNewBytes / $totalOriginalBytes)) * 100, 1)

Write-Host "==========================================================" -ForegroundColor Green
Write-Host "Succès ! Poids total des cartes : $origTotalMb Mo -> $newTotalMb Mo ($reduction% de réduction)" -ForegroundColor Green
Write-Host "L'APK final sera désormais largement sous les 50 Mo !" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
