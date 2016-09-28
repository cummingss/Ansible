$HostName = "PRDCUSE1001"
$DomainToJoin = "mldir.net"

if ($ENV:ComputerName -ne $HostName) {
	Rename-computer -newname $HostName
    restart-computer -Force
}

# Retrieve and validate a Password from console.
if (!$DomainCredentials) {
    $DomainCredentials = Get-Credential -username "$DomainToJoin\$env:username" -Message "Enter credentials required to join the computer to the $DomainToJoin domain."
}


# Install Windows Features
Install-WindowsFeature AD-Domain-Services,DNS,RSAT-DFS-Mgmt-Con,RSAT-DNS-Server -IncludeManagementTools

# Enable RPC Firewall Rule.
Enable-NetFirewallRule -DisplayName "COM+ Network Access (DCOM-In)"

# Import Powershelll Module
Import-Module ADDSDeployment

# Set NLA to disabled
(Get-WmiObject -class "Win32_TSGeneralSetting" -Namespace root\cimv2\terminalservices -ComputerName . -Filter "TerminalName='RDP-tcp'").SetUserAuthenticationRequired(0)

#Install Child Domain
Install-ADDSDomain `
-NoGlobalCatalog:$false `
-CreateDnsDelegation:$true `
-Credential (Get-Credential) `
-DatabasePath "C:\windows\NTDS" `
-DomainMode "Win2012R2" `
-DomainType "ChildDomain" `
-InstallDns:$true `
-LogPath "C:\windows\NTDS" `
-NewDomainName "prod" `
-NewDomainNetbiosName "PROD" `
-ParentDomainName "mldir.net" `
-NoRebootOnCompletion:$false `
-SiteName "us-east-1" `
-SysvolPath "C:\windows\SYSVOL" `
-Force:$true