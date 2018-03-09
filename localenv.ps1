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
  $PSVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo("$PSHome\Powershell.exe").FileVersion
  $IPAddress = @( Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object { $_.DefaultIpGateway } )[0].IPAddress[0]
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

  Write-Host "Snapins:".PadRight(24," ") -ForegroundColor $Color_Label -NoNewline
  $StartingPosition = $Host.UI.RawUI.CursorPosition.X
  Write-Host "".PadRight(30,"-") -ForegroundColor $Color_Label
  Get-PSSnapin | Format-Wide -autosize | Out-String -Width $( $HostWidth -$StartingPosition -1 ) -stream | Where-Object {$_} | ForEach-Object{ Write-Host $($(" "*$StartingPosition) + $_) -foregroundColor $Color_Value_1} 
  
  Write-Host "Modules:".PadRight(24," ") -foregroundcolor $Color_Label -noNewLine
  $StartingPosition = $Host.UI.RawUI.CursorPosition.X
  Write-Host "".PadRight(30,"-") -ForegroundColor $Color_Label
  
  Get-Module | Format-Wide -AutoSize | Out-String -Width $( $HostWidth -$StartingPosition -1 ) -stream | Where-Object {$_} |  ForEach-Object{ Write-Host $($(" "*$StartingPosition) + $_) -foregroundColor $Color_Value_1}
  
  Write-Host "Functions:".PadRight(24," ") -foregroundcolor $Color_Label -noNewLine
  $StartingPosition = $Host.UI.RawUI.CursorPosition.X
  Write-Host "".PadRight(30,"-") -ForegroundColor $Color_Label
  Get-ChildItem Scripts:CoreFunctions* -Recurse | Select-Object Name | Format-Wide -AutoSize | Out-String -Width $( $HostWidth -$StartingPosition -1 ) -stream | Where-Object {$_} |  ForEach-Object{ Write-Host $($(" "*$StartingPosition) + $($_.Replace(".ps1",""))) -foregroundColor $Color_Value_1}  
  
  $Host.UI.RawUI.ForegroundColor =$PreviousColor
  Write-Host ""
  Write-Host ""

  $LogicalDisk = @()
  Get-WmiObject Win32_LogicalDisk -filter "DriveType='3'" | ForEach-Object {
    $LogicalDisk += @($_ | Select-Object @{n="Name";e={$_.Caption}},
    @{n="Volume Label";e={$_.VolumeName}},
    @{n="Used (GB)";e={"{0:N2}" -f ( ($_.Size/1GB) - ($_.FreeSpace/1GB) )}},
    @{n="Free (GB)";e={"{0:N2}" -f ($_.FreeSpace/1GB)}},
    @{n="Size (GB)";e={"{0:N2}" -f ($_.Size/1GB)}},
    @{n="Free (%)";e={if($_.Size) { "{0:N2}" -f ( ($_.FreeSpace/1GB) / ($_.Size/1GB) * 100 )}else{"NAN"} }} )
  } 

  Write-Host "Disks:".PadRight(24," ") -foregroundcolor $Color_Label  -noNewLine
  $StartingPosition = $Host.UI.RawUI.CursorPosition.X
  Write-Host "".PadRight(30,"-") -ForegroundColor $Color_Label
  $LogicalDisk | format-table -AutoSize |  Out-String -Width $( $HostWidth -$StartingPosition -1 ) -stream | Where-Object {$_} |  ForEach-Object{ Write-Host $($(" "*$StartingPosition) + $_) -foregroundColor $Color_Value_1}  

  Write-Host "Uptime:".PadRight(24," ") -foregroundcolor $Color_Label -noNewLine
  $StartingPosition = $Host.UI.RawUI.CursorPosition.X
  $uptime = Get-SystemUptime
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


#
# NEed to workout where tools and dev items go...
#
function Install-Tools {
  if(-not $Global:IsAdmin) {
    Write-Host "Restart console as admin. [sudo powershell]"
    return
  }
  
  if($env:path -match "Chocolatey") {
    Write-Host "Chocolatey already installed."
  } else {
    Write-Host "Installing Chocolatey..."
    Invoke-Expression ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))
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

switch ( $Host.Name ) {
    'Windows PowerShell ISE Host' {
        $Global:Color_Label = $Global:PsfConfiguration.IseColorLabel
        $Global:Color_Value_1 = $Global:PsfConfiguration.IseColorValue1
        $Global:Color_Value_2 = $Global:PsfConfiguration.IseColorValue2
        $HostWidth = 80

        Import-Module ISEPack 

        $PSISE.options.FontName = $Global:PsfConfiguration.IseFontName
        $psise.Options.ConsolePaneBackgroundColor = $Global:PsfConfiguration.IseBackgroundColor
        $psise.Options.ConsolePaneTextBackgroundColor = $Global:PsfConfiguration.IseTextBackgroundColor
        $psise.Options.ConsolePaneForegroundColor = $Global:PsfConfiguration.IseForegroundColor

        # watch for changes to the Files collection of the current Tab
        register-objectevent $psise.CurrentPowerShellTab.Files collectionchanged -action {
          # iterate ISEFile objects
          $event.sender | ForEach-Object {
            # set private field which holds default encoding to ASCII
            $_.gettype().getfield("encoding","nonpublic,instance").setvalue($_, [text.encoding]::ascii)
          }
        } | Out-null
    }
    default
    {
      $pshost = get-host
      $global:ConsoleHost = ($pshost.Name -eq "ConsoleHost")
      $pswindow = $pshost.ui.rawui
      
      #Setup console colours I like!
      #$pswindow.ForegroundColor = "Green"
      #Write-Host $pswindow.BackgroundColor
      #$pswindow.BackgroundColor = "Black"
      if($pswindow.buffersize.height -le $Global:PsfConfiguration.WindowHeightBuffer -and $pswindow.buffersize.width -le $Global:PsfConfiguration.WindowWidth ) {
            trap {Continue}
            $newsize = $pswindow.buffersize
            $newsize.height = $Global:PsfConfiguration.WindowHeightBuffer
            $newsize.width = $Global:PsfConfiguration.WindowWidth
            $pswindow.buffersize = $newsize
      }
      
      if($pswindow.windowsize.height -le $Global:PsfConfiguration.WindowHeight -and $pswindow.windowsize.width -le $Global:PsfConfiguration.WindowWidth ) {
            trap {Continue}
            $newsize = $pswindow.windowsize
            $newsize.height = $Global:PsfConfiguration.WindowHeight
            $newsize.width = $Global:PsfConfiguration.WindowWidth
            $pswindow.windowsize = $newsize            
      }

      $Global:Color_Label = $Global:PsfConfiguration.HostColorLabel
      $Global:Color_Value_1 = $Global:PsfConfiguration.HostColorValue1
      $Global:Color_Value_2 = $Global:PsfConfiguration.HostColorValue2
      $HostWidth = $Host.UI.RawUI.WindowSize.Width
      
      # Set a nice title for the window. 
      if(!$global:WindowTitlePrefix) {
        if ($IsAdmin) {
          $global:WindowTitlePrefix = "PowerShell (ADMIN) - "
        } else {
          $global:WindowTitlePrefix = "PowerShell - "
        }
      }
      
      $pswindow.WindowTitle = "$($global:WindowTitlePrefix) [Local Environment]"
    }
}

#
# Add variable for onedrive from registry if installed and mapping drive.  
#
$onedriveProperty = Get-ItemProperty -Path "hkcu:\Software\Microsoft\OneDrive\" -Name UserFolder -ErrorAction SilentlyContinue
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

# Setup the prompt
function Global:prompt {
  $realLASTEXITCODE = $LASTEXITCODE
  # The at sign creates an array in case only one history item exists.
  $history = @(get-history)
  if($history.Count -gt 0) {
    $lastItem = $history[$history.Count - 1]
    $lastId = $lastItem.Id
  }
  $nextCommand = $lastId + 1
  Write-Host "PS: $nextCommand $($executionContext.SessionState.Path.CurrentLocation)" -ForegroundColor Gray
  if(Get-Module -Name posh-git) {
    Write-VcsStatus
  }
  "$('#' * ($nestedPromptLevel + 1)) "


  $global:LASTEXITCODE = $realLASTEXITCODE  
}

Show-SystemInfo

# Load the local profile. If found then load it. 
if((Test-Path ".\localprofile.ps1")) {
    . .\localprofile.ps1
}

# Load machine specific profie. this is not backed up using One Drive. 
if((Test-Path ".\localprofile.$($env:COMPUTERNAME).ps1")) {
    . ".\localprofile.$($env:COMPUTERNAME).ps1"
}

function Install-Cmder {
  $miniInstallSource = 'https://github.com/cmderdev/cmder/releases/download/v1.3.2/cmder_mini.zip'
  $fullInstallSource = 'https://github.com/cmderdev/cmder/releases/download/v1.3.2/cmder.zip'
  $enableCmder = [bool](Read-Choice "Do you want to enable the cmder - http://cmder.net/ ?" "&No","&Yes" -Default 1)
  if($enableCmder) {
    $installFull = [bool](Read-Choice "Do you want to install the Full or Mini version?" "&Mini","&Full" -Default 1)
    Write-Host "Installing CMDER to tools. Please wait..."

    $path = Join-Path (Get-PsfConfig -Key ToolsPath) "cmder"
    if(!(Test-Path $path)) {New-Item -Path $path -ItemType Directory | Out-Null }
    if($installFull) {
      Invoke-WebRequest -Uri $miniInstallSource -OutFile (Join-Path $path 'cmder.zip')
    } else {
      Invoke-WebRequest -Uri $miniInstallSource -OutFile (Join-Path $path 'cmder.zip')
    }
    Expand-Archive -Path (Join-Path $path 'cmder.zip') -DestinationPath $path
    $TargetFile = (Join-Path $path 'cmder.exe')
    $ShortcutFile = Join-Path (Get-PsfConfig -Key ToolsPath) "cmder.cmd"
    "@ECHO OFF`n$TargetFile" | Out-File -FilePath $ShortcutFile -Force -Encoding ascii
    
    # Update the profile so PSF loads in CMDER
    $cmderProfile = Join-Path (Get-PsfConfig -Key ToolsPath) "cmder\config\user-profile.ps1"
    $psfLocalRoot =  Join-Path $env:USERPROFILE "psf"
    $envLoadLine = "`n. $psfLocalRoot\localenv.ps1   #LOCALENV - May change in future`n"
    New-Item $cmderProfile -type file -force -ea 0 | Out-Null
    $envLoadLine | Set-Content  ($cmderProfile)
    
    # Remove old PSGet
    $psgetPath = Join-Path (Join-Path (Join-Path (Join-Path (Get-PsfConfig -Key ToolsPath) "cmder") "vendor") "psmodules") "PsGet"
    Remove-Item $psgetPath -Recurse -Force | Out-Null
    Set-PsfConfig -Key 'CMDER_ENABLED' -Value 'enabled'
}

#Install cmder?
if((Get-PsfConfig -Key 'CMDER_ENABLED') -eq 'unknown' -or (Get-PsfConfig -Key 'CMDER_ENABLED') -eq $null) {
    Install-Cmder
  } else {
    Set-PsfConfig -Key 'CMDER_ENABLED' -Value 'disabled'
  }
}

#TODO
# Visual Studio Code check and Install
#  choco install VisualStudioCode -y
# GIT check and install 
#  choco install git -y

# Friendly Tips!
$tip = (Get-Content psf:\tips.txt)[(Get-Random -Minimum 0 -Maximum ((Get-Content psf:\tips.txt).Count + 1))]
Write-Host "`n-= Tip =-" -foregroundcolor $Color_Label
Write-Host " $tip `n`n"

if($env:psfretainpath -eq 'true' -or $env:TERM_PROGRAM -eq 'vscode') {
  Pop-Location
}
