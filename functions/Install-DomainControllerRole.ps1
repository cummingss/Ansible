<#
    Function Name:  Install-DomainControllerRole
    Author:         Simon Cummings (simon@cummingsit.com)   
    Purpose:        Install a New DC (Domain Controller).  There are options to install the new DC into the following scenarios:
						1.	First DC in a new Forest/Domain.
 						2.	First DC in new Child Domain
						3.	DC in exisiting Domain.
					
					Note: It is only possible to set the Functional Level of the Forest/Domain only when installing the first DC in a Domain or Forest.
						
    Parameters:     
                    TargetComputer    		- String - Target Computer against which function to be executed
					DomainName				- String - Name of new domain to be installed (Mandatory).
					SiteName				- String - Name of AD Site for Domain Controller.
					DomainMode		 		- String - Choose functional Domain Level for new Domain.
					ForestMode				- String - Choose functional Forest Level for new Forest.
					NewChild				- String - Create New Child Domain for Domain specified in $Domainname.
					InstallDNS				- Switch - If specified, install DNS. 
					NoGlobalCatalog			- Switch - If specified, Global Catalog role will not be installed.  By default GC will be installed. 
					CreateDNSDelegation 	- Switch - If specified, DNS Delegation will be installed.  By default DNS delegation will not installed. 
					CriticalReplicationOnly - Switch - If specified, Critial Only Replication will take place.  By default full replication is specified.
	Returns:        Boolean $true/$false

    Dependancies:   This script is dependant of the following additional functions/scripts.
					Add-ADSite
					Enable-AutoAdminLogon
					Get-ValidatedPassword
					Install-ADNewForest
					IsDomainController
					IsDomainJoined
					Write-ToLog
#>
Function Install-DomainControllerRole {
[CmdletBinding()]
PARAM (
    [Parameter(Mandatory=$false,HelpMessage="Hostname install Domain Contoller",ValueFromPipeLine=$true)][string]$TargetComputer = $ENV:ComputerName,
    [Parameter(Mandatory=$true,HelpMessage="Specify New Domain Name",ValueFromPipeLine=$true)]           [string]$DomainName,
    [Parameter(Mandatory=$false,HelpMessage="Specify New Site Name ",ValueFromPipeLine=$true)]           [string]$SiteName,
    [Parameter(Mandatory=$false,HelpMessage="Specify Domain Mode ",ValueFromPipeLine=$true)]             [string]$DomainMode ="Default",
    [Parameter(Mandatory=$false,HelpMessage="Specify Forest Mode ",ValueFromPipeLine=$true)]             [string]$ForestMode ="Default",
    [Parameter(Mandatory=$false,HelpMessage="Specify as New Forest ",ValueFromPipeLine=$true)]           [switch]$NewForest,
    [Parameter(Mandatory=$false,HelpMessage="Specify as New Child Domain ",ValueFromPipeLine=$true)]     [switch]$NewChild,
    [Parameter(Mandatory=$false,HelpMessage="Specify Install DNS",ValueFromPipeLine=$true)]              [switch]$InstallDNS,
    [Parameter(Mandatory=$false,HelpMessage="Specify Install Global Catalog",ValueFromPipeLine=$true)]   [switch]$NoGlobalCatalog=$false,
    [Parameter(Mandatory=$false,HelpMessage="Specify Create DNS Deleation",ValueFromPipeLine=$true)]     [switch]$CreateDNSDelegation=$false,
    [Parameter(Mandatory=$false,HelpMessage="Specify Critical Replication Only",ValueFromPipeLine=$true)][switch]$CriticalReplicationOnly=$false
    )

    process {

        # Get current Domain membership.
        If ($NewChild) {
            $DomainJoined = IsDomainJoined -DomainToCheck $ParentDomain
        } else {
            $DomainJoined = IsDomainJoined
        }

        # Check if IsDomainController
        $IsDomainController = IsDomainController

        # If not already a domain controller.
        If (!($IsDomainController.IsDC)) {

            # Get SafeMode Password
            if (!($SafeModeAdministratorPassword)) {
                $SafeModeAdministratorPassword = get-ValidatedPassword -Comment "Enter SafeModeAdministrator Password for Domain" #-ReturnAsString
            } else {
                $SafeModeAdministratorPassword = $SafeModeAdministratorPassword | ConvertTo-SecureString -AsPlainText -force
            }
        }

        # If Computer is a domain member, but the domain is NOT the same as the intended domain, 
        # and a New Child domain is not being created,  remove from current domain.
        IF ($DomainJoined.Member -and !($NewChild) -and !(($DomainJoined.Domain -eq $ForestName) -or ($DomainJoined.Domain -eq $DomainName) -or ($DomainJoined.Domain -eq "$DomainName.$ForestName"))) {

            # Write Log Entry
            Write-ToLog -LogFile $global:LogFile -LogText "Is Domain Member   :`t$($DomainJoined.Member)" -ForeGroundColour Yellow
            Write-ToLog -LogFile $global:LogFile -LogText "Is Domain Joined   :`t$($DomainJoined.domain)" -ForeGroundColour Yellow
            Write-ToLog -LogFile $global:LogFile -LogText "Is New Child Domain:`t$NewChild" -ForeGroundColour Yellow
            Write-ToLog -LogFile $global:LogFile -LogText "Destingation Forest:`t$ForestName" -ForeGroundColour Yellow
            Write-ToLog -LogFile $global:LogFile -LogText "Destingation Domain:`t$Domain" -ForeGroundColour Yellow
            

            Remove-FromDomain -Restart -AutoAdminLogon -DomainCredentials $global:DomainCredentials -LocalCredentials $global:LocalCredentials

        } # END If domain member check.

        #-----------------------------------------------
        # Install WindowsFeature AD-Domain-Services. 
        #-----------------------------------------------
        If (($(Get-WindowsFeature AD-Domain-Services).installState -ne "Installed")) {

            # Write Log Entry
            Write-ToLog -LogFile $global:LogFile -LogText "Installing Windows AD-Domain-Services Feature.  Please wait..." -ForeGroundColour Yellow

            Install-WindowsFeature AD-Domain-Services,RSAT-DNS-Server -IncludeManagementTools
            
        }
        
        #-----------------------------------------------
        # Check and Install/Remove DNS Server feature as required.
        #-----------------------------------------------
        If (!($InstallDNS) -and ($(Get-WindowsFeature DNS).installState -eq "Installed") -or ($(Get-WindowsFeature DNS).installState -eq "InstallPending")) {
        
            # Write Log Entry
            Write-ToLog -LogFile $global:LogFile -LogText "Removing Windows Feature DNS. Please wait..." -ForeGroundColour Yellow

            Remove-WindowsFeature DNS

            # Enabled AutoAdminLogon & restart
            Enable-AutoAdminLogon -Credential $global:LocalCredentials -AutoLogonCount 2 -Restart
            
        } elseIf (($(Get-WindowsFeature DNS).installState -ne "Installed") -and $InstallDNS) {
            Install-WindowsFeature DNS
            
        } # END: Check DNS Service.



        #----------------------------------------------------------------
        # START - Create New Forest
        #----------------------------------------------------------------
        # Create New Forest.  If Computer is not already a DC, and the request new forest does not already exist.
        If (!($($IsDomainController.IsDC)) -and ($NewForest) -and (!(IsForestExist -ForestName $ForestName))) {

                Install-ADNewForest -ForestName $ForestName -DomainMode $DomainMode -ForestMode $ForestMode -InstallDns:$InstallDNS

        }  # END: Create New Forest
        #----------------------------------------------------------------
        # END   - Create New Forest
        #----------------------------------------------------------------


        #----------------------------------------------------------------
        # Update default -first-site name for a newly created forest.
        #----------------------------------------------------------------
        If ($IsDomainController.IsDC -and ($NewForest) -and (IsForestExist -ForestName $ForestName)) {

            # Change Default-First-Site-Name if specified.
            Add-ADSite -SiteName $SiteName -AsDefaultFirstSite
        } # END: If Forest Exist (post install whilst configuring a new Forest)



        #----------------------------------------------------------------
        # START - Create New Child Domain
        #----------------------------------------------------------------

        #----------------------------------------------------------------
        # Check if IsDomainController
        #----------------------------------------------------------------
        $IsDomainController = IsDomainController

        #----------------------------------------------------------------
        # Add ADSite for Child Domain.
        #----------------------------------------------------------------
        if ($($IsDomainController.IsDC) -and $NewChild) {

            Add-ADSite -SiteName $SiteName

        }

        # Install Child Domain into existing Forest/Domain.
        if (!($($IsDomainController.IsDC)) -and $NewChild) {

            Install-ADChildDomain -DomainName $DomainName -ParentDomainName $ParentDomain -Credential $global:ParentCredentials -DomainMode $DomainMode -InstallDns:$InstallDNS -CreateDNSDelegation:$CreateDNSDelegation

        } # END: If Not New Child Domain


        #----------------------------------------------------------------
        # END   - Create New Child Domain
        #----------------------------------------------------------------
    

        #----------------------------------------------------------------
        # START - Create Domain controller for existing domain
        #----------------------------------------------------------------

        # Check if IsDomainController
        $IsDomainController = IsDomainController

        # Install Domain Controller in existing Forest.
        if (!($($IsDomainController.IsDC)) -and !($NewChild)) {

            # If Computer is a not a domain member, and the computer is to be a Domain DC, join the domain.
            If (!$($DomainJoined.Member)) {
                JoinDomain -DomainToJoin $DomainName -Restart -AutoAdminLogon -DomainCredentials $global:DomainCredentials
            }

            # Write Log Entry
            Write-ToLog -LogFile $global:LogFile -LogText "Installing Domain Controller for existing Domain ($DomainName) in AD Site: $SiteName. Please wait..." -Foregroundcolour Yellow
        
            # Import required Module.
            Add-AvailableModules -ModuleName ADDSDeployment
        

            # Check credentials.  Exit script if not valid.
            if (!(Test-ADAuthentication -Credential $global:DomainCredentials)) {
                write-host "Exiting script." -ForegroundColor Red
                exit
            }

            Try {
            
                # Display Debug Message
                if ($global:debug) {write-host "Installing Domain contoller for existing domain: $DomainName." -ForegroundColor Yellow}

                # Install as Domain Controller of existing domain.
                Install-ADDSDomainController -DomainName $DomainName -SafeModeAdministratorPassword $SafeModeAdministratorPassword `
                    -SiteName $SiteName -InstallDNS:$InstallDNS -NoGlobalCatalog:$NoGlobalCatalog -CreateDNSDelegation:$CreateDNSDelegation            `
                    -CriticalReplicationOnly:$CriticalReplicationOnly -NoRebootOnCompletion  -Force -Credential $global:DomainCredentials 

                # Write Log Entry
                Write-ToLog -LogFile $global:LogFile -LogText "Successfully installed Domain Controller in existing Domain ($DomainName)." -Foregroundcolour Green

                # Enabled AutoAdminLogon & restart
                Enable-AutoAdminLogon -Credential $global:DomainCredentials -AutoLogonCount 2 -Restart

            } catch {
            
                # Write Log Entry
                Write-ToLog -LogFile $global:LogFile -LogText "Failed to install Domain Controller.`r`n$Error" -Foregroundcolour Red
            } # END: Try/Catch

        } # END: If Not Domain Controller, install as DC.

        # Add ADSite for Existing Domain.
        if ($($IsDomainController.IsDC) -and !($NewChild)) {
            
            Add-ADSite -SiteName $SiteName
        }
        #----------------------------------------------------------------
        # END   - Create Domain controller for existing domain
        #----------------------------------------------------------------


        # Configure Generic Features
    
        #----------------------------------------------------------------
        # Disable LMHosts Name Resolution
        #----------------------------------------------------------------
        Disable-LMHostNameResolution


        #----------------------------------------------------------------
        # Add IP Address range as Subnet in Specified Site.
        #----------------------------------------------------------------
        # Get current IP Address.
        $IpEnabledNIC = Get-WmiObject win32_networkadapterconfiguration -Filter "ipenabled ='true'"

        Foreach ($item in $IpEnabledNIC[0]) {
            # Check for IPv4 Address and replace.
            If ($item.indexof(".") -gt 0 ) {
                $IP_Address = $item
                $IP_NetMask = $IpEnabledNIC.ipsubnet
            } # END: If
        } # END: For Each


        #----------------------------------------------------------------
        # Add IP Subnet to AD Site
        #----------------------------------------------------------------
        Add-SubnetToADSite -IPAddress (Get-NetworkAddress -IPAddress $IP_Address -SubNetMask $IP_NetMask) -SubNetMask $IP_NetMask -SiteName $SiteName -Description "$DomainName.$ForestName Domain Controllers"

        #----------------------------------------------------------------
        # Move Domain Controller to Site
        #----------------------------------------------------------------
        $cnc = (Get-ADRootDSE).ConfigurationNamingContext
        Try {
            Move-ADDirectoryServer -Identity $TargetComputer -site "CN=$SiteName,CN=Sites,$cnc"

            # Write Log Entry
            If ($global:LogFile) {Write-ToLog -LogFile $global:LogFile -LogText "Successfully moved to AD Site: $SiteName." -Foregroundcolour Green}
        } catch {
            # Write Log Entry
            If ($global:LogFile) {Write-ToLog -LogFile $global:LogFile -LogText "Failed to move to AD Site: $SiteName." -Foregroundcolour Red}
        }
        
        #----------------------------------------------------------------
        # Create AD Site Link Site
        #----------------------------------------------------------------
        If ($DomainName -ne $ForestName) {
            Try {
                Add-ADSiteLink -SiteLink "UK-SWN - $SiteName" -SitesIncluded "UK-SWN",$SiteName -LinkCost 100 -ReplFreq 60 -ErrorAction silentlycontinue
                # Write Log Entry
                If ($global:LogFile) {Write-ToLog -LogFile $global:LogFile -LogText "Successfully created AD Site Link: $SiteName." -Foregroundcolour Green}
            } catch {
                # Write Log Entry
                If ($global:LogFile) {Write-ToLog -LogFile $global:LogFile -LogText "Failed to create AD Site Site Link: UK-SWN - $SiteName." -Foregroundcolour Red}
            }
        } # END If NOT New Forest

        #----------------------------------------------------------------
        # Force full Active Directory replication following install.
        #----------------------------------------------------------------
        If (!($NewForest)) {
            Try {
                if ($ParentDomain -eq $Domain) {
                    $repdomain = $domain
                    repadmin /syncall "$repdomain"
                } else {
                    $repdomain = "$domain.$ParentDomain"
                    repadmin /syncall "$repdomain"
                }

                # Write Log Entry
                If ($global:LogFile) {Write-ToLog -LogFile $global:LogFile -LogText "Forced Replication Sync for Domain: $repdomain. " -Foregroundcolour Green}
    
                $ADReplErrors = ConvertFrom-Csv -InputObject (repadmin.exe /showrepl * /csv) | where {$_.showrepl_columns -ne 'showrepl_INFO'}
            } catch {

                # Write Log Entry
                If ($global:LogFile) {Write-ToLog -LogFile $global:LogFile -LogText "Failed to forced Replication Sync for Domain: $repdomain. " -Foregroundcolour Red}
                exit
            }
        } # END If NOT New Forest

        #----------------------------------------------------------------
        # Enable Add AD RSAT Tools
        #----------------------------------------------------------------
        Try {
            Add-WindowsFeature RSAT-AD-Tools -IncludeAllSubFeature

            # Write Log Entry
            If ($global:LogFile) {Write-ToLog -LogFile $global:LogFile -LogText "Installed RSAT Tools for Active Directory. " -Foregroundcolour Green}
        } catch {

            # Write Log Entry
            If ($global:LogFile) {Write-ToLog -LogFile $global:LogFile -LogText "Failed to install RSAT Tools for Active Directory.`r`n$Error" -Foregroundcolour Red}

        } # END: Try/Catch


        #----------------------------------------------------------------
        # Enable AD Recycle Bin.
        #----------------------------------------------------------------
        Try {

            Get-ADOptionalFeature "Recycle Bin Feature"

            # Write Log Entry
            If ($global:LogFile) {Write-ToLog -LogFile $global:LogFile -LogText "Recycle Bin Feature already enabled." -Foregroundcolour Green}

        } catch {

            Try {

                Enable-ADOptionalFeature "Recycle Bin Feature" -scope Forest -target $ForestName -confirm:$false

                # Write Log Entry
                If ($global:LogFile) {Write-ToLog -LogFile $global:LogFile -LogText "Enabled AD Recycle Bin." -Foregroundcolour Green}

            } catch {

                # Write Log Entry
                If ($global:LogFile) {Write-ToLog -LogFile $global:LogFile -LogText "Failed to Enable AD Recycle Bin.`r`n$Error" -Foregroundcolour Red}

            } # END: Try/Catch
        } # END: Try/Catch    


        #----------------------------------------------------------------
        # Enable RDP for server.
        #----------------------------------------------------------------
        If ((Get-CimInstance "Win32_TerminalServiceSetting" -Namespace root\cimv2\terminalservices).AllowTSConnections -ne 1) {

            Try {
                Get-CimInstance "Win32_TerminalServiceSetting" -Namespace root\cimv2\terminalservices | Invoke-CimMethod -MethodName setallowtsconnections -Arguments @{AllowTSConnections = 1; ModifyFirewallException = 1} | out-null
       
                # Write Log Entry
                If ($global:LogFile) {Write-ToLog -LogFile $global:LogFile -LogText "Enabled RDP connectivity." -Foregroundcolour Green}
            } catch {

                # Write Log Entry
                If ($global:LogFile) {Write-ToLog -LogFile $global:LogFile -LogText "Failed to Enable Remote Desktop.`r`n$Error" -Foregroundcolour Red}
        
            } # END: Try/Catch

        } else {

            # Display Debug Message
            if ($global:debug) {write-host "RDP connectivity already enabled." -ForegroundColor Yellow}

        }# END: If - Enable RDP

        #----------------------------------------------------------------
        # Enable user authentication over RDP-Tcp for RDP
        #----------------------------------------------------------------
        If ((Get-CimInstance "Win32_TSGeneralSetting" -Namespace root\cimv2\terminalservices -filter 'TerminalName = "RDP-Tcp"').UserAuthenticationRequired -ne 1) {
            
            try {
                Get-CimInstance "Win32_TSGeneralSetting" -Namespace root\cimv2\terminalservices -filter 'TerminalName = "RDP-Tcp"' | Invoke-CimMethod -MethodName SetUserAuthenticationRequired -Arguments @{UserAuthenticationRequired = 1} | out-null

                # Write Log Entry
                If ($global:LogFile) {Write-ToLog -LogFile $global:LogFile -LogText "Force user authentication over RDP-Tcp." -Foregroundcolour Green}

            } catch {

                # Write Log Entry
                If ($global:LogFile) {Write-ToLog -LogFile $global:LogFile -LogText "Failed to force user authentication over RDP-Tcp.`r`n$Error" -Foregroundcolour Red}
        
            } # END: Try/Catch

        } else {

            # Display Debug Message
            if ($global:debug) {write-host "Forced user authentication over RDP-Tcp connectivity already enabled." -ForegroundColor Yellow}

        }# END: If - Enable user authentication over RDP-Tcp for RDP

        #----------------------------------------------------------------
        # Remove uneccessary Windows Feature installation source (Hardening process).
        #----------------------------------------------------------------
        IF (Get-WindowsFeature | ?{$_.installstate -eq "Available"}) {
            Try {
                Get-WindowsFeature | ?{$_.installstate -eq "Available"} | Remove-WindowsFeature -Remove
       
                # Write Log Entry
                If ($global:LogFile) {Write-ToLog -LogFile $global:LogFile -LogText "Removed non required Windows Feature source files." -Foregroundcolour Green}
            } catch {

                # Write Log Entry
                If ($global:LogFile) {Write-ToLog -LogFile $global:LogFile -LogText "Failed to removed non required Windows Feature source files.`r`n$Error" -Foregroundcolour Red}
        
            } # END: Try/Catch
        } else {

            # Display Debug Message
            if ($global:debug) {write-host "Source files for non required Windows Feature already removed." -ForegroundColor Yellow}

        } # END: If

            
        #----------------------------------------------------------------
        # Enable Strict Replication Consistency checking
        #----------------------------------------------------------------
        IF (!(test-path "AD:CN=94fdebc6-8eeb-4640-80de-ec52b9ca17fa,CN=Operations,CN=ForestUpdates,CN=Configuration,$((Get-ADDomain).DistinguishedName)")) {
            Try {
                $cnc    = (Get-ADRootDSE).configurationnamingcontext
                $ADpath = "CN=Operations,CN=ForestUpdates," + $cnc
                $obj    = "94fdebc6-8eeb-4640-80de-ec52b9ca17fa"
                New-ADObject -Name $obj -Type container -path $ADpath -OtherAttributes @{showInAdvancedViewOnly="TRUE"}
                # Write Log Entry
                If ($global:LogFile) {Write-ToLog -LogFile $global:LogFile -LogText "Enabled Strict Replication Consistency checking." -Foregroundcolour Green}
            } catch {

                # Write Log Entry
                If ($global:LogFile) {Write-ToLog -LogFile $global:LogFile -LogText "Failed to enabled Strict Replication Consistency checking.`r`n$Error" -Foregroundcolour Red}
        
            } # END: Try/Catch

        } # END: If Strict Replication Consistency checking.

        #----------------------------------------------------------------
        # Remove Server GUI for minimal interface.
        #----------------------------------------------------------------
        IF (Get-WindowsFeature Server-Gui-Shell | ?{$_.installstate -eq "Installed"}) {
            Remove-WindowsFeature Server-Gui-Shell
        }

    } # END: Process

<#
    -------------------------------------
    #       Function Exit process.
    -------------------------------------
#>
    End {
        # Clean up variables.
        Remove-Variable TargetComputer
    } # END: Function End process
} # END: Function
