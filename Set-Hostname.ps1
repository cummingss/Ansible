<#
    Function Name:  Set-Hostname
    Author:         Simon Cummings (simon@cummingsit.com)   
    Purpose:        Changes a Windows Computername for a target computer.
    Parameters:
                    $TargetComputer    - Target Computer against which function to be executed
                    $NewHostName       - New ComputerName for TargetComputer
    Returns:        Boolean 
                        $true          - If change is successful, of name already changed.
                        $false         - if there was and error or something else
#>
Function Set-Hostname {
[CmdletBinding()]
PARAM (
    [Parameter(Mandatory=$false,HelpMessage="Target Computer",ValueFromPipeLine=$true)][string]$TargetComputer = $env:COMPUTERNAME,
    [Parameter(Mandatory=$false,HelpMessage="New Host Name",ValueFromPipeLine=$true)][string]$NewHostName,
    [Parameter(Mandatory=$true,HelpMessage="Specify Local Credentials",ValueFromPipeLine=$true)][System.Management.Automation.PSCredential]$LocalCredentials
    )


    # Check name Length meets requirments.
    if ($NewHostName.Length -gt 15) {
            
            # Write Log Entry
            If ($global:LogFile) {Write-ToLog -LogFile $global:LogFile -LogText "FAILED.  New hostname is too long. $($NewHostName.Length) Characters.  Exiting Script." -ForeGroundColour Red}
            exit

    } # END If

    # Create new Computer object
    $oComputer = Get-WmiObject  win32_computersystem -ComputerName $TargetComputer -EnableAllPrivileges -Authentication 6

    # Checking hostname against requirement
    If ($($oComputer.Name) -ne $NewHostName) {


        # Write Log Entry
        If ($global:LogFile) {Write-ToLog -LogFile $global:LogFile -LogText "Renaming host:`t$NewHostName" -ForeGroundColour Yellow}

        Try {
            $oComputer.rename($NewHostName) | out-null

            # Write Log Entry
            If ($global:LogFile) {Write-ToLog -LogFile $global:LogFile -LogText "Hostname changed." -ForeGroundColour Green}

            # Enable Enable-AutoAdminLogon
            Enable-AutoAdminLogon -Credential $LocalCredentials -AutoLogonCount 2
            
            # Write Log Entry
            If ($global:LogFile) {Write-ToLog -LogFile $global:LogFile -LogText "The computer will now restart." -Foregroundcolour Green}

            Restart-Computer -ComputerName $TargetComputer -Force

            sleep 5

        } catch {

            # Write Log Entry
            If ($global:LogFile) {Write-ToLog -LogFile $global:LogFile -LogText "FAILED.  Unable to rename this computer.`r`n$Error" -ForeGroundColour Red}
            
            return $false
        } # END: Try/Catch

    } # END: If
} # END: Function 
