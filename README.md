# Ephesoft.Transact.DSC
This powershell module can be used by running Import-Module in a PowerShell console

## Contributing
Please see the contributing.md file

# Module Usage
## Installing Ephesoft Transact with the Module
````powershell
      TransactSetup 'InstallTransact'
      {
        DatabaseType = 'SQL'
        DBCredential = $MyDBCred
        Ensure = 'Present'
        InstallerPath = 'C:\Path\To\Uncompressed\Installers'
        Version = '2020.1'
        LicenseFilePath = 'C:\Path\To\ephesoft.lic'
        SQLAuthTye = 'SQL'
      }
````

## Parameters

| Name                      | Required                                   | Description                                               |
| :------------------------ | :----------------------------------------- | :-------------------------------------------------------- |
| Database Type             | Yes                                        | The type of database to use ('MariaDB', 'SQL', Oracle)    |
| DBCredential              | Yes - Except if using SQL with Windows Auth| PS credential object containing database credentials      |
| Ensure                    | Yes                                        | 'Present' or 'Absent' - Installs/Removes Ephesoft Transact|
| LicenseFilePath           | Yes                                        | Full file path to the license file to be installed        |
| SQLAuthType               | Yes                                        | Specifies the SQL authentication to use ('Windows', SQL') |
| Version                   | Yes                                        | The version of Ephesoft Transct to Install (i.e. 2020.1)  |

## Limitations
* The module currently only supports local databases
* The module currently only supports Ephesoft Transact Versions 2019.1 or higher