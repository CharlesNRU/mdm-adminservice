# Modern BIOS/Driver Management with the Administration Service
This solution is used together with packages created by the [Driver Automation Tool](https://github.com/maurice-daly/DriverAutomationTool) and allows you to dynamically apply drivers or BIOS packages to systems during a task sequence.

### 2021-04-27: [Now works with CMG](https://sysmansquad.com/2021/04/27/updated-modern-driver-bios-management-with-cmg-support/)
- Full OS support : Drivers and BIOS updates over CMG
- WinPE support: Bare metal deployment over CMG

***

## Invoke-GetPackageIDFromAdminService.ps1
PowerShell script developed to query the Configuration Manager Administration Service and return the most suitable Driver or BIOS package according to the values supplied.
***
## MDM-TS.zip
This is an export of the task sequences used for Applying BIOS or Driver packages
***
## Details / Examples
See the following blog posts for more details:

[Modern Driver Management with the Administration Service](https://www.sysmansquad.com/2020/05/15/modern-driver-management-with-the-administration-service)

[Modern BIOS Management with the Administration Service](https://www.sysmansquad.com/2020/06/18/modern-bios-management-with-the-administration-service/)

[Updated Modern Driver/BIOS Management with CMG Support](https://sysmansquad.com/2021/04/27/updated-modern-driver-bios-management-with-cmg-support/)