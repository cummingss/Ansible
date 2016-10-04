# Add Certificate Servers for mldir.net domain in DEV.
Add-WindowsFeature  AD-Certificate, ADCS-Online-Cert -includemanagementtools
restart-computer
