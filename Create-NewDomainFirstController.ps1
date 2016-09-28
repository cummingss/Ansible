$HostName = "MLDCUSE1001"
$DomainToJoin = "mldir.net"

if (!$SafeModeAdministratorPassword) {
	$SafeModeAdministratorPassword = (Get-Credential -Message "Enter credentials required for SafeModeAdministratorPassword (DSRM).")
}

# Install Windows Features
Install-WindowsFeature AD-Domain-Services,DNS,RSAT-DFS-Mgmt-Con,RSAT-DNS-Server -IncludeManagementTools

# Enable RPC Firewall Rule.
Enable-NetFirewallRule -DisplayName "COM+ Network Access (DCOM-In)"

# Rename Computer
if ($ENV:ComputerName -ne $HostName) {
	Rename-computer -newname $HostName
    restart-computer -Force
}

# Import Powershelll Module
Import-Module ADDSDeployment

# Install New Forest
Install-ADDSForest `
-CreateDnsDelegation:$false `
-DatabasePath "C:\windows\NTDS" `
-DomainMode "Win2012R2" `
-DomainName "mldir.net" `
-DomainNetbiosName "MLDIR" `
-ForestMode "Win2012R2" `
-InstallDns:$true `
-LogPath "C:\windows\NTDS" `
-NoRebootOnCompletion:$false `
-SysvolPath "C:\windows\SYSVOL" `
-Force:$true


