# Run as Administrator in PowerShell:
#   powershell -ExecutionPolicy Bypass -File .\baseline.ps1


# Create file timestamp of baseline 
$outFile  = "C:\Baselines\$($env:COMPUTERNAME)_$(Get-Date -Format 'yyyyMMdd_HHmm')"
New-Item -ItemType Directory -Path $out -Force | Out-Null

# 1 Get System and OS Info
Get-ComputerInfo | Select-Object CsName, OsName, OSBuildType, WindowsVersion, OSUptime
    Export-Csv '$outFile\01_SystemInfo.csv' -NoTypeInformation 

# 2 Local Admin and Users
Get-LocalGroupMember -Group "Administrators" | Select-Object Name, PrincipalSource, ObjectClass | 
    Export-Csv '$outFile\02_LocalAdmins.csv' -NoTypeInformation

# 3. Running Process with File Paths and Hashes
# Get Process -> Export as CSV 
Get-Process | Where-Object { $_.Path } | ForEach-Object {
    [PSCustomObject]@{
        Id = $_.Id
        Name = $_.ProcessName
        Path = $_.Path
        SHA256 = (Get-FileHash $_.Path -Algorithm SHA256 -ErrorAction SilentlyContinue).Hash
    }
} | Export-Csv '$outDir\03_Processes.csv' -NoTypeInformation 

# 4. Service & Binary Paths 
Get-CimInstance Win32_Service | Select-Object Name, DisplayName, State, StartMode, PathName, StartName |
    Export-Csv "$outfile\04_Sercices.csv" -NoTypeInformation

# 5. Listen & Establish Network Connections
# Get TCP Connection -> Export to csv
Get-NetTCPConnection | Where-Object { $_.State -in @('Listen', 'Establish') } | 
    Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort , State, OwningProcess | 
    Export-Csv "$outFile\05_NetworkTCP.csv" -NoTypeInformation


# 6. Non-Microsoft Scheduled Task 
# Get Non-Microsoft Relative Task -> Export as csv
Get-ScheduledTask | Where-Object { $_.Author -notmatch 'Microsoft' -and $_.State -ne 'Disabled' } |
    Select-Object TaskName, TaskPath, State, Author | 
    Export-Csv "$outFile\06_ScheduledTasks.csv" -NoTypeInformation

# 7. Autorun Registry Keys
# Get Registry Key from Current User and Local Machine -> Export as Text file 
Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
                       "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -ErrorAction SilentlyContinue | 
            Out-File "$outFile\07_Autoruns.txt"


