<#
    Function Name:  Get-ValidatedPassword
	Date:			14-06-2016
    Author:         Simon Cummings (simon@cummingsit.com)   
    Purpose:        Prompts user for a password with confirmation.
	
    Parameters:     $Comment           - Prompt displayed to user.
                    $ReturnAsString    - Return the password as a plain text string, if required.  Default is secured-string

    Returns:        Returns Plain text or secured-string password validated.

    Dependancies:   ConvertFrom-SecureToPlain
#>
function get-ValidatedPassword {
    [CmdletBinding()]
    param(
    [Parameter(Mandatory=$false, ValueFromPipeline=$True)][string] $Comment,
    [Parameter(Mandatory=$false, ValueFromPipeline=$True)][switch] $ReturnAsString
    )

    # Retrieve and validate a Password from console.
    Do {
        # Enter password 1st Time.
        $pwd1 =  read-host -AsSecureString $(If ($Comment ){echo $Comment} else {echo "Enter Password:"} )
        $pwd1_txt = ConvertFrom-SecureToPlain -SecureString $pwd1

        # Enter password 2st Time.
        $pwd2 =  read-host -AsSecureString "Re-enter password: "
        $pwd2_txt = ConvertFrom-SecureToPlain -SecureString $pwd2

        # Compare txt versions of passwords
        If ($pwd1_txt -ne $pwd2_txt) {
            write-host "Error:  Passwords do match.  Try again." -ForegroundColor Red
        } # END: If

    } until ($pwd1_txt -eq $pwd2_txt)  # END: Do/While loop
    
    # Check required return value.
    If ($ReturnAsString) {

        # Display Debug Message
        if ($global:debug) {write-host "Returning plain text password: $pwd1_txt" -ForegroundColor Yellow }

        return $pwd1_txt

    } else {

        # Display Debug Message
        if ($global:debug) {write-host "Returning Secure String password: $pwd1_txt" -ForegroundColor Yellow }

        return $pwd1

    } # END: If

    End {
        # Clean-up vairables.
        If ($pwd1) {Remove-Variable pwd1}
        If ($pwd2) {Remove-Variable pwd2}
        If ($pwd1_txt) {Remove-Variable pwd1_txt}
        If ($pwd2_txt) {Remove-Variable pwd2_txt}
        If ($ReturnAsString) {Remove-Variable ReturnAsString}
        If ($result) {Remove-Variable result}
    } # END: Function End Processes

} # END: Function
