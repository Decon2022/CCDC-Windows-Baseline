# Run as Administrator in PowerShell:
#   powershell -ExecutionPolicy Bypass -File .\baseline.ps1


if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole('Administrator')) { Write-Error "Run as Administrator"; exit 1 }

# Timestamp of script
$out = "C:\Baseline_$($env:COMPUTERNAME)_$(Get-Date -Format 'yyyyMMdd_HHmm')"
New-Item -ItemType Directory -Path $out -Force | Out-Null

# System info
systeminfo                                        > "$out\systeminfo.txt"
ipconfig /all                                     > "$out\ipconfig.txt"

# Users and groups
Get-LocalUser | Select-Object Name, Enabled, LastLogon     | Out-File "$out\users.txt"
Get-LocalGroupMember Administrators                        | Out-File "$out\admins.txt"
net localgroup                                    > "$out\groups.txt"

# Services and processes
Get-CimInstance Win32_Service | Sort-Object State,Name | Select-Object Name,DisplayName,State,StartMode,StartName,PathName | Format-Table -AutoSize | Out-File "$out\services.txt" -Width 500
Get-Process | Sort-Object Name | Select-Object Id,Name,Path     | Out-File "$out\processes.txt" -Width 250

# Network
netstat -ano                                      > "$out\netstat.txt"
Get-NetTCPConnection -State Listen | Sort-Object LocalPort | Select-Object LocalAddress,LocalPort,OwningProcess | Out-File "$out\listening_ports.txt"
Get-NetFirewallProfile | Select-Object Name,Enabled      | Out-File "$out\firewall_profiles.txt"
net share                                         > "$out\shares.txt"

# Scheduled tasks and startup items
Get-ScheduledTask | Where-Object State -ne 'Disabled' | Select-Object TaskPath,TaskName,State | Out-File "$out\scheduled_tasks.txt" -Width 250
Get-CimInstance Win32_StartupCommand | Select-Object Name,Command,Location | Out-File "$out\startup.txt" -Width 250
reg query HKLM\Software\Microsoft\Windows\CurrentVersion\Run > "$out\run_keys.txt"
reg query HKCU\Software\Microsoft\Windows\CurrentVersion\Run >> "$out\run_keys.txt"

# Installed software and patches
Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*, HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* |
    Where-Object DisplayName | Select-Object DisplayName,DisplayVersion | Sort-Object DisplayName | Out-File "$out\software.txt" -Width 250
Get-HotFix | Select-Object HotFixID,InstalledOn          | Out-File "$out\hotfixes.txt"

# Installed roles (works on Windows Server only)
Get-WindowsFeature -ErrorAction SilentlyContinue | Where-Object Installed | Out-File "$out\roles.txt"

Write-Host "Done. Baseline saved to $out"