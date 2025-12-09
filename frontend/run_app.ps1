# Flutter App Run Script
# Run this from the frontend directory

Write-Host "🎮 XPerience Gaming - Starting App..." -ForegroundColor Cyan
Write-Host ""

# Check if emulator is running
Write-Host "📱 Checking for connected devices..." -ForegroundColor Yellow
flutter devices

Write-Host ""
Write-Host "🚀 Launching app on emulator..." -ForegroundColor Green
Write-Host ""

# Run the app
flutter run

# Note: While app is running:
# - Press 'r' for hot reload
# - Press 'R' for hot restart  
# - Press 'q' to quit

