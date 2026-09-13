Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "  Compilation Lupus Arena - Release APK (Android) " -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Cyan

# Nettoyage automatique des anciens processus Java pour liberer les ports reseau
Get-Process java,dart -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 800

Write-Host "`n[1/2] Mise a jour des dependances (flutter pub get)..." -ForegroundColor Yellow
flutter pub get

Write-Host "`n[2/2] Compilation de l'APK Release compatible avec votre SDK et Windows..." -ForegroundColor Yellow
flutter build apk --release --target-platform android-arm --no-tree-shake-icons --android-skip-build-dependency-validation

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n=================================================" -ForegroundColor Green
    Write-Host "  SUCCES : APK GENERE AVEC SUCCES !" -ForegroundColor Green
    Write-Host "  Fichier : build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor White
    Write-Host "=================================================" -ForegroundColor Green
} else {
    Write-Host "`n[!] La compilation a rencontre une erreur." -ForegroundColor Red
}
