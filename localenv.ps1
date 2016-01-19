cd $env:USERPROFILE 

# Internal functions that are used all over the place and not in a module. 
function elevate-process {
  $file, [string]$arguments = $args;
  $psi = new-object System.Diagnostics.ProcessStartInfo $file;
  $psi.Arguments = $arguments;
  $psi.Verb = "runas";
  $psi.WorkingDirectory = get-location;
  [System.Diagnostics.Process]::Start($psi);
}

function Get-SystemUptime ($computer = "$env:computername") {
  $lastboot = [System.Management.ManagementDateTimeconverter]::ToDateTime("$((gwmi  Win32_OperatingSystem -computername $computer).LastBootUpTime)")
  $uptime = (Get-Date) - $lastboot
  Write-Host "System Uptime for $computer is: " -NoNewline -ForegroundColor $Color_Value_2
  Write-Host $uptime.days -NoNewline -ForegroundColor $Color_Label
  Write-Host " days " -NoNewline -ForegroundColor $Color_Value_2
  Write-Host $uptime.hours -NoNewline -ForegroundColor $Color_Label
  Write-Host " hours " -NoNewline -ForegroundColor $Color_Value_2
  Write-Host $uptime.minutes -NoNewline -ForegroundColor $Color_Label
  Write-Host " minutes " -NoNewline -ForegroundColor $Color_Value_2
  Write-Host $uptime.seconds -NoNewline -ForegroundColor $Color_Label
  Write-Host " seconds" -ForegroundColor $Color_Value_2
}

function Restart-Host {
    [CmdletBinding(SupportsShouldProcess = $true,ConfirmImpact='High')]
 
    Param (
        [switch]$AsAdministrator,
        [switch]$Force
    )
    
    begin {    
        Set-StrictMode -Version Latest    
        $proc = Get-Process -Id $PID
        Write-Verbose "Restarting $($proc.Name)"    
    }    

    process {
 
        $proc = Get-Process -Id $PID
        $cmdArgs = [Environment]::GetCommandLineArgs() | Select-Object -Skip 1
    
        $params = @{ FilePath = $proc.Path }
        if ($AsAdministrator) { $params.Verb = 'runas' }
        if ($cmdArgs) { $params.ArgumentList = $cmdArgs }
    
        if ($Force -or $PSCmdlet.ShouldProcess($proc.Name,"Restart the console")) {
            if ($host.Name -eq 'Windows PowerShell ISE Host' -and $psISE.PowerShellTabs.Files.IsSaved -contains $false) {
                if ($Force -or $PSCmdlet.ShouldProcess('Unsaved work detected?','Unsaved work detected. Save changes?','Confirm')) {
                    foreach ($IseTab in $psISE.PowerShellTabs) {
                        $IseTab.Files | ForEach-Object {
                            if ($_.IsUntitled -and !$_.IsSaved) {
                                $_.SaveAs($_.FullPath,[System.Text.Encoding]::UTF8)
                            } elseif(!$_.IsSaved) {
                                $_.Save()
                            }
                        }
                    }
                } else {
                    foreach ($IseTab in $psISE.PowerShellTabs) {
                        $unsavedFiles = $IseTab.Files | Where-Object IsSaved -eq $false
                        $unsavedFiles | ForEach-Object {$IseTab.Files.Remove($_,$true)}
                    }
                }
            }
            Start-Process @params
            $proc.CloseMainWindow()
        }
    }
}


function Update-PSF {
    [CmdletBinding()]
    Param(
        [switch]$WhatIf
    )
    $cacheTime =  Get-Random
    $downloadUrl = "https://raw.github.com/sytone/PowerShellFrame/master/install.ps1?cache={0}" -f $cacheTime
    iex ((new-object net.webclient).DownloadString($downloadUrl))
    Restart-Host -Force

}

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
  Get-PSSnapin | Format-Wide -autosize | Out-String -Width $( $HostWidth -$StartingPosition -1 ) -stream | Where-Object {$_} | %{ Write-Host $($(" "*$StartingPosition) + $_) -foregroundColor $Color_Value_1} 
  
  Write-Host "Modules:".PadRight(24," ") -foregroundcolor $Color_Label -noNewLine
  $StartingPosition = $Host.UI.RawUI.CursorPosition.X
  Write-Host "".PadRight(30,"-") -ForegroundColor $Color_Label
  
  Get-Module | Format-Wide -AutoSize | Out-String -Width $( $HostWidth -$StartingPosition -1 ) -stream | Where-Object {$_} |  %{ Write-Host $($(" "*$StartingPosition) + $_) -foregroundColor $Color_Value_1}
  #Get-Module -ListAvailable | Format-Wide -Column 3 | Out-String -Width $( $HostWidth -$StartingPosition -1 ) -stream | Where-Object {$_} |  %{ Write-Host $($(" "*$StartingPosition) + $_) -foregroundColor $Color_Value_2} 
  
  Write-Host "Functions:".PadRight(24," ") -foregroundcolor $Color_Label -noNewLine
  $StartingPosition = $Host.UI.RawUI.CursorPosition.X
  Write-Host "".PadRight(30,"-") -ForegroundColor $Color_Label
  Get-ChildItem Scripts:CoreFunctions* -Recurse | Select-Object Name | Format-Wide -AutoSize | Out-String -Width $( $HostWidth -$StartingPosition -1 ) -stream | Where-Object {$_} |  %{ Write-Host $($(" "*$StartingPosition) + $($_.Replace(".ps1",""))) -foregroundColor $Color_Value_1}  
  
  $Host.UI.RawUI.ForegroundColor =$PreviousColor
  Write-Host ""
  Write-Host ""

  $LogicalDisk = @()
  gwmi Win32_LogicalDisk -filter "DriveType='3'" | % {
    $LogicalDisk += @($_ | Select @{n="Name";e={$_.Caption}},
    @{n="Volume Label";e={$_.VolumeName}},
    @{n="Used (GB)";e={"{0:N2}" -f ( ($_.Size/1GB) - ($_.FreeSpace/1GB) )}},
    @{n="Free (GB)";e={"{0:N2}" -f ($_.FreeSpace/1GB)}},
    @{n="Size (GB)";e={"{0:N2}" -f ($_.Size/1GB)}},
    @{n="Free (%)";e={if($_.Size) { "{0:N2}" -f ( ($_.FreeSpace/1GB) / ($_.Size/1GB) * 100 )}else{"NAN"} }} )
  } 

  Write-Host "Disks:".PadRight(24," ") -foregroundcolor $Color_Label  -noNewLine
  $StartingPosition = $Host.UI.RawUI.CursorPosition.X
  Write-Host "".PadRight(30,"-") -ForegroundColor $Color_Label
  $LogicalDisk | format-table -AutoSize |  Out-String -Width $( $HostWidth -$StartingPosition -1 ) -stream | Where-Object {$_} |  %{ Write-Host $($(" "*$StartingPosition) + $_) -foregroundColor $Color_Value_1}  

  Write-Host "Uptime:".PadRight(24," ") -foregroundcolor $Color_Label -noNewLine
  $StartingPosition = $Host.UI.RawUI.CursorPosition.X
  $uptime = Get-SystemUptime
  Write-Host $uptime -ForegroundColor $Color_Label

  Write-Host "Admin Mode:`t`t" -ForegroundColor $Color_Label -nonewline
  If ($IsAdmin) {
    Write-Host "Running in admin mode"
  } else {
    Write-Host "Running in user mode"
  }  
  
  Write-Host "Location:`t`t" -ForegroundColor $Color_Label -nonewline
  Write-Host (Get-Location) -ForegroundColor $Color_Label
  
}

function Add-DirectoryToPath($Directory) {
  if (-not ($ENV:PATH.Contains($Directory))) {
    $ENV:PATH += ";$Directory"
  }
}

function Set-PsfConfig($Key,$Value) {
    if($Global:PsfConfiguration.$key -eq $null) {
        $Global:PsfConfiguration | Add-Member $key $value
    } else {
        $Global:PsfConfiguration.$key = $value
    }
    $Global:PsfConfiguration | Export-Clixml Psf:\config.xml
}

function Get-PsfConfig($Key=$null) {
    if($key -eq $null) {
        $Global:PsfConfiguration
    } else {
        $Global:PsfConfiguration.$key
    }
}

function Remove-PsfConfig($Key) {
     $Global:PsfConfiguration.PSObject.Properties.Remove($key)
     $Global:PsfConfiguration | Export-Clixml Psf:\config.xml
}



function Install-Tools {
  if(-not $Global:IsAdmin) {
    Write-Host "Restart console as admin. [sudo powershell]"
    return
  }
  
  if($env:path -match "Chocolatey") {
    Write-Host "Chocolatey already installed."
  } else {
    Write-Host "Installing Chocolatey..."
    iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))
  }
  
  if($env:path -match "Boxstarter") {
    Write-Host "Boxstarter already installed."
  } else {    
    Write-Host "Installing Boxstarter..."
    CINST Boxstarter -y
  }
}


$id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$wp = new-object System.Security.Principal.WindowsPrincipal($id)
$admin = [System.Security.Principal.WindowsBuiltInRole]::Administrator
$Global:IsAdmin = $wp.IsInRole($admin)

#
# Create the drives for scripts and PSF
#
if (-not (Test-Path Scripts:)) {
  New-PSDrive -name Scripts -psprovider FileSystem -root .\Scripts\PowerShell -Description "Scripts Folder" -Scope Global | Out-Null
}

if (-not (Test-Path Psf:)) {
  New-PSDrive -name Psf -psprovider FileSystem -root (Join-Path $env:USERPROFILE "psf") -Description "PowerShellFrame Folder" -Scope Global | Out-Null
}

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

if(-not(Test-Path (Get-PsfConfig -Key ToolsPath))) {
    New-Item -Path (Get-PsfConfig -Key ToolsPath) -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
}

function Set-LocationWithPathCheck($Path) {
  if(-not (Test-Path $Path)) {
    New-Item -Path $Path -ItemType Directory
  }
  Set-Location $Path
}

function Set-LocationDevelopment {
  Set-LocationWithPathCheck (Get-PsfConfig -Key DevelopmentFolder)
}

function Set-LocationTools {
  Set-LocationWithPathCheck (Get-PsfConfig -Key ToolsPath)
}

function Update-PsfGit($m = "Lazy hack and commit") {
    Push-Location (Join-Path (Get-PsfConfig -Key DevelopmentFolder) "PowerShellFrame")
    git add .
    git commit -m $m
    git push
    Pop-Location
}

set-alias cdev Set-LocationDevelopment;
set-alias ctools Set-LocationTools;
set-alias sudo elevate-process;
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
          $event.sender | % {
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
# Pull the scripts into the modules path for easy load. This will mean ability to sync between machines in the future. 
#
if ( -not ($Env:PSModulepath.Contains($(Convert-Path Scripts:CoreModulesManual)) )) {
  $env:PSMODULEPATH += ";" + $(Convert-Path Scripts:CoreModulesManual) 
}

if ( -not ($Env:PSModulepath.Contains($(Convert-Path Scripts:CoreModulesAuto)) )) {
  $env:PSMODULEPATH += ";" + $(Convert-Path Scripts:CoreModulesAuto) 
}

#
# Import my auto modules. This is everything in the CoreModulesAuto folder. One folder per module. 
#
Get-ChildItem $(Convert-Path Scripts:CoreModulesAuto) | Where-Object {$_.PsIsContainer} | %{ 
  Import-Module $($_.FullName) -Force | out-null
}

#
# Update Path to make life easier.
#
Get-Item Scripts:CoreFunctions | ? { $_.PsIsContainer } | % {Add-DirectoryToPath -Directory "$($_.FullName)" }
Get-ChildItem Scripts:CoreFunctions* | ? { $_.PsIsContainer } | % {Add-DirectoryToPath -Directory "$($_.FullName)" }


# Setup the prompt
function Global:prompt {
  # The at sign creates an array in case only one history item exists.
  $history = @(get-history)
  if($history.Count -gt 0) {
    $lastItem = $history[$history.Count - 1]
    $lastId = $lastItem.Id
  }
  $nextCommand = $lastId + 1
  Write-Host "PS: $nextCommand $($executionContext.SessionState.Path.CurrentLocation)" -ForegroundColor Gray
  "$('#' * ($nestedPromptLevel + 1)) "
}

Show-SystemInfo

if((Test-Path ".\localprofile.ps1")) {
    . .\localprofile.ps1
}