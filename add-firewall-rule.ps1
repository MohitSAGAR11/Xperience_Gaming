# XPerience Gaming - Firewall Rule Setup
# Run this script as Administrator to add permanent firewall rule

$ruleName = "XPerience Gaming Backend - Port 5000"

# Check if rule already exists
$existingRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue

if ($existingRule) {
    Write-Host "Firewall rule already exists. Removing old rule..." -ForegroundColor Yellow
    Remove-NetFirewallRule -DisplayName $ruleName
}

# Create new firewall rule
Write-Host "Creating firewall rule for port 5000..." -ForegroundColor Green
New-NetFirewallRule -DisplayName $ruleName `
    -Direction Inbound `
    -LocalPort 5000 `
    -Protocol TCP `
    -Action Allow `
    -Profile Domain,Private,Public `
    -Enabled True

Write-Host "✅ Firewall rule created successfully!" -ForegroundColor Green
Write-Host "Your backend server on port 5000 is now accessible from your phone." -ForegroundColor Green
Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
