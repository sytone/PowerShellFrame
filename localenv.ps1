# This is the core logic for the framework, it only has critical commands in it and the rest should come from 
# modules in the system.

# Move to the user profile for all actions. 
push-location $env:USERPROFILE

# Setup drive paths so we can pull modules in ASAP. 
if (-not (Test-Path Scripts:)) {
  New-PSDrive -name Scripts -psprovider FileSystem -root .\Scripts\PowerShell -Description "Scripts Folder" -Scope Global | Out-Null
}

if (-not (Test-Path Psf:)) {
  New-PSDrive -name Psf -psprovider FileSystem -root (Join-Path $env:USERPROFILE "psf") -Description "PowerShellFrame Folder" -Scope Global | Out-Null
}

#
# Pull the scripts into the modules path for easy load. This will mean ability to sync between machines in the future. 
#
if ( -not ($Env:PSModulepath.Contains($(Convert-Path Scripts:CoreModulesManual)) )) {
  $env:PSMODULEPATH += ";" + $(Convert-Path Scripts:CoreModulesManual) 
}

if ( -not ($Env:PSModulepath.Contains($(Convert-Path Scripts:CoreModulesAuto)) )) {
  $env:PSMODULEPATH += ";" + $(Convert-Path Scripts:CoreModulesAuto) 
}

# Import main module. 
Import-Module PowerShellFrame

#
# Import my auto modules. This is everything in the CoreModulesAuto folder. One folder per module. 
#
Get-ChildItem $(Convert-Path Scripts:CoreModulesAuto) | Where-Object {$_.PsIsContainer} | ForEach-Object{ 
  Import-Module $($_.FullName) -Force | out-null
}

# Get the security context for the running shell. 
$id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$wp = new-object System.Security.Principal.WindowsPrincipal($id)
$admin = [System.Security.Principal.WindowsBuiltInRole]::Administrator
$Global:IsAdmin = $wp.IsInRole($admin)


# We now should have the PSF module loaded. Any commands in this file are just related to the console or aliases. 

<#
.SYNOPSIS
  Pulls down the latest version of the console bits. Will use module functions if avaliable.  
#>
function Update-PSF {
    [CmdletBinding()]
    Param(
        [switch]$WhatIf
    )
    $cacheTime =  Get-Random
    $downloadUrl = "https://raw.githubusercontent.com/sytone/PowerShellFrame/master/install.ps1?cache={0}" -f $cacheTime
    Invoke-Expression ((new-object net.webclient).DownloadString($downloadUrl))
    if(-not (Test-Path Function:\Restart-Host)) {"You will need to restart the console instance manually."} 
    else {Restart-Host -Force}
}

<#
.SYNOPSIS
  Shows a nice formatted output of system state at startup. All native PowerShell functions.  
#>
function Show-SystemInfo {
  
  # Grab some system Information to be displayed
  $PSVersion = "{0} - {1}" -f $PSVersionTable.PsVersion, $PSVersionTable.PSEdition
  $IPAddress = (Get-NetIPAddress -AddressFamily IPv4 | where { $_.InterfaceAlias -notmatch 'Loopback' -and $_.InterfaceAlias -notmatch 'bluetooth'})[0].IPAddress
  $Cert = Get-ChildItem -Path Cert:CurrentUser\my -CodeSigningCert
  
  $PreviousColor = $Host.UI.RawUI.ForegroundColor
  #Display relevant information
  Write-Host "ComputerName:".PadRight(24," ") -ForegroundColor $Color_Label -nonewline
  Write-Host "$($env:COMPUTERNAME)" -ForegroundColor $Color_Value_2
  Write-Host "IP Address:".PadRight(24," ") -ForeGroundColor $Color_Label -nonewline
  Write-Host $IPAddress -ForeGroundColor $Color_Value_2
  Write-Host "UserName:".PadRight(24," ") -ForegroundColor $Color_Label -nonewline
  Write-Host "$env:UserDomain\$env:UserName" -ForegroundColor $Color_Value_2
  Write-Host "PowerShell Version:".PadRight(24," ") -ForegroundColor $Color_Label -nonewline
  Write-Host $PSVersion -ForegroundColor $Color_Value_2
  Write-Host "Code Signing Cert:".PadRight(24," ") -ForegroundColor $Color_Label -nonewline
  Write-Host $Cert.FriendlyName -ForegroundColor $Color_Value_2

  if($env:PSFShowModules) {
    Write-Host "Modules:".PadRight(24," ") -foregroundcolor $Color_Label -noNewLine
    $StartingPosition = $Host.UI.RawUI.CursorPosition.X
    Write-Host "".PadRight(30,"-") -ForegroundColor $Color_Label
    
    Get-Module | Format-Wide -AutoSize | Out-String -Width $( $HostWidth -$StartingPosition -1 ) -stream | Where-Object {$_} |  ForEach-Object{ Write-Host $($(" "*$StartingPosition) + $_) -foregroundColor $Color_Value_1}
  }

  if($env:PSFShowFunctions) {
    Write-Host "Functions:".PadRight(24," ") -foregroundcolor $Color_Label -noNewLine
    $StartingPosition = $Host.UI.RawUI.CursorPosition.X
    Write-Host "".PadRight(30,"-") -ForegroundColor $Color_Label
    Get-ChildItem Scripts:CoreFunctions* -Recurse | Select-Object Name | Format-Wide -AutoSize | Out-String -Width $( $HostWidth -$StartingPosition -1 ) -stream | Where-Object {$_} |  ForEach-Object{ Write-Host $($(" "*$StartingPosition) + $($_.Replace(".ps1",""))) -foregroundColor $Color_Value_1}  
    
    $Host.UI.RawUI.ForegroundColor =$PreviousColor
    Write-Host ""
    Write-Host ""
  }

  if($env:PSFShowDrives) {
    $LogicalDisk = @()
    Get-Volume | ForEach-Object {
      $LogicalDisk += @($_ | Select-Object @{n="Name";e={$_.FriendlyName}},
      @{n="Volume Label";e={$_.DriveLetter}},
      @{n="Used (GB)";e={"{0:N2}" -f ( ($_.Size/1GB) - ($_.SizeRemaining/1GB) )}},
      @{n="Free (GB)";e={"{0:N2}" -f ($_.SizeRemaining/1GB)}},
      @{n="Size (GB)";e={"{0:N2}" -f ($_.Size/1GB)}},
      @{n="Free (%)";e={if($_.Size) { "{0:N2}" -f ( ($_.SizeRemaining/1GB) / ($_.Size/1GB) * 100 )}else{"NAN"} }} )
    } 

    Write-Host "Disks:".PadRight(24," ") -foregroundcolor $Color_Label  -noNewLine
    $StartingPosition = $Host.UI.RawUI.CursorPosition.X
    Write-Host "".PadRight(30,"-") -ForegroundColor $Color_Label
    $LogicalDisk | format-table -AutoSize |  Out-String -Width $( $HostWidth -$StartingPosition -1 ) -stream | Where-Object {$_} |  ForEach-Object{ Write-Host $($(" "*$StartingPosition) + $_) -foregroundColor $Color_Value_1}  
  }

  Write-Host "Uptime:".PadRight(24," ") -foregroundcolor $Color_Label -noNewLine
  $StartingPosition = $Host.UI.RawUI.CursorPosition.X
  if(Get-Command -Name Get-Uptime -ErrorAction SilentlyContinue) {
    $uptime = Get-Uptime
  } else {
  $uptime = Get-SystemUptime
  }
  Write-Host $uptime.days -NoNewline -ForegroundColor $Color_Label
  Write-Host " days " -NoNewline -ForegroundColor $Color_Value_2
  Write-Host $uptime.hours -NoNewline -ForegroundColor $Color_Label
  Write-Host " hours " -NoNewline -ForegroundColor $Color_Value_2
  Write-Host $uptime.minutes -NoNewline -ForegroundColor $Color_Label
  Write-Host " minutes " -NoNewline -ForegroundColor $Color_Value_2
  Write-Host $uptime.seconds -NoNewline -ForegroundColor $Color_Label
  Write-Host " seconds" -ForegroundColor $Color_Value_2  

  Write-Host "Admin Mode:`t`t" -ForegroundColor $Color_Label -nonewline
  If ($IsAdmin) {
    Write-Host "Running in admin mode"
  } else {
    Write-Host "Running in user mode"
  }  
  
  Write-Host "Location:`t`t" -ForegroundColor $Color_Label -nonewline
  Write-Host (Get-Location) -ForegroundColor $Color_Label

  if((Test-Path OneDrive:)) {
    Write-Host "OneDrive:`t`t" -ForegroundColor $Color_Label -nonewline
    Write-Host (Get-PSDrive -Name OneDrive).Root -ForegroundColor $Color_Label
  }

}

# Create configuration if missing with defaults.
if (-not (Test-Path Psf:\config.xml)) {
  $hash = @{            
      DevelopmentFolder = (Join-Path $env:USERPROFILE "dev")     
      ToolsPath = (Join-Path $env:USERPROFILE "tools")           
      WindowWidth = 150
      WindowHeight = 50
      WindowHeightBuffer = 1000
      IseColorLabel = "Cyan"
      IseColorValue1 = "Green"
      IseColorValue2 = "Yellow"
      IseFontName = "Consolas"
      IseBackgroundColor = "DarkMagenta"
      IseTextBackgroundColor = "DarkMagenta"
      IseForegroundColor = "DarkYellow"
      HostColorLabel = "Cyan"
      HostColorValue1 = "Green"
      HostColorValue2 = "Yellow"
  }     
  
  $configuration = New-Object PSObject -Property $hash
  $configuration | Export-Clixml Psf:\config.xml
}

$Global:PsfConfiguration = Import-Clixml Psf:\config.xml

# Setup tools directory and path. 
if(-not(Test-Path (Get-PsfConfig -Key ToolsPath))) {
    New-Item -Path (Get-PsfConfig -Key ToolsPath) -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
}
Add-DirectoryToPath -Directory (Get-Item -LiteralPath (Get-PsfConfig -Key ToolsPath)).FullName 

# Setup dev directory
if(-not(Test-Path (Get-PsfConfig -Key DevelopmentFolder))) {
    New-Item -Path (Get-PsfConfig -Key DevelopmentFolder) -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
}

function Set-LocationDevelopment {
  Set-LocationWithPathCheck (Get-PsfConfig -Key DevelopmentFolder)
}

function Set-LocationTools {
  Set-LocationWithPathCheck (Get-PsfConfig -Key ToolsPath)
}

set-alias cdev Set-LocationDevelopment
set-alias ctools Set-LocationTools;
set-alias sudo Start-ElevatedProcess;
set-alias reload Restart-Host;
set-alias updatepsf Update-PSF;

#
# Add variable for onedrive from registry if installed and mapping drive. Personal is the default.
#
$onedriveProperty = Get-ItemProperty -Path "hkcu:\Software\Microsoft\OneDrive\Personal" -Name UserFolder -ErrorAction SilentlyContinue
if($onedriveProperty) {
  $onedrive = $onedriveProperty.UserFolder
}

if($onedrive) {
  if (-not (Test-Path OneDrive:)) {
    New-PSDrive -name OneDrive -psprovider FileSystem -root $OneDrive -Description "OneDrive Folder" -Scope Global | Out-Null
  }
  if(-not (Test-Path "$onedrive\scripts\powershell")) {
    New-Item -Path "$onedrive\scripts\powershell" -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
  }
  Add-DirectoryToPath -Directory "$onedrive\scripts\powershell"
}

#
# Update Path to make life easier.
#
Get-Item Scripts:CoreFunctions | Where-Object { $_.PsIsContainer } | ForEach-Object {Add-DirectoryToPath -Directory "$($_.FullName)" }
Get-ChildItem Scripts:CoreFunctions* | Where-Object { $_.PsIsContainer } | ForEach-Object {Add-DirectoryToPath -Directory "$($_.FullName)" }

Show-SystemInfo

# Load the local profile. If found then load it.
if((Test-Path ".\localprofile.ps1")) {
    . .\localprofile.ps1
}

# Load the onedrive profile. If found then load it.
if($onedrive) {
  if((Test-Path "$onedrive\scripts\powershell\localprofile.ps1")) {
    . "$onedrive\scripts\powershell\localprofile.ps1"
  }  
}

# Load machine specific profie.
if((Test-Path ".\localprofile.$($env:COMPUTERNAME).ps1")) {
    . ".\localprofile.$($env:COMPUTERNAME).ps1"
}

# Load the onedrive machine specific profile. If found then load it.
if($onedrive) {
  if((Test-Path "$onedrive\scripts\powershell\localprofile.$($env:COMPUTERNAME).ps1")) {
    . "$onedrive\scripts\powershell\localprofile.$($env:COMPUTERNAME).ps1"
  }  
}

# Friendly Tips!
$tip = (Get-Content psf:\tips.txt)[(Get-Random -Minimum 0 -Maximum ((Get-Content psf:\tips.txt).Count + 1))]
Write-Host "`n-= Tip =-" -foregroundcolor $Color_Label
Write-Host " $tip `n`n"

# Fix web invoke issues by allowing multiple tls types. 
[Net.ServicePointManager]::SecurityProtocol = 
  [Net.SecurityProtocolType]::Tls12 -bor `
  [Net.SecurityProtocolType]::Tls11 -bor `
  [Net.SecurityProtocolType]::Tls

# If the retain path variable is set or in vs code pop back to the launch location. Otherwise
# stay in the profile directory.
if($env:psfretainpath -eq 'true' -or $env:TERM_PROGRAM -eq 'vscode') {
  Pop-Location
}
