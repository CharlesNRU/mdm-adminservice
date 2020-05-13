<#
.SYNOPSIS
	Queries the ConfigMgr AdminService for a list of packages and filters down to the package that best matches what was provided in the parameters.
    Script returns the PackageID of the selected package.

.DESCRIPTION
    This script will query the ConfigMgr AdminService and retrieve a list of driver or BIOS packages. It will then
    filter  down to the most suitable package according to the parameters given.
    The script returns a PackageID which can then be used in a task sequence to download the content and apply drivers
    or BIOS updates

    Note: If multiple suitable packages are found after filtering, the most recently created package will be selected.

    Note2: The filtering process assumes that you are using packages created by the Driver Automation Tool
    Link: https://github.com/maurice-daly/DriverAutomationTool
    This tool allows you to easily select and download BIOS and Driver packages from major manufacturers.
    You can also create custom driver packages from the tool if the vendor is not supported directly by the tool.

.PARAMETER ServerFQDN
    The fully qualified domain name of the server hosting the AdminService

.PARAMETER Username
    The username that will be used to query the AdminService. This username needs at least the "Read" permission on packages in SCCM

.PARAMETER Password
    The password of the username

.PARAMETER BypassCertCheck
    Enabling this option will allow PowerShell to accept any certificate when querying the AdminService.

.PARAMETER Manufacturer
    Specify the manufacturer of the device

.PARAMETER Model
    Specify the mode name of the device

.PARAMETER SystemSKU
    Specify the System SKU of the device (preferred option, more precise than model name)

.PARAMETER PackageType
    Specify whether the script will return a BIOS Package or a Driver Package

.PARAMETER DriverPackageOSArch
    If package is a driver package, specify if looking for 32 or 64 bit drivers.
    Note: Parameter is ignored for BIOS Packages.

.PARAMETER DriverPackageReleaseId
    If package is a driver package, specify which specific ReleaseId of Windows 10 you are looking for.
    Note 1: Parameter is ignored for BIOS Packages.
    Note 2: Some manufacturers (ex: Dell) do not have specific ReleaseId driver packages.
            If no suitable driver package is found for the specified ReleaseID, this filter will be ignored.

.PARAMETER LogPath
    Specify the folder where the log file will be located.

.PARAMETER LogFileName
    Specify the name of the log file.

.EXAMPLE
    #Find a 64-bit driver package for the manufacturer 'Dell' for the model name 'Optiplex 5050'
    .\Invoke-GetPackageIDFromAdminService.ps1 -ServerFQDN "cm01.domain.com" -Username "CM_SvcAccount" -Password "123" -PackageType DriverPackage -Manufacturer "Dell" -Model "Optiplex 5050"

    #Find a 32-bit driver package for the manufacturer 'Hewlett-Packard' with the model name 'EliteBook 840 G4 Notebook PC' for Windows 10 1809
    .\Invoke-GetPackageIDFromAdminService.ps1 -ServerFQDN "cm01.domain.com" -Username "CM_SvcAccount" -Password "123" -PackageType DriverPackage -Manufacturer "Hewlett-Packard" -Model "EliteBook 840 G4 Notebook PC" -DriverPackageOSArch x86 -DriverPackageReleaseId 1809

    #Find a BIOS update package for the manufacturer 'Dell' with a System SystemSKU value of "07A2"
    .\Invoke-GetPackageIDFromAdminService.ps1 -ServerFQDN "cm01.domain.com" -Username "CM_SvcAccount" -Password "123" -PackageType BIOSPackage -Manufacturer "Dell" -SystemSKU "07A2"

    #Find a 64-bit driver package for the manufacturer 'Hewlett-Packard' with a System SystemSKU value of "828c"
    .\Invoke-GetPackageIDFromAdminService.ps1 -ServerFQDN "cm01.domain.com" -Username "CM_SvcAccount" -Password "123" -PackageType DriverPackage -Manufacturer "Hewlett-Packard" -SystemSKU "828c" -DriverPackageOSArch x64

.NOTES
    FileName:    Invoke-GetPackageIDFromAdminService.ps1
    Author:      Charles Tousignant
    Created:     2020-04-28
    Updated:     2020-05-10
#>
[CmdletBinding()]
param(
    [parameter(Mandatory = $true, HelpMessage = "Set the FQDN of the server hosting the ConfigMgr AdminService.")]
	[ValidateNotNullOrEmpty()]
	[string]$ServerFQDN,

    [parameter(Mandatory = $false, HelpMessage = "Specify the username that will be used to query the AdminService.")]
	[ValidateNotNullOrEmpty()]
	[string]$Username,

    [parameter(Mandatory = $false, HelpMessage = "Specify the password for the username that will be used to query the AdminService.")]
	[ValidateNotNullOrEmpty()]
	[string]$Password,

    [parameter(Mandatory = $false, HelpMessage = "If set to True, PowerShell will bypass SSL certificate checks when contacting the AdminService.")]
    [bool]$BypassCertCheck = $False,

    [parameter(Mandatory = $false, HelpMessage = "Specify the manufacturer of the device.")]
    [ValidateNotNullOrEmpty()]
    [string]$Manufacturer = "Unknown",

    [parameter(Mandatory = $false, HelpMessage = "Specify the model of the device.")]
    [ValidateNotNullOrEmpty()]
    [string]$Model = "Unknown",

    [parameter(Mandatory = $false, HelpMessage = "Specify the SystemSKU of the device.")]
    [ValidateNotNullOrEmpty()]
    [string]$SystemSKU = "Unknown",

    [parameter(Mandatory = $true, HelpMessage = "Specify the package type that will be returned: DriverPackage or BIOSPackage.")]
    [ValidateNotNullOrEmpty()]
    [ValidateSet("DriverPackage", "BIOSPackage")]
    [string]$PackageType,

    [parameter(Mandatory = $false, HelpMessage = "For DriverPackages only: Specify OS Architecture")]
    [ValidateSet("x64", "x86")]
	[string]$DriverPackageOSArch = "x64",

    [parameter(Mandatory = $false, HelpMessage = "For DriverPackages only: Specify the ReleaseId of Windows 10 that you are targeting (ex: 1909).")]
    [ValidateRange(0,9999)]
	[int]$DriverPackageReleaseId = 0,

    [parameter(Mandatory = $false, HelpMessage = "Specify the path where the log file will be created.")]
    [ValidateScript({
        If(-not ($_ | Test-Path)){
            throw "File or folder does not exist"
        }
        If(-not ($_ | Test-Path -PathType Container)){
            throw "The LogPath must be a folder, not a file."
        }
        return $true
    })]
    [System.IO.FileInfo]$LogPath = "$env:SystemRoot\Temp",

    [parameter(Mandatory = $false, HelpMessage = "Specify the name of the log file.")]
    [ValidateNotNullOrEmpty()]
    [string]$LogFileName = "GetPackageID_$($PackageType).log"
)
Begin {
    Function Add-TextToCMLog {
    ##########################################################################################################
    <#
    .SYNOPSIS
       Log to a file in a format that can be read by Trace32.exe / CMTrace.exe

    .DESCRIPTION
       Write a line of data to a script log file in a format that can be parsed by Trace32.exe / CMTrace.exe

       The severity of the logged line can be set as:

            1 - Information
            2 - Warning
            3 - Error

       Warnings will be highlighted in yellow. Errors are highlighted in red.

       The tools to view the log:

       SMS Trace - http://www.microsoft.com/en-us/download/details.aspx?id=18153
       CM Trace - Installation directory on Configuration Manager 2012 Site Server - <Install Directory>\tools\

    .EXAMPLE
       Add-TextToCMLog c:\output\update.log "Application of MS15-031 failed" Apply_Patch 3

       This will write a line to the update.log file in c:\output stating that "Application of MS15-031 failed".
       The source component will be Apply_Patch and the line will be highlighted in red as it is an error
       (severity - 3).

    #>
    ##########################################################################################################

    #Define and validate parameters
    [CmdletBinding()]
    Param(
          #Path to the log file
          [parameter(Mandatory=$True)]
          [String]$LogFile,

          #The information to log
          [parameter(Mandatory=$True)]
          [String]$Value,

          #The source of the error
          [parameter(Mandatory=$True)]
          [String]$Component,

          #The severity (1 - Information, 2- Warning, 3 - Error)
          [parameter(Mandatory=$True)]
          [ValidateRange(1,3)]
          [Single]$Severity
          )


    #Obtain UTC offset
    $DateTime = New-Object -ComObject WbemScripting.SWbemDateTime
    $DateTime.SetVarDate($(Get-Date))
    $UtcValue = $DateTime.Value
    $UtcOffset = $UtcValue.Substring(21, $UtcValue.Length - 21)


    #Create the line to be logged
    $LogLine =  "<![LOG[$Value]LOG]!>" +`
                "<time=`"$(Get-Date -Format HH:mm:ss.fff)$($UtcOffset)`" " +`
                "date=`"$(Get-Date -Format M-d-yyyy)`" " +`
                "component=`"$Component`" " +`
                "context=`"$([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)`" " +`
                "type=`"$Severity`" " +`
                "thread=`"$($pid)`" " +`
                "file=`"`">"

    #Write the line to the passed log file
    Out-File -InputObject $LogLine -Append -NoClobber -Encoding Default -FilePath $LogFile -WhatIf:$False

    }
	Try{
        $LogFile = Join-Path $LogPath $LogFileName
        $component = "Invoke-GetPackageIDFromAdminService"
        Add-TextToCMLog $LogFile "*******************$component started.*******************" $component 1
    }Catch{
        Write-Error -Message "Failed to write to the logfile `"$LogFile`"" -ErrorAction Stop
    }
}
Process{
    Try{
        If((-not $Model -or $Model -eq 'Unknown') -and (-not $SystemSKU -or $SystemSKU -eq 'Unknown')){
            Add-TextToCMLog -Value "No model or SystemSKU provided, we need at least one of these values to determine a suitable package." -LogFile $LogFile -Component $component -Severity 3
            Return
        }

        If($Username){
            If($Password){
                $Global:Credential = New-Object System.Management.Automation.PSCredential -ArgumentList $Username,($Password | ConvertTo-SecureString -AsPlainText -Force)
                $Global:InvokeRestMethodCredential = @{
                    "Credential" = ($Global:Credential)
                }
            }Else{
                Add-TextToCMLog -Value "Username provided without a password, please specify a password." -LogFile $LogFile -Component $component -Severity 3
                Return
            }
        }Else{
            Add-TextToCMLog -Value "Using default credentials to query the AdminService." -LogFile $LogFile -Component $component -Severity 1
            $Global:InvokeRestMethodCredential = @{
                "UseDefaultCredentials" = $True
            }
        }

        If($BypassCertCheck){
            Add-TextToCMLog $LogFile  "Bypassing certificate checks to query the AdminService." $component 2
            #Source: https://til.intrepidintegration.com/powershell/ssl-cert-bypass.html
            Add-Type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(
        ServicePoint srvPoint, X509Certificate certificate,
        WebRequest request, int certificateProblem) {
        return true;
    }
}
"@
            [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Ssl3, [Net.SecurityProtocolType]::Tls, [Net.SecurityProtocolType]::Tls11, [Net.SecurityProtocolType]::Tls12
        }

        #Build AdminService URI
        [string]$Global:BaseUrl = "https://$($ServerFQDN)/AdminService"


        $WMIPackageURL = $Global:BaseUrl + "/wmi/SMS_Package"


        Add-TextToCMLog $LogFile  "Retrieving list of SMS_Package from the AdminService @ `"$($WMIPackageURL)`"" $component 1

        If($PackageType -eq "DriverPackage"){
            $Filter = "startswith(Name,'Drivers - ')"
        }ElseIf($PackageType -eq "BIOSPackage"){
            $Filter = "startswith(Name,'BIOS Update - ')"
        }
        $Body = @{
            "`$filter" = $Filter
            "`$select" = "Name,Description,Manufacturer,Version,SourceDate,PackageID"
        }

        $Packages = (Invoke-RestMethod -Method Get -Uri $WMIPackageURL -Body $Body @Global:InvokeRestMethodCredential | Select-Object -ExpandProperty value)

        If(($Packages | Measure-Object).Count -gt 0){
            Add-TextToCMLog $LogFile  "Initial count of packages before starting filtering process: $(($Packages | Measure-Object).Count)" $component 1

            If($Manufacturer -and ($Manufacturer -ne 'Unknown')){
                # Filter out packages that does not match with the vendor
                Add-TextToCMLog $LogFile  "Filtering package from specified computer manufacturer: $($Manufacturer)" $component 1
                $Packages = $Packages | Where-Object{$_.Manufacturer -like $Manufacturer}
                Add-TextToCMLog $LogFile  "Count of packages after filter processing: $(($Packages | Measure-Object).Count)" $component 1
            }

            # Filter out driver packages that does not contain any value in the package description
            Add-TextToCMLog $LogFile  "Filtering package results to only include packages that have details added to the description field" $component 1
            $Packages = $Packages | Where-Object{$_.Description -ne ([string]::Empty)}
            Add-TextToCMLog $LogFile  "Count of packages after filter processing: $(($Packages | Measure-Object).Count)" $component 1

            If($PackageType -eq "DriverPackage"){
                # Filter for OS Architecture
                Add-TextToCMLog $LogFile  "Filtering driver packages for the specified OS Architecture: `"$DriverPackageOSArch`"" $component 1
                $Packages = $Packages | Where-Object{$_.Name -like "* $DriverPackageOSArch*"}
                Add-TextToCMLog $LogFile  "Count of packages after filter processing: $(($Packages | Measure-Object).Count)" $component 1

                If($DriverPackageReleaseId -ne 0){
                    Add-TextToCMLog $LogFile  "Filtering driver package for the specified ReleaseID: `"$DriverPackageReleaseId`"" $component 1
                    $ReleaseIdPackages = $Packages | Where-Object{$_.Name -like "* $DriverPackageReleaseId *"}
                    If(($ReleaseIdPackages | Measure-Object).Count -gt 0){
                        $Packages = $ReleaseIdPackages
                    }Else{
                        Add-TextToCMLog $LogFile  "Could not find any driver packages for ReleaseID `"$DriverPackageReleaseId`". Ignoring ReleaseId filter..." $component 2
                    }
                    Add-TextToCMLog $LogFile  "Count of packages after filter processing: $(($Packages | Measure-Object).Count)" $component 1
                }
            }
            If($SystemSKU -and ($SystemSKU -ne 'Unknown')){
                Add-TextToCMLog $LogFile  "Filtering package results to only packages that have the SystemSKU `"$($SystemSKU)`" in the description field." $component 1
                $SystemSKUMatchingPackages = New-Object System.Collections.ArrayList
                Foreach($Package in $Packages){
                    $Description = $package.description

                    #Removing the "(Models included:" and the ")" from the description
                    $Description = ($Description -replace "\(Models included:","") -replace "\)",""

                    If($Description -match ","){
                        $SystemSKUDelimiter = ","
                    }
                    If($Description -match ";"){
                        $SystemSKUDelimiter = ";"
                    }

                    If($SystemSKUDelimiter){
                        $PackageSKUs = $Description -split $SystemSKUDelimiter
                    }Else{#No SystemSKU delimiter found, assuming only one SystemSKU for this driver package
                        $PackageSKUs = $Description
                    }

                    If($PackageSKUs -contains $SystemSKU){
                        [void]$SystemSKUMatchingPackages.add($Package)
                    }
                }
                If(($SystemSKUMatchingPackages | Measure-Object).Count -gt 0){
                    $Packages = $SystemSKUMatchingPackages
                }Else{
                    If($Model -and ($Model -ne 'Unknown')){
                        $ModelFilteringNeeded = $true
                        Add-TextToCMLog $LogFile  "Could not find any packages matching SystemSKU `"$SystemSKU`", attempting to filter by model name as a fallback." $component 2
                    }Else{
                        Add-TextToCMLog $LogFile  "Could not find any packages matching SystemSKU `"$SystemSKU`" and no model name provided as a fallback." $component 3
                        $Packages = $null
                    }
                }
                Add-TextToCMLog $LogFile  "Count of packages after filter processing: $(($Packages | Measure-Object).Count)" $component 1

            }
            If((!$SystemSKU -or $SystemSKU -eq 'Unknown') -or $ModelFilteringNeeded){
                Add-TextToCMLog $LogFile  "Filtering package results to only packages that have the model name `"$($Model)`" in the package name." $component 1
                $Packages = $Packages | Where-Object{$_.Name -like "*$Model*"}
                Add-TextToCMLog $LogFile  "Count of packages after filter processing: $(($Packages | Measure-Object).Count)" $component 1
            }

            switch(($Packages | Measure-Object).Count){
                0{
                    Add-TextToCMLog $LogFile  "No suitable package found." $component 3
                }
                1{
                    Add-TextToCMLog $LogFile  "Found exactly 1 package after the filtering process." $component 1
                    $SelectedPackage = $Packages
                }
                default{
                    Add-TextToCMLog $LogFile  "Found multiple packages after the filtering process, will use the most recently created package." $component 1
                    $SelectedPackage = ($Packages | Sort-Object -Property SourceDate -Descending | Select-Object -First 1)
                }
            }
        }Else{
            Add-TextToCMLog $LogFile  "Could not find any packages from the AdminService." $component 3
        }
    }Catch{
        Add-TextToCMLog $LogFile  "Error: $($_.Exception.HResult)): $($_.Exception.Message)" $component 3
        Add-TextToCMLog $LogFile "$($_.InvocationInfo.PositionMessage)" $component 3
        Exit 1
    }
}
End{
    If($SelectedPackage){
        Add-TextToCMLog $LogFile "Selected Package: `"$($SelectedPackage.Name)`"" $component 1
        Add-TextToCMLog $LogFile "Returning PackageID `"$($SelectedPackage.PackageID)`"" $component 1
    }
    Add-TextToCMLog $LogFile "*******************$component finished.*******************" $component 1
    If($SelectedPackage){
        Return $($SelectedPackage.PackageID)
    }
}