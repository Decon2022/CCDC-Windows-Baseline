<#
Choose Server Core, (Server specific lateral movement and credential protection)
ENFORE LDAP Signing + Credential Guard +  Channel Binding, 
Enable SMB Signing , restrict local admin logon - LocalAccountTokenFilterPolicy 
Lock down RDP with Network LEvel Authenication + FIPS Encryption
disabele TLS 1.0/1.1 
Remove unnecessary 
#>


<# Since this is a server hosting Food service its gonna be IIS
Block local administrator accounts from authenticating over the network [LocalAccountTokenFilterPolicy = 0]
disable printe service (Spooler)
#>

#1. Enable LSARunAsPPL and Virutal-based security  
# Set RunAsPPL = 1 & LsaCfgFlags = 1 (HHKLM:\SYSTEM\CurrentControlSet\Control\LSA)


#2. SMB Relay Prevention Require SMB Packet Signing, both Server and Client
# RequireSecuirtySignature = $true & EncryptData = $true


# 3. Remote Management (RDP & WinRM) Enfore RDP NLA, High/FIPS Encryption and block Pass-The-Hash 
# UserAuthentication = 1, MinEnryptionLevel = 3, LocalAccountTokenFilterPolicy = 0 


# 4. Transport Cryptography (SCCHANNEL) 
# Disable SSL 2.0/ 3.0 & TLS 1.0/1.1 ; enforce TLS 1.2 / TLS 1.3

# 5. Role & Service Minimization
# Disable Powershell v2 Engine, Print Spooler, WPAD / WinHTTP 


