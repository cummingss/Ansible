<#
    Function Name:  IsDomainController
	Date:			14-06-2016
    Author:         Simon Cummings (simon@cummingsit.com)   
    Purpose:        Checks if the TargetComputer is a member of a Domain
    Parameters:     
                    $TargetComputer    - Target Computer against which function to be executed
    Returns:        System Object containing
                        DC             - Boolean $true/$false
                        Domain         - Domain Name

#>
Function IsDomainController {
[CmdletBinding()]
PARAM (
    [Parameter(Mandatory=$false,HelpMessage="Target Computer",ValueFromPipeLine=$true)][string]$TargetComputer = $env:COMPUTERNAME
    )

    # Display Debug Message
    if ($global:debug) {write-host "Checking for: Domain Controller: " -ForegroundColor Yellow -NoNewline}

    # Check if TargetComputer is part of a domain via WMI quest
    $DomainRole = (Get-WmiObject Win32_ComputerSystem -ComputerName $TargetComputer).domainrole

    # Create object to be returned to caller to include Boolean True/False and Domain Name.
    $returnOjb = New-Object -TypeName System.Object

    # A domain current domain to return object.
    $returnOjb | add-member -membertype NoteProperty -name Domain -value $(Get-WmiObject Win32_ComputerSystem).domain

    if (($DomainRole -eq 4) -or ($DomainRole -eq 5)) {
        switch ($DomainRole) {
            4 { $DomainRole = "Backup Domain Controller"}
            5 { $DomainRole = "Primary Domain Controller"}
        }

        # Display Debug Message
        if ($global:debug) {write-host "Success.`r`n$TargetComputer is $DomainRole for the $($(Get-WmiObject Win32_ComputerSystem).domain) domain." -ForegroundColor Green}

        # Add to return object
        $returnOjb | add-member -membertype NoteProperty -name Type -value $DomainRole
        $returnOjb | add-member -membertype NoteProperty -name IsDC -value $true


    } else {

        # Display Debug Message
        if ($global:debug) {write-host "$TargetComputer is NOT currently a domain controller." -ForegroundColor Red}

        # Add to return object
        $returnOjb | add-member -membertype NoteProperty -name Type -value $null
        $returnOjb | add-member -membertype NoteProperty -name IsDC -value $false

    } # END: If

    # Exit function with return object.
    return $returnOjb 
    
    
    End {
        # Clean-up vairables.
        If ($DomainRole) {Remove-Variable DomainRole}
        If ($TargetComputer) {Remove-Variable TargetComputer}
        If ($result) {Remove-Variable result}
    } # END: Function End Processes

} # END: Function 
