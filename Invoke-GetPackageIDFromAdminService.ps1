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
    For intranet clients
    The fully qualified domain name of the server hosting the AdminService
    
.PARAMETER ExternalUrl
    For internet clients
    ExternalUrl of the AdminService you wish to connect to. You can find the ExternalUrl by directly querying your CM database.
    Query: SELECT ProxyServerName,ExternalUrl FROM [dbo].[vProxy_Routings] WHERE [dbo].[vProxy_Routings].ExternalEndpointName = 'AdminService'
    It should look like this: HTTPS://<YOURCMG>.<FQDN>/CCM_Proxy_ServerAuth/<RANDOM_NUMBER>/AdminService
    
.PARAMETER TenantId
    For internet clients
    Azure AD Tenant ID that is used for your CMG

.PARAMETER ClientId
    For internet clients
    Client ID of the application registration created to interact with the AdminService

.PARAMETER ApplicationIdUri
    For internet clients
    Application ID URI of the Configuration manager Server app created when creating your CMG.
    The default value of 'https://ConfigMgrService' should be good for most people.
    
.PARAMETER Username
    The username that will be used to query the AdminService. This username needs at least the "Read" permission on packages in SCCM

.PARAMETER Password
    The password of the username

.PARAMETER BypassCertCheck
    Enabling this option will allow PowerShell to accept any certificate when querying the AdminService.
    If you do not enable this option, you need to make sure the certificate used by the AdminService is trusted by the device.

.PARAMETER Manufacturer
    Specify the manufacturer of the device

.PARAMETER Model
    Specify the mode name of the device

.PARAMETER SystemSKU
    Specify the System SKU of the device (preferred option, more precise than model name)

.PARAMETER PackageType
    Specify whether the script will return a BIOS Package or a Driver Package

.PARAMETER PilotPackages
    If set to True, the script will only return pilot packages.

.PARAMETER DriverPackageOSArch
    If package is a driver package, specify if looking for 32 or 64 bit drivers.
    Note: Parameter is ignored for BIOS Packages.

.PARAMETER DriverPackageReleaseId
    If package is a driver package, specify which specific ReleaseId of Windows 10 you are looking for. (1909, 2004, 20H2, etc.)
    Note 1: Parameter is ignored for BIOS Packages.
    Note 2: Some manufacturers (ex: Dell) do not have specific ReleaseId driver packages.
            If no suitable driver package is found for the specified ReleaseID, this filter will be ignored.

.PARAMETER CurrentBIOSVersion
    If package is a BIOS package, specify the current BIOS version.
    Vendors each have their own version name standards, make sure it matches version naming in your packages.
    Note: Parameter is ignored for Driver Packages.
    
.PARAMETER CurrentBIOSReleaseDate
    If package is a BIOS package, specify the current BIOS release date.
    By default, this parameter will get the release date information directly from the system.
    You would probably only specify this parameter for testing purposes.
    Note: Parameter is ignored for Driver Packages.

.PARAMETER LogPath
    Specify the folder where the log file will be located.

.PARAMETER LogFileName
    Specify the name of the log file.

.EXAMPLE
    Find a 64-bit driver package for the manufacturer 'Dell' for the model name 'Optiplex 5050'
    Invoke-GetPackageIDFromAdminService.ps1 -ServerFQDN "cm01.domain.com" -Username "CM_SvcAccount" -Password "123" -PackageType DriverPackage -Manufacturer "Dell" -Model "Optiplex 5050"

.EXAMPLE
    Find a 32-bit driver package for the manufacturer 'HP' with the model name 'EliteBook 840 G4 Notebook PC' for Windows 10 1809
    Invoke-GetPackageIDFromAdminService.ps1 -ServerFQDN "cm01.domain.com" -Username "CM_SvcAccount" -Password "123" -PackageType DriverPackage -Manufacturer "HP" -Model "EliteBook 840 G4 Notebook PC" -DriverPackageOSArch x86 -DriverPackageReleaseId 1809

.EXAMPLE
    Find a BIOS update package for the manufacturer 'Dell' with a System SystemSKU value of "07A2"
    Invoke-GetPackageIDFromAdminService.ps1 -ServerFQDN "cm01.domain.com" -Username "CM_SvcAccount" -Password "123" -PackageType BIOSPackage -Manufacturer "Dell" -SystemSKU "07A2" -CurrentBIOSVersion "1.23"

.EXAMPLE
    Find a 64-bit driver package for the manufacturer 'HP' with a System SystemSKU value of "828c"
    Invoke-GetPackageIDFromAdminService.ps1 -ServerFQDN "cm01.domain.com" -Username "CM_SvcAccount" -Password "123" -PackageType DriverPackage -Manufacturer "HP" -SystemSKU "828c" -DriverPackageOSArch x64

.EXAMPLE
    Find a pilot BIOS update package for the manufacturer 'Lenovo' for the model 'ThinkPad X270'
    Invoke-GetPackageIDFromAdminService.ps1 -ServerFQDN "cm01.domain.com" -Username "CM_SvcAccount" -Password "123" -PackageType BIOSPackage -Manufacturer "Lenovo" -Model "ThinkPad X270" -CurrentBIOSVersion "1.38" -PilotPackages $true

.EXAMPLE
    Find a driver package for the manufacturer 'Dell' for the model name 'Optiplex 5050' via CMG
    Invoke-GetPackageIDFromAdminService.ps1 -ExternalUrl "HTTPS://BOBCMG.BOBBY.COM/CCM_Proxy_ServerAuth/12124441919/AdminService" -TenantId b18e3ea8-164d-473d-aedc-65d9ed6afaa6 -CLientId b64efa47-bc07-4781-a022-3fd1345826e7 -Username CM_BOB@BOBBY.COM -Password 123 -PackageType DriverPackage -Manufacturer "Dell" -Model "Optiplex 5050"

.NOTES
    FileName:    Invoke-GetPackageIDFromAdminService.ps1
    Author:      Charles Tousignant
    Contact:     @NoRemoteUsers
    Created:     2020-04-28
    Updated:     2024-05-01
    
    Version history:
    1.0.0 (2020-04-28): Script created
    1.1.0 (2020-05-30): Added logic & parameters to filter any BIOS package retrieved that is not an update
                        Added boolean parameter 'PilotPackages' to allow querying for pilot packages
                        Improved the code to parse SKUs & ReleaseDate info from package descriptions
    2.0.0 (2021-04-24): Added Support for CMG
                        Added logic to dynamically install the required MSAL.PS module when using CMG
    2.1.0 (2023-02-04): Changes in the AdminService in CB2111 caused the Invoke-restmethod fail when using
                        -Body parameter to specify filtering criteria, implemented workaround.
    2.1.1 (2024-04-25): Added Win10/11 filtering. -Dan Hammond (@FlannelNZ)
    2.2.0 (2024-05-01): Removed dependency on MSAL.PS module when using CMG

#>
[CmdletBinding()]
param(
    [parameter(Mandatory = $true, HelpMessage = "Set the FQDN of the server hosting the ConfigMgr AdminService.", ParameterSetName = "Intranet")]
	[ValidateNotNullOrEmpty()]
	[string]$ServerFQDN,
    
    [parameter(Mandatory = $true, HelpMessage = "Set the CMG ExternalUrl for the AdminService.", ParameterSetName = "Internet")]
	[ValidateNotNullOrEmpty()]
	[string]$ExternalUrl,
    
    [parameter(Mandatory = $true, HelpMessage = "Set your TenantID.", ParameterSetName = "Internet")]
	[ValidateNotNullOrEmpty()]
	[string]$TenantID,
    
    [parameter(Mandatory = $true, HelpMessage = "Set the ClientID of app registration to interact with the AdminService.", ParameterSetName = "Internet")]
	[ValidateNotNullOrEmpty()]
	[string]$ClientID,
    
    [parameter(Mandatory = $false, HelpMessage = "Specify URI here if using non-default Application ID URI for the configuration manager server app.", ParameterSetName = "Internet")]
	[ValidateNotNullOrEmpty()]
	[string]$ApplicationIdUri = 'https://ConfigMgrService',
        

    [parameter(Mandatory = $false, HelpMessage = "Specify the username that will be used to query the AdminService.", ParameterSetName = "Intranet")]
    [parameter(Mandatory = $true, HelpMessage = "Specify the username that will be used to query the AdminService.", ParameterSetName = "Internet")]
	[ValidateNotNullOrEmpty()]
	[string]$Username,

    [parameter(Mandatory = $false, HelpMessage = "Specify the password for the username that will be used to query the AdminService.", ParameterSetName = "Intranet")]
    [parameter(Mandatory = $true, HelpMessage = "Specify the password for the username that will be used to query the AdminService.", ParameterSetName = "Internet")]
	[ValidateNotNullOrEmpty()]
	[string]$Password,

    [parameter(Mandatory = $false, HelpMessage = "If set to True, PowerShell will bypass SSL certificate checks when contacting the AdminService.", ParameterSetName = "Intranet")]
    [parameter(Mandatory = $false, HelpMessage = "If set to True, PowerShell will bypass SSL certificate checks when contacting the AdminService.", ParameterSetName = "Internet")]
    [bool]$BypassCertCheck = $false,

    [parameter(Mandatory = $false, HelpMessage = "Specify the manufacturer of the device.", ParameterSetName = "Intranet")]
    [parameter(Mandatory = $false, HelpMessage = "Specify the manufacturer of the device.", ParameterSetName = "Internet")]
    [ValidateNotNullOrEmpty()]
    [string]$Manufacturer = "Unknown",

    [parameter(Mandatory = $false, HelpMessage = "Specify the model of the device.", ParameterSetName = "Intranet")]
    [parameter(Mandatory = $false, HelpMessage = "Specify the model of the device.", ParameterSetName = "Internet")]
    [ValidateNotNullOrEmpty()]
    [string]$Model = "Unknown",

    [parameter(Mandatory = $false, HelpMessage = "Specify the SystemSKU of the device.", ParameterSetName = "Intranet")]
    [parameter(Mandatory = $false, HelpMessage = "Specify the SystemSKU of the device.", ParameterSetName = "Internet")]
    [ValidateNotNullOrEmpty()]
    [string]$SystemSKU = "Unknown",

    [parameter(Mandatory = $true, HelpMessage = "Specify the package type that will be returned: DriverPackage or BIOSPackage.", ParameterSetName = "Intranet")]
    [parameter(Mandatory = $true, HelpMessage = "Specify the package type that will be returned: DriverPackage or BIOSPackage.", ParameterSetName = "Internet")]
    [ValidateNotNullOrEmpty()]
    [ValidateSet("DriverPackage", "BIOSPackage")]
    [string]$PackageType,
    
    [parameter(Mandatory = $false, HelpMessage = "If set to True, the script will only return pilot packages.", ParameterSetName = "Intranet")]
    [parameter(Mandatory = $false, HelpMessage = "If set to True, the script will only return pilot packages.", ParameterSetName = "Internet")]
    [bool]$PilotPackages = $false,

    [parameter(Mandatory = $false, HelpMessage = "For DriverPackages only: Specify OS Architecture", ParameterSetName = "Intranet")]
    [parameter(Mandatory = $false, HelpMessage = "For DriverPackages only: Specify OS Architecture", ParameterSetName = "Internet")]
    [ValidateSet("x64", "x86")]
    [string]$DriverPackageOSArch = "x64",

    [parameter(Mandatory = $false, HelpMessage = "For DriverPackages only: Specify the version of Windows (ex: Windows 10).", ParameterSetName = "Intranet")]
    [parameter(Mandatory = $false, HelpMessage = "For DriverPackages only: Specify the version of Windows (ex: Windows 11).", ParameterSetName = "Internet")]
    [string]$DriverPackageWinVer = "Unknown",

    [parameter(Mandatory = $false, HelpMessage = "For DriverPackages only: Specify the ReleaseId of Windows 10 that you are targeting (ex: 1909).", ParameterSetName = "Intranet")]
    [parameter(Mandatory = $false, HelpMessage = "For DriverPackages only: Specify the ReleaseId of Windows 10 that you are targeting (ex: 1909).", ParameterSetName = "Internet")]
    [string]$DriverPackageReleaseId = "Unknown",

    [parameter(Mandatory = $false, HelpMessage = "For BIOSPackages only: Specify the system's current BIOS version.", ParameterSetName = "Intranet")]
    [parameter(Mandatory = $false, HelpMessage = "For BIOSPackages only: Specify the system's current BIOS version.", ParameterSetName = "Internet")]
    [ValidateNotNullOrEmpty()]
    [string]$CurrentBIOSVersion = "Unknown",

    [parameter(Mandatory = $false, HelpMessage = "For BIOSPackages only: Specify the system's current BIOS release date in the following format: yyyyMMdd", ParameterSetName = "Intranet")]
    [parameter(Mandatory = $false, HelpMessage = "For BIOSPackages only: Specify the system's current BIOS release date in the following format: yyyyMMdd", ParameterSetName = "Internet")]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({
        Try{
            [datetime]::ParseExact($_,"yyyyMMdd",$null)
            Return $true
        }Catch{
            throw "Date format needs to be `"yyyyMMdd`"."
        }
    })]
    [string]$CurrentBIOSReleaseDate = $(
        $date = Get-CimInstance -ClassName CIM_BIOSElement | Select-Object -ExpandProperty ReleaseDate
        If($date){
            #BIOS Release Date is not null, assigning the value in the expected format.
            $date | Get-Date -Format "yyyyMMdd"
        }Else{
            #BIOS Release Date is null, assigning an old date
            "19700101"
        }
    ),
    
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
    
    Function Get-AdminServiceUri{
        If($ServerFQDN){
            Return "https://$($ServerFQDN)/AdminService"
        }
        If($ExternalUrl){
            Return $ExternalUrl
        }
    }
}
Process{
    Try{
        If((-not $Model -or $Model -eq 'Unknown') -and (-not $SystemSKU -or $SystemSKU -eq 'Unknown')){
            Add-TextToCMLog -Value "No model or SystemSKU provided, we need at least one of these values to determine a suitable package." -LogFile $LogFile -Component $component -Severity 3
            Return
        }
        
        Add-TextToCMLog -Value "Processing credentials..." -LogFile $LogFile -Component $component -Severity 1
        switch($PSCmdlet.ParameterSetName){
            "Intranet"{
                If($Username){
                    If($Password){
                        Add-TextToCMLog -Value "Using provided username & password to query the AdminService." -LogFile $LogFile -Component $component -Severity 3
                        $Credential = New-Object System.Management.Automation.PSCredential -ArgumentList $Username,($Password | ConvertTo-SecureString -AsPlainText -Force)
                        $InvokeRestMethodCredential = @{
                            "Credential" = ($Credential)
                        }
                    }Else{
                        Add-TextToCMLog -Value "Username provided without a password, please specify a password." -LogFile $LogFile -Component $component -Severity 3
                        Return
                    }
                }Else{
                    Add-TextToCMLog -Value "No username provided, using current user credentials to query the AdminService." -LogFile $LogFile -Component $component -Severity 1
                    $InvokeRestMethodCredential = @{
                        "UseDefaultCredentials" = $True
                    }
                }
                
            }
            "Internet"{
                Add-TextToCMLog -Value "Getting access token to query the AdminService via CMG." -LogFile $LogFile -Component $component -Severity 1
                $body = @{
                    grant_type  = "password"
                    scope       = ([String]::Concat($($ApplicationIdUri),'/user_impersonation'))
                    client_id   = $ClientID
                    username    = $Username
                    password    = $Password
                }
                $contentType = "application/x-www-form-urlencoded"
                $uri = "https://login.microsoftonline.com/$($TenantID)/oauth2/v2.0/token"
                $authToken = Invoke-RestMethod -Method Post -Uri $uri -ContentType $contentType -Body $body
                Add-TextToCMLog -Value "Successfully retrieved access token." -LogFile $LogFile -Component $component -Severity 1
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
       
        $WMIPackageURI = [String]::Concat($(Get-AdminServiceUri),"/wmi/SMS_Package")
        Add-TextToCMLog $LogFile  "Retrieving list of packages from the AdminService @ `"$($WMIPackageURI)`"" $component 1

        switch($PackageType){
            "DriverPackage"{
                If(-not $PilotPackages){
                    $Filter = "startswith(Name,'Drivers -')"
                }Else{
                    $Filter = "startswith(Name,'Drivers Pilot -')"
                }
            }
            "BIOSPackage"{
                If(-not $PilotPackages){
                    $Filter = "startswith(Name,'BIOS Update -')"
                }Else{
                    $Filter = "startswith(Name,'BIOS Update Pilot -')"
                }
            }
        }

        $Body = @{
            "`$filter" = $Filter
            "`$select" = "Name,Description,Manufacturer,Version,SourceDate,PackageID"
        }

        #Fix for AdminService CB2111 and newer
        Add-Type -AssemblyName System.Web
        $BodyParameters = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
        foreach ($param in $Body.GetEnumerator()) {
            $BodyParameters.Add($param.Name, $param.Value)
        }
        $Request = [System.UriBuilder]($WMIPackageURI)
        $Request.Query = $BodyParameters.ToString()
        $DecodedURI = [System.Web.HttpUtility]::UrlDecode($Request.Uri)


        switch($PSCmdlet.ParameterSetName){
            'Intranet'{
                $Packages = Invoke-RestMethod -Method Get -Uri $DecodedURI @InvokeRestMethodCredential | Select-Object -ExpandProperty value
            }
            'Internet'{
                $authHeader = @{
                    'Authorization' = "Bearer " + $authToken.access_token
                }
                $Packages = Invoke-RestMethod -Method Get -Uri $DecodedURI -Headers $authHeader | Select-Object -ExpandProperty value
            }
        }      

        If(($Packages | Measure-Object).Count -gt 0){
            Add-TextToCMLog $LogFile  "Initial count of packages before starting filtering process: $(($Packages | Measure-Object).Count)" $component 1

            If($Manufacturer -and ($Manufacturer -ne 'Unknown')){
                # Filter out packages that do not match Manufacturer value
                Add-TextToCMLog $LogFile  "Filtering package from specified computer manufacturer: $($Manufacturer)" $component 1
                $Packages = $Packages | Where-Object{$_.Manufacturer -like $Manufacturer}
                Add-TextToCMLog $LogFile  "Count of packages after filter processing: $(($Packages | Measure-Object).Count)" $component 1
            }

            # Filter out packages that do not contain any value in the package description
            Add-TextToCMLog $LogFile  "Filtering package results to only include packages that have details added to the description field" $component 1
            $Packages = $Packages | Where-Object{$_.Description -ne ([string]::Empty)}
            Add-TextToCMLog $LogFile  "Count of packages after filter processing: $(($Packages | Measure-Object).Count)" $component 1

            If($SystemSKU -and ($SystemSKU -ne 'Unknown')){
                Add-TextToCMLog $LogFile  "Filtering package results to only packages that have the SystemSKU `"$($SystemSKU)`" in the description field." $component 1
                $SystemSKUMatchingPackages = New-Object System.Collections.ArrayList
                Foreach($Package in $Packages){
                    $Description = $package.Description
                    If($Description -match "\(Models included:(.*)\) \(Release Date:(.*)\)"){
                        $SKUList = $matches[1]
                    }ElseIf($Description -match "\(Models included:(.*)\)"){
                        $SKUList = $matches[1]
                    }

                    If($SKUList -match ";"){
                        $SystemSKUDelimiter = ";"
                    }ElseIf($SKUList -match ","){
                        $SystemSKUDelimiter = ","
                    }ElseIf($SKUList -match " "){
                        $SystemSKUDelimiter = " "
                    }

                    If($SystemSKUDelimiter){
                        $PackageSKUs = $SKUList -split $SystemSKUDelimiter
                    }Else{#No SystemSKU delimiter found, assuming only one SystemSKU for this package
                        $PackageSKUs = $SKUList
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
            If(!$SystemSKU -or $SystemSKU -eq 'Unknown' -or $ModelFilteringNeeded){
                Add-TextToCMLog $LogFile  "Filtering package results to only packages that have the model name `"$($Model)`" in the package name." $component 1
                $Packages = $Packages | Where-Object{$_.Name -like "*$Model*"}
                Add-TextToCMLog $LogFile  "Count of packages after filter processing: $(($Packages | Measure-Object).Count)" $component 1
            }
            
            If($PackageType -eq "DriverPackage"){
                # Filter for OS Architecture
                Add-TextToCMLog $LogFile  "Filtering driver packages for the specified OS Architecture: `"$DriverPackageOSArch`"" $component 1
                $Packages = $Packages | Where-Object{$_.Name -like "* $DriverPackageOSArch*"}
                Add-TextToCMLog $LogFile  "Count of packages after filter processing: $(($Packages | Measure-Object).Count)" $component 1

                # Filter for OS version
                If($DriverPackageWinVer -ne "Unknown"){
                    Add-TextToCMLog $LogFile  "Filtering driver packages for the specified Windows version: `"$DriverPackageWinVer`"" $component 1
                    $Packages = $Packages | Where-Object{$_.Name -like "* $DriverPackageWinVer*"}
                    Add-TextToCMLog $LogFile  "Count of packages after filter processing: $(($Packages | Measure-Object).Count)" $component 1
                }

                #Filter for specific Windows 10 ReleaseId
                If($DriverPackageReleaseId -ne "Unknown"){
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
            
            If($PackageType -eq "BIOSPackage"){
                # Filter out packages that do not contain any value in the package version
                Add-TextToCMLog $LogFile  "Filtering package results to only include packages that have version information in the version field" $component 1
                $Packages = $Packages | Where-Object{$_.Version -ne ([string]::Empty)}
                Add-TextToCMLog $LogFile  "Count of packages after filter processing: $(($Packages | Measure-Object).Count)" $component 1

                Add-TextToCMLog $LogFile  "Filtering package results to only BIOS packages that would be an upgrade to the current BIOS." $component 1
                $ApplicableBIOSPackages = New-Object System.Collections.ArrayList
                If($Manufacturer -ne "Lenovo"){
                    #Check if any of the packages has a BIOS version higher than the current BIOS version
                    If($CurrentBIOSVersion -and $CurrentBIOSVersion -ne "Unknown"){
                        Add-TextToCMLog $LogFile  "Filtering package results to only packages that have a BIOS version higher than  `"$($CurrentBIOSVersion)`"" $component 1

                        foreach($package in $Packages){
                            switch($Manufacturer){
                                "Dell"{
                                    If($package.Version -as [Version]){
                                        If($CurrentBIOSVersion -as [Version]){
                                            If(([Version]$Package.Version) -gt [Version]$CurrentBIOSVersion){
                                                [void]$ApplicableBIOSPackages.Add($package)
                                            }
                                        }ElseIf($CurrentBIOSVersion -like "A*"){
                                            #Moving from A__ version to a proper version number is considered an upgrade for Dell systems
                                            [void]$ApplicableBIOSPackages.Add($package)
                                        }
                                    }ElseIf(($Package.Version -like "A*") -and ($CurrentBIOSVersion -like "A*")){
                                        If(([Int32]::Parse(($Package.Version).TrimStart("A"))) -gt ([Int32]::Parse(($CurrentBIOSVersion).TrimStart("A")))){
                                            [void]$ApplicableBIOSPackages.Add($package)
                                        }
                                    }
                                }
                                "HP"{
                                    $packageVersion = ($package.Version).TrimEnd(".")
                                    $packageVersion = $packageVersion.Split(" ")[0] #Example: 02.02.03 A 1 --> Will only use 02.02.03 for evaluating
                                    If($packageVersion -as [Version]){
                                        If($CurrentBIOSVersion -as [Version]){
                                            If([Version]$packageVersion -gt [Version]$CurrentBIOSVersion){
                                                [void]$ApplicableBIOSPackages.Add($package)
                                            }
                                        }Else{#Attempting to extract a version number from the current BIOS version provided
                                            $CleanBIOSVersion = $CurrentBIOSVersion.TrimEnd(".")
                                            $CleanBIOSVersion = $CleanBIOSVersion.Split(" ")[0]
                                            If($CleanBIOSVersion -as [Version]){
                                                If([Version]$packageVersion -gt [Version]$CleanBIOSVersion){
                                                    [void]$ApplicableBIOSPackages.Add($package)
                                                }
                                            }
                                        }
                                    }ElseIf($packageVersion -match ".*F\.(\d+)$"){
                                        $packageVersion = $matches[1]
                                        If($CurrentBIOSVersion -match ".*F\.(\d+)$"){
                                            If([int32]$packageVersion -gt [int32]$matches[1]){
                                                [void]$ApplicableBIOSPackages.add($package)
                                            }
                                        }
                                    }
                                }
                                "Microsoft"{
                                    Add-TextToCMLog $LogFile  "No BIOS package will be returned, Microsoft provides firmware updates as part of their driver packages." $component 2
                                }
                                default{
                                    #Any other manufacturer: Compare versions only if they both parse as [Version] objects
                                    If(($package.Version -as [Version]) -and ($CurrentBIOSVersion -as [Version])){
                                        If([Version]($package.Version) -gt [Version]$CurrentBIOSVersion){
                                            [void]$ApplicableBIOSPackages.Add($package)
                                        }
                                    }
                                }
                            }
                        }
                    }Else{
                        Add-TextToCMLog $LogFile  "No current BIOS version specified, cannot compare BIOS version." $component 3
                    }
                }Else{
                    #Lenovo Only: Check if any of the remaining packages have a BIOS Release Date newer than the current BIOS Release Date
                    Add-TextToCMLog $LogFile  "Filtering package results to only packages that have a BIOS release date newer than `"$($CurrentBIOSReleaseDate)`"." $component 1
                    $BIOSReleaseDate = [datetime]::ParseExact($CurrentBIOSReleaseDate,"yyyyMMdd",$null)
                    foreach($package in $Packages){
                        If($package.Description -match "\(Models included:(.*)\) \(Release Date:(.*)\)"){
                            Try{
                                $ReleaseDate = [datetime]::ParseExact($matches[2],"yyyyMMdd",$null)
                                If($ReleaseDate -gt $BIOSReleaseDate){
                                    [void]$ApplicableBIOSPackages.Add($package)
                                }
                            }Catch{
                                Add-TextToCMLog $LogFile  "Failed to parse `"$matches[2]`" as a BIOS release date for package `"$($package.Name)`", skipping..." $component 2
                            }
                        }
                    }
                }

                If(($ApplicableBIOSPackages | Measure-Object).Count -gt 0){
                    $Packages = $ApplicableBIOSPackages
                }Else{
                    $Packages = $null
                }
                Add-TextToCMLog $LogFile  "Count of packages after filter processing: $(($Packages | Measure-Object).Count)" $component 1
            }

            switch(($Packages | Measure-Object).Count){
                0{
                    switch($PackageType){
                        "DriverPackage"{
                            Add-TextToCMLog $LogFile  "No suitable driver package found." $component 3
                        }
                        "BIOSPackage"{
                            Add-TextToCMLog $LogFile  "Could not find any applicable BIOS package." $component 1
                        }
                    }
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