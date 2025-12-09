# Test script to verify backend connectivity

Write-Host "🔍 Testing Backend Connection..." -ForegroundColor Cyan
Write-Host ""

# 1. Check if backend is running on port 5000
Write-Host "1. Checking if port 5000 is listening..." -ForegroundColor Yellow
$listening = netstat -ano | Select-String ":5000" | Select-String "LISTENING"
if ($listening) {
    Write-Host "   ✅ Port 5000 is listening" -ForegroundColor Green
    Write-Host "   $listening" -ForegroundColor Gray
} else {
    Write-Host "   ❌ Port 5000 is NOT listening" -ForegroundColor Red
    Write-Host "   Make sure backend is running: npm run dev" -ForegroundColor Yellow
}
Write-Host ""

# 2. Check firewall rule
Write-Host "2. Checking firewall rules for port 5000..." -ForegroundColor Yellow
$firewallRule = Get-NetFirewallRule | Where-Object {$_.DisplayName -like "*5000*" -and $_.Enabled -eq $true}
if ($firewallRule) {
    Write-Host "   ✅ Firewall rule exists and is enabled" -ForegroundColor Green
    $firewallRule | ForEach-Object { Write-Host "   - $($_.DisplayName)" -ForegroundColor Gray }
} else {
    Write-Host "   ❌ No firewall rule found for port 5000" -ForegroundColor Red
    Write-Host "   Run: .\add-firewall-rule.ps1 as Administrator" -ForegroundColor Yellow
}
Write-Host ""

# 3. Get local IP address
Write-Host "3. Your PC's IP address:" -ForegroundColor Yellow
$ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.InterfaceAlias -notlike "*Loopback*" -and $_.IPAddress -notlike "169.254.*"}).IPAddress
Write-Host "   $ip" -ForegroundColor Cyan
Write-Host ""

# 4. Test localhost connection
Write-Host "4. Testing localhost connection..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "http://localhost:5000/api/health" -Method Get -TimeoutSec 5
    Write-Host "   ✅ Localhost connection successful" -ForegroundColor Green
    Write-Host "   Response: $($response.message)" -ForegroundColor Gray
} catch {
    Write-Host "   ❌ Localhost connection failed" -ForegroundColor Red
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Gray
}
Write-Host ""

# 5. Test IP address connection
Write-Host "5. Testing IP address connection..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "http://${ip}:5000/api/health" -Method Get -TimeoutSec 5
    Write-Host "   ✅ IP address connection successful" -ForegroundColor Green
    Write-Host "   Response: $($response.message)" -ForegroundColor Gray
} catch {
    Write-Host "   ❌ IP address connection failed" -ForegroundColor Red
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Gray
}
Write-Host ""

# Summary
Write-Host "📱 Test from your phone's browser:" -ForegroundColor Cyan
Write-Host "   http://${ip}:5000/api/health" -ForegroundColor White
Write-Host ""
Write-Host "📝 Update Flutter app if IP changed:" -ForegroundColor Cyan
Write-Host "   File: frontend/lib/config/constants.dart" -ForegroundColor White
Write-Host "   baseUrl: 'http://${ip}:5000/api'" -ForegroundColor White

