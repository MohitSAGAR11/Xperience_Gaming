# Run this script as Administrator to allow port 5000 through Windows Firewall

Write-Host "Adding Windows Firewall rule for Node.js Backend (Port 5000)..." -ForegroundColor Cyan

# Add inbound rule for TCP port 5000
New-NetFirewallRule -DisplayName "Node.js Backend Port 5000" `
    -Direction Inbound `
    -LocalPort 5000 `
    -Protocol TCP `
    -Action Allow `
    -Profile Any

Write-Host "✅ Firewall rule added successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Port 5000 is now accessible from your network." -ForegroundColor Green
Write-Host ""
Write-Host "Test from your phone's browser:" -ForegroundColor Yellow
Write-Host "http://10.10.4.37:5000/api/health" -ForegroundColor White

