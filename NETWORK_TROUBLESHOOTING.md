# 🔧 Network Connection Troubleshooting

## 🐛 Error: "No route to host" - Backend Connection Failed

### Problem
The app cannot connect to the backend server at `http://10.10.4.50:5000/api`

### Common Causes
1. **IP Address Changed** - Your PC's IP address changed (DHCP)
2. **Backend Not Running** - Server is not started
3. **Network Changed** - Connected to different WiFi/network
4. **Firewall Blocking** - Windows Firewall blocking port 5000

---

## ✅ Quick Fix Steps

### Step 1: Check if Backend is Running

Open a terminal and check if the backend server is running:

```bash
cd backend
npm start
# OR
node server.js
```

You should see:
```
Server running on port 5000
✅ Firebase Admin SDK initialized successfully
```

### Step 2: Get Your Current IP Address

**Windows:**
```bash
ipconfig
```

Look for **IPv4 Address** under your active network adapter (Wi-Fi or Ethernet):
```
Wireless LAN adapter Wi-Fi:
   IPv4 Address. . . . . . . . . . . : 192.168.1.100  ← This is your IP
```

**Common IP ranges:**
- `192.168.x.x` - Home/Office WiFi
- `10.0.x.x` - Some networks
- `10.10.x.x` - Your previous IP (may have changed)

### Step 3: Update baseUrl in constants.dart

1. Open `frontend/lib/config/constants.dart`
2. Find line 16:
   ```dart
   static const String baseUrl = 'http://10.10.4.50:5000/api';
   ```
3. Replace `10.10.4.50` with your **current IP address**:
   ```dart
   static const String baseUrl = 'http://192.168.1.100:5000/api';  // Use YOUR IP
   ```
4. Save the file
5. **Hot restart** the app (not just hot reload):
   ```bash
   # Press 'R' in Flutter terminal, or
   flutter run
   ```

### Step 4: Verify Connection

Test if you can reach the backend from your device:

**From your phone/device browser:**
```
http://YOUR_IP:5000/api/health
# OR
http://YOUR_IP:5000/api/cafes
```

If you get a response, the connection works!

---

## 🔍 Detailed Troubleshooting

### Check 1: Backend Server Status

**Is the backend running?**
```bash
cd backend
# Check if server is running
# If not, start it:
npm start
```

**Check if port 5000 is in use:**
```bash
netstat -ano | findstr :5000
```

### Check 2: Firewall Settings

Windows Firewall might be blocking port 5000.

**Allow port 5000:**
1. Open **Windows Defender Firewall**
2. Click **Advanced settings**
3. Click **Inbound Rules** → **New Rule**
4. Select **Port** → **Next**
5. Select **TCP** → Enter port **5000** → **Next**
6. Select **Allow the connection** → **Next**
7. Check all profiles → **Next**
8. Name it "Backend API" → **Finish**

### Check 3: Network Configuration

**Are you on the same network?**
- Phone and PC must be on the **same WiFi network**
- If using mobile data, it won't work (use WiFi)

**Check network adapter:**
```bash
ipconfig /all
```
Look for the adapter that's **connected** and has an IP address.

### Check 4: Test Connection Manually

**From your PC (should work):**
```bash
curl http://localhost:5000/api/health
# OR
curl http://127.0.0.1:5000/api/health
```

**From your phone browser:**
```
http://YOUR_PC_IP:5000/api/health
```

If PC works but phone doesn't → Network/Firewall issue
If both don't work → Backend not running

---

## 📱 Device-Specific Configuration

### Android Emulator
Use: `http://10.0.2.2:5000/api`
```dart
static const String baseUrl = 'http://10.0.2.2:5000/api';
```

### iOS Simulator
Use: `http://localhost:5000/api`
```dart
static const String baseUrl = 'http://localhost:5000/api';
```

### Physical Device (Android/iOS)
Use: `http://YOUR_PC_IP:5000/api`
```dart
static const String baseUrl = 'http://192.168.1.100:5000/api';  // Your PC's IP
```

---

## 🔄 Quick IP Update Script

**Windows PowerShell:**
```powershell
# Get your IP
$ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.InterfaceAlias -like "*Wi-Fi*" -or $_.InterfaceAlias -like "*Ethernet*"}).IPAddress
Write-Host "Your IP: $ip"
Write-Host "Update baseUrl to: http://$ip:5000/api"
```

---

## ✅ Verification Checklist

- [ ] Backend server is running (`npm start` in backend folder)
- [ ] Got current IP address (`ipconfig`)
- [ ] Updated `baseUrl` in `constants.dart` with current IP
- [ ] Hot restarted the app (not just hot reload)
- [ ] Phone and PC on same WiFi network
- [ ] Firewall allows port 5000
- [ ] Can access `http://YOUR_IP:5000/api/health` from phone browser

---

## 🚀 After Fixing

Once you update the IP and restart:

1. **Google Sign-In should work** ✅
2. **All API calls should work** ✅
3. **No more "No route to host" errors** ✅

---

## 💡 Pro Tips

### Make IP Static (Optional)
To avoid IP changes:
1. Go to **Network Settings**
2. Set your IP to **static** instead of DHCP
3. Use the same IP every time

### Use ngrok for Testing (Alternative)
If IP keeps changing, use ngrok:
```bash
# Install ngrok
# Run backend on localhost:5000
ngrok http 5000
# Use the ngrok URL in baseUrl
```

---

## 🆘 Still Not Working?

1. **Check backend logs** - Are requests reaching the server?
2. **Check device logs** - Any other errors?
3. **Try different network** - Switch WiFi networks
4. **Restart everything** - PC, phone, router
5. **Use emulator** - Test with Android emulator first

---

**Last Updated:** [Current Date]
**Related Files:**
- `frontend/lib/config/constants.dart` (line 16)

