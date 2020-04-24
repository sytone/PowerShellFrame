# PowerShellFrame

The PowerShellFrame is a framework for installing and running powershell to be more porductive. 

This updates your profile and adds some handy base commands for working with powershell. 

## Installation

Run the following commands:

As these scripts are not signed you need to allow them to run.

```PowerShell
Set-ExecutionPolicy -ExecutionPolicy Unrestricted
```

Command Window

```PowerShell
@powershell -NoProfile -ExecutionPolicy unrestricted -Command "iex ((new-object net.webclient).DownloadString('https://raw.github.com/sytone/PowerShellFrame/master/install.ps1'))"
```

PowerShell Window

```PowerShell
iex ((new-object net.webclient).DownloadString(('https://raw.github.com/sytone/PowerShellFrame/master/install.ps1?x={0}' -f (Get-Random))))
```

## Handy Commands

- reload          # Reloads the powershell instance. 
- sudo            # Runs elevate-process to run commands as administrator. Eample: sudo powershell
- updatepsf       # Used to update the framework from github
- Install-Tools   # Install Chocolatey and Boxstarter which help with machine setup. 

## Pending Work

- Backup/Sync of your modules and core scripts to a location you want
  - OneDrive
  - Github
- PSGet for module installation?
