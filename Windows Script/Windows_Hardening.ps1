# This script will go over object that is neccesary for Windows Hardening 

<# TODO:// 
Check Windows Hardening Checklist (cybersecurity101.net)
    Test case each set of instrution
    1. Enforce NTLMv2 Only & Refuse LM/NTLMv1 
    2. Disable Anonymous Enumeration of SAM Accounts and Shares
    3. Disable autorun / Autoplay on all drives
    4. Account password lenght (14 chars) & lockout threshold 3 attempts
    5. Event log minimum size (Security >=1 gb, Application/System >= 32MB)
    6. Comand Line process Audit 

#>

try {
    if (-not ([Security.Principal.WindowsPrincipal][Secuirty.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Secuirity.Principal.WindowsBuiltInRole]::Administrator){
        Write-Host "LOL: You thought, you had access :)"-ForegroundColor Red
        return 

    }

    #0. Change Local Admin Password
    Set-LocalUser -Name "Administrator" -Password (Read-Host -AsSecureString "Enter new password")

    # Run as Administrator
    # 1. Enable Windows Firewall acrross all profile 
    Set-NetFirewallProfile -Profile Domain, Public, Private -Enabled True

    # 2. Disable SMBv1 (Legacy protocol mitigation) 
    Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart -ErrorAction SilentlyContinue 

    # 3. Disable LLMNR ( Mitigates local name resolution poisoning )
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" -Force | Out-Null
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" -Name "EnableMultcast" -Value 0 -Type DWord

    # 4. Disable WDigest Cleartext Credential Caching 
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest" -Name "UseLogonCredential" -Value 0 -Type DWord

    # 5. Enable PowerShell Script Block Logging ( Event ID 4104 )
    $PSLogPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Powershell\ScriptBlockLogging"
    New-Item -Path $PSLogPath -Force | Out-Null
    Set-ItemProperty -Path $PSLogPath -Name "EnableScriptBlockLogging" -Value 1 -Type DWord

    # 6. Enable Command-Line Process Auditing (Event ID 4688)
    <# Logs every program executed on the system 
    PS:  This might be too resource heavy
    #>
    auditpol.exe /set /subcategory:"Process Creation" /success:enable /failure:enable | Out-Null
    $AuditPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit"
    New-Item -Path $AuditPath -Force | Out-Null
    Set-ItemProperty -Path $AuditPath -Name "ProcessCreationIncludeCmdLine_Enabled" -Value 1 -Type DWord

    # 7. Disable Build-in Guest Account 
    Disable-LocalUser -Name "Guest" -ErrorAction SilentlyContinue

    Write-Host "[+] Core hardening baseline appiled. " -ForegroundColor Green



}
catch {
    Write-Error "Opps Try Again :)"
    Exit 1
}


