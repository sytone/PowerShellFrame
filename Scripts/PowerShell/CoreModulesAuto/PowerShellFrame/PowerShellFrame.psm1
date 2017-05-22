#requires -version 4

<#
.SYNOPSIS
  Starts the remote desktop process with options set. 

.DESCRIPTION
  Allows you to start a remote desktop process and set options not made avliable
  by mstsc like the gateway host name. 

.PARAMETER FullAddress
  A valid computer name, IPv4 address, or IPv6 address - Specifies the remote computer to which you want to connect

.PARAMETER FullScreen
  If specified remote desktop will be full screen.

.PARAMETER Resolution
  Screen resolution if not full screen. 1024x768 by default.

.PARAMETER UseMultimon
  Use all monitors.

.PARAMETER GatewayHostName
  Use a gateway for the connection.
  
.PARAMETER UserName
  Username to use to log into the remote computer. 

.INPUTS
  None

.OUTPUTS
  None

.NOTES
  Version:        1.0
  Author:         Sytone
  Creation Date:  1/18/2016
  Purpose/Change: Initial script development

.EXAMPLE
  Connect-RemoteDesktop -FullAddress mrserver -FullScreen -UseMultimon
  
  Connect-RemoteDesktop -FullAddress mrserver -FullScreen -UseMultimon -GatewayHostName my.gateway.com
#>
 function Connect-RemoteDesktop {
    [CmdletBinding()]
 
    Param (
        [Parameter(Mandatory=$True,HelpMessage="A valid computer name, IPv4 address, or IPv6 address - Specifies the remote computer to which you want to connect")]
        [string]$FullAddress,
        [Parameter(HelpMessage="If specified remote desktop will be full screen.")]
        [switch]$FullScreen,
        [Parameter(HelpMessage="Screen resolution if not full screen. 1024x768 by default.")]
        [string]$Resolution = "1024x768",
        [Parameter(HelpMessage="Use all monitors.")]
        [Switch]$UseMultimon,
        [Parameter(HelpMessage="Use a gateway for the connection.")]
        [String]$GatewayHostName,
        [Parameter(HelpMessage="Username to use to log into the remote computer.")]
        [String]$UserName
    )
    
    begin { 
    }    

    process {
        if($FullScreen) {
            $screenmodeid = "2"
        } else {
            $screenmodeid = "1"
        }
        
        if($Resolution -match 'x') {
            $width = $Resolution.Split('x')[0]
            $height = $Resolution.Split('x')[1] 
        }
        
        if($UseMultimon) {
            $multiMon = "use multimon:i:1"
            $screenmodeid = "2"
        } else {
            $multiMon = "use multimon:i:0"
        }

$rdpString = @"
screen mode id:i:$screenmodeid
$multiMon
desktopwidth:i:$width
desktopheight:i:$height
session bpp:i:32
winposstr:s:0,3,0,0,800,600
compression:i:1
keyboardhook:i:2
audiocapturemode:i:0
videoplaybackmode:i:1
connection type:i:7
networkautodetect:i:1
bandwidthautodetect:i:1
displayconnectionbar:i:1
enableworkspacereconnect:i:0
disable wallpaper:i:0
allow font smoothing:i:0
allow desktop composition:i:0
disable full window drag:i:1
disable menu anims:i:1
disable themes:i:0
disable cursor setting:i:0
bitmapcachepersistenable:i:1
full address:s:$FullAddress
audiomode:i:2
redirectprinters:i:0
redirectcomports:i:0
redirectsmartcards:i:1
redirectclipboard:i:1
redirectposdevices:i:0
autoreconnection enabled:i:1
authentication level:i:2
prompt for credentials:i:0
negotiate security layer:i:1
remoteapplicationmode:i:0
alternate shell:s:
shell working directory:s:
gatewayhostname:s:$GatewayHostName
gatewayusagemethod:i:2
gatewaycredentialssource:i:4
gatewayprofileusagemethod:i:1
promptcredentialonce:i:0
gatewaybrokeringtype:i:0
use redirection server name:i:0
rdgiskdcproxy:i:0
kdcproxyname:s:
drivestoredirect:s:
"@ 
        if($UserName) {
            $rdpString += "username:s:$UserName`n"
        }
        $f = New-TemporaryFile
        $rdpFile = "{0}.rdp" -f $f.FullName
        $rdpString | Set-Content $rdpFile
        Start-Process $rdpFile
    }
 }
 
<#
.SYNOPSIS
    Uses the PS tokenize process to parse out all the commands to be executed
.DESCRIPTION
    Creates a alias that can take params like UNIX alias command, it will
    also place the $arg at the end so you can add commands. 
.EXAMPLE
    C:\PS> alias fred=start-process winword
    C:\PS> fred helloworld.docx
    
    This will start work with whatever you add at the end. 

[System.Management.Automation.PSParser]::Tokenize("cd -Path ..; dir -Path c:; get-ChildItem -Path d:",[ref]$null)
Resolve-Aliases "cd -Path ..; dir -Path c:; get-ChildItem -Path d:"
Set-Location Get-ChildItemth ..; dir -Path c:; get-ChildItem -Path d:

#>
function script:Resolve-Aliases {
    param($line)
    $newCommandLine = ""
    # Replaice the Aliases with the full internal command. 
    [System.Management.Automation.PSParser]::Tokenize($line,[ref]$null) | ForEach-Object {
        $type = $_.Type
        $content = $_.Content
        switch ($type) { 
            "Command" {            
                $cmd = @(Get-Command $content)[0]
                if($cmd.CommandType -eq "Alias") {
                    $newCommandLine += $cmd.Definition
                    #$line = $line.Remove( $_.StartColumn -1, $_.Length ).Insert( $_.StartColumn -1, $cmd.Definition )
                } else {
                    $newCommandLine += $content
                }
            } 
            "CommandParameter" {$newCommandLine += $content} 
            "CommandArgument" {$newCommandLine += $content} 
            "StatementSeparator" {$newCommandLine += $content} 
            "String" {$newCommandLine += "`"" + $content + "`""} 
            default {$newCommandLine += $content}
        }        
        $newCommandLine += " "
    }
    $newCommandLine
}

<#
.SYNOPSIS
    Creates a alias that can take params lik UNIX
.DESCRIPTION
    Creates a alias that can take params like UNIX alias command, it will
    also place the $arg at the end so you can add commands. The use or arguments 
    only works on simple commands and it is passed in as a argument array (Splat)
.EXAMPLE
    C:\PS> alias fred=start-process winword
    C:\PS> fred helloworld.docx
    
    This will start work with whatever you add at the end. 
#>
function alias {
    
    # pull together all the args and then split on =
    $alias,$cmd = [string]::join(" ",$args).split("=",2) | ForEach-Object { $_.trim()}
    $cmd = Resolve-Aliases $cmd
    if((Get-Item "function:\Alias$Alias" -ErrorAction SilentlyContinue)) { 
        Write-Host "Alias ($alias) exists, please remove first. ( unalias $alias ) ."
        return
    }
    $f = New-Item -Path function: -Name "Global:Alias$Alias" -Options "AllScope" -Value @"
Invoke-Expression '$cmd `@args '
    ###ALIAS###
"@ 
    # Invoke-Expression '$cmd `$args'

    $a = Set-Alias -Name $Alias -Value "Alias$Alias" -Description "A UNIX-style alias using functions" -Option "AllScope" -scope Global -passThru 
}

function unalias([string]$Alias,[switch]$Force){ 
    if( (Get-Alias $Alias).Description -eq "A UNIX-style alias using functions" ) {
       Remove-Item "function:Alias$Alias" -Force:$Force
       Remove-Item "alias:$alias" -Force:$Force
       if($?) {
          "Removed alias '$Alias' and accompanying function"
       }
    } else {
       Remove-Item "alias:$alias" -Force:$Force
       if($?) {
          "Removed alias '$Alias'"
       }
    }
}


#.Synopsis
#  Prompt the user for a choice, and return the (0-based) index of the selected item
#.Parameter Message
#  This is the prompt that will be presented to the user. Basically, the question you're asking.
#.Parameter Choices
#  An array of strings representing the choices (or menu items), with optional ampersands (&) in them to mark (unique) characters which can be used to select each item.
#.Parameter ChoicesWithHelp
#  A Hashtable where the keys represent the choices (or menu items), with optional ampersands (&) in them to mark (unique) characters which can be used to select each item, and the values represent help text to be displayed to the user when they ask for help making their decision.
#.Parameter Default
#  The (0-based) index of the menu item to select by default (defaults to zero).
#.Parameter MultipleChoice
#  Prompt the user to select more than one option. This changes the prompt display for the default PowerShell.exe host to show the options in a column and allows them to choose multiple times.
#  Note: when you specify MultipleChoice you may also specify multiple options as the default!
#.Parameter Caption
#  An additional caption that can be displayed (usually above the Message) as part of the prompt
#.Parameter Passthru
#  Causes the Choices objects to be output instead of just the indexes
#.Example
#  Read-Choice "WEBPAGE BUILDER MENU"  "&Create Webpage","&View HTML code","&Publish Webpage","&Remove Webpage","E&xit"
#.Example
#  [bool](Read-Choice "Do you really want to do this?" "&No","&Yes" -Default 1)
#  
#  This example takes advantage of the 0-based index to convert No (0) to False, and Yes (1) to True. It also specifies YES as the default, since that's the norm in PowerShell.
#.Example
#  Read-Choice "Do you really want to delete them all?" @{"&No"="Do not delete all files. You will be prompted to delete each file individually."; "&Yes"="Confirm that you want to delete all of the files"}
#  
#  Note that with hashtables, order is not guaranteed, so "Yes" will probably be the first item in the prompt, and thus will output as index 0.  Because of thise, when a hashtable is passed in, we default to Passthru output.
function Read-Choice {
    [CmdletBinding(DefaultParameterSetName="HashtableWithHelp")]
    param(
    [Parameter(Mandatory=$true, Position = 10, ParameterSetName="HashtableWithHelp")]
    [Hashtable]$ChoicesWithHelp
    ,   
    [Parameter(Mandatory=$true, Position = 10, ParameterSetName="StringArray")]
    [String[]]$Choices
    ,
    [Parameter(Mandatory=$False)]
    [string]$Caption = "Please choose!"
    ,  
    [Parameter(Mandatory=$False, Position=0)]
    [string]$Message = "Choose one of the following options:"
    ,  
    [Parameter(Mandatory=$False)]
    [int[]]$Default  = 0
    ,  
    [Switch]$MultipleChoice
    ,
    [Switch]$Passthru
    )
    begin {
        if($ChoicesWithHelp) { 
            [System.Collections.DictionaryEntry[]]$choices = $ChoicesWithHelp.GetEnumerator() | %{$_}
        }
    }
    process {
        $Descriptions = [System.Management.Automation.Host.ChoiceDescription[]]( $(
                        if($choices -is [String[]]) {
                            foreach($choice in $choices) {
                            New-Object System.Management.Automation.Host.ChoiceDescription $choice
                            } 
                        } else {
                            foreach($choice in $choices) {
                            New-Object System.Management.Automation.Host.ChoiceDescription $choice.Key, $choice.Value
                            } 
                        }
                    ) )
                    
        # Passing an array as the $Default triggers multiple choice prompting.
        if(!$MultipleChoice) { [int]$Default = $Default[0] }

        [int[]]$Answer = $Host.UI.PromptForChoice($Caption,$Message,$Descriptions,$Default)

        if($Passthru -or !($choices -is [String[]])) {
            Write-Verbose "$Answer"
            Write-Output  $Descriptions[$Answer]
        } else {
            Write-Output $Answer
        }
    }

}
 
<#
.SYNOPSIS
Runs a process elevated. 

.DESCRIPTION
Uses the diagnostics process start to start a new process as elevated for the user. Returns the process 
to the calling function for tracking.   

.PARAMETER file 
The first param is the file to execute. 

.PARAMETER args
args are added as arguments after conversion to a string. 

.EXAMPLE
Start a new powershell instance that is elevated. 
Start-ElevatedProcess powershell

.NOTES
You need to have admin access to actually run the process as elevated. You may get a UAC prompt. 
#>
function Start-ElevatedProcess {
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
  return $uptime
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

 

function Add-DirectoryToPath($Directory) {
    $env_Path = [System.Environment]::GetEnvironmentVariable("Path", "User")
    if (($env_Path -split ';') -notcontains "$Directory") {
    if ($env_Path) {
        $env_Path = $env_Path + ';'
    }
    $env_Path += "$Directory"
    [System.Environment]::SetEnvironmentVariable("Path", $env_Path, "User")
    $env:Path = $env_Path 
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



function Set-LocationWithPathCheck($Path) {
  if(-not (Test-Path $Path)) {
    New-Item -Path $Path -ItemType Directory
  }
  Set-Location $Path
}

function Update-PsfGit($m = "Lazy hack and commit") {
    Push-Location (Join-Path (Get-PsfConfig -Key DevelopmentFolder) "PowerShellFrame")
    git add .
    git commit -m $m
    git push
    Pop-Location
}

function Get-PsfGit($m = "Lazy hack and commit") {
    Push-Location (Join-Path (Get-PsfConfig -Key DevelopmentFolder) "PowerShellFrame")
    git pull
    Pop-Location
}

function Initialize-PsfGit() {
  $cloneRoot = (Join-Path (Get-PsfConfig -Key DevelopmentFolder) "PowerShellFrame")
  if(!(Test-Path $cloneRoot)) {New-Item -Path $cloneRoot -ItemType Directory | Out-Null }
  git clone "https://github.com/sytone/PowerShellFrame.git" $cloneRoot
}


function Backup-Customizations() {
  # This will backup all the customizations for the PSF world to make it easy to restore. 
  # Depends on OneDrive and OneDrive Syncronization. 
  $x = (get-item OneDrive:\PSFSync)
  $syncRoot = "$($x.FullName)"
  pushd $env:USERPROFILE

  if(-not (Test-Path OneDrive:\)) {
    Write-Host "Unable to backup in OneDrive. Not mapped or setup." -ForegroundColor Red
    return
  }

  if(-not (Test-Path $syncRoot)) {
    New-Item -Path $syncRoot -ItemType Directory | Out-Null 
  }

  # Backup CMDER XML.
  Write-Host "Backing up ConEmu.xml..."
  $cmderProfile = Join-Path (Get-PsfConfig -Key ToolsPath) "cmder\vendor\conemu-maximus5\ConEmu.xml"
  Copy-Item -Path $cmderProfile -Destination $syncRoot -Force

  Write-Host "Backing up local profile... (Not localprofile.$($env:COMPUTERNAME).ps1)"
  Copy-Item -Path .\localprofile.ps1 -Destination $syncRoot -Force

  Write-Host "Backing up Code Modules Auto"
  $x = (get-item Scripts:\CoreModulesAuto)
  ROBOCOPY /E "$($x.FullName)" "$(Join-Path $syncRoot 'CoreModulesAuto')" | Out-Null
  
  Write-Host "Backing up Core Functions"
  $x = (get-item Scripts:\CoreFunctions)
  ROBOCOPY /E "$($x.FullName)" "$(Join-Path $syncRoot 'CoreFunctions')" | Out-Null
  #Copy-Item -Path Scripts:\CoreFunctions\*.* -Destination (Join-Path $syncRoot "CoreFunctions") -Recurse -Force
  #Copy-Item -Path Scripts:\CoreModulesAuto\*.* -Destination (Join-Path $syncRoot "CoreModulesAuto") -Recurse -Force
  Remove-Item -Path (Join-Path $syncRoot "CoreModulesAuto\AutoHotkey") -Recurse -Force | Out-Null
  Remove-Item -Path (Join-Path $syncRoot "CoreModulesAuto\PowerShellFrame") -Recurse -Force | Out-Null
  popd
}

function Restore-Customizations() {
  $x = (get-item OneDrive:\PSFSync)
  $syncRoot = "$($x.FullName)"

  if(-not (Test-Path $syncRoot)) {
    Write-Host "Unable to find backup in OneDrive." -ForegroundColor Red
    return
  }
  pushd $env:USERPROFILE


  $cmderProfile = Join-Path (Get-PsfConfig -Key ToolsPath) "cmder\vendor\conemu-maximus5\ConEmu.xml"
  Write-Host "Restoring ConEmu.xml..."
  Copy-Item -Path (Join-Path $syncRoot "ConEmu.xml") -Destination $cmderProfile -Force  

  Write-Host "Restoring local profile..."
  Copy-Item -Path (Join-Path $syncRoot 'localprofile.ps1') -Destination .\localprofile.ps1 -Force

  $x = (get-item Scripts:\CoreModulesAuto)
  Write-Host "Restoring Core Modules Auto..."
  ROBOCOPY /E "$(Join-Path $syncRoot 'CoreModulesAuto')" "$($x.FullName)" | Out-Null
  
  $x = (get-item Scripts:\CoreFunctions)
  Write-Host "Restoring Core Functions..."
  ROBOCOPY /E "$(Join-Path $syncRoot 'CoreFunctions')" "$($x.FullName)" | Out-Null
  popd
}