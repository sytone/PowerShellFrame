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

###
# PSF Coding Helpers. 
###
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

function Test-PsfChanges () {
    $cloneRoot = (Join-Path (Get-PsfConfig -Key DevelopmentFolder) "PowerShellFrame")
    
    $ScriptsRoot = (Join-Path $env:USERPROFILE "Scripts")  
    $PowerShellScriptsRoot = (Join-Path $ScriptsRoot "PowerShell")  
    Remove-Item (Join-Path $PowerShellScriptsRoot "CoreModulesAuto\PowerShellFrame\PowerShellFrame.psm1") -force | Out-Null
    Copy-Item (Join-Path $cloneRoot "Scripts\PowerShell\CoreModulesAuto\PowerShellFrame\PowerShellFrame.psm1")  (Join-Path $PowerShellScriptsRoot "CoreModulesAuto\PowerShellFrame\PowerShellFrame.psm1") -Force

    $psfLocalRoot =  Join-Path $env:USERPROFILE "psf"
    Remove-Item "$psfLocalRoot\localenv.ps1" -Force | Out-Null
    Copy-Item (Join-Path $cloneRoot "localenv.ps1")  "$psfLocalRoot\localenv.ps1" -Force
    
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

###
# UI Helpers
# From: http://blog.danskingdom.com/powershell-multi-line-input-box-dialog-open-file-dialog-folder-browser-dialog-input-box-and-message-box/
###

<#
.SYNOPSIS
    Show message box popup and return the button clicked by the user.
.DESCRIPTION
    Long description
.EXAMPLE
    $buttonClicked = Read-MessageBoxDialog -Message "Please press the OK button." -WindowTitle "Message Box Example" -Buttons OKCancel -Icon Exclamation
    if ($buttonClicked -eq "OK") { Write-Host "Thanks for pressing OK" }
    else { Write-Host "You clicked $buttonClicked" }
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
#>
function Read-MessageBoxDialog() {
    param(
        [string]$Message, 
        [string]$WindowTitle, 
        [System.Windows.Forms.MessageBoxButtons]$Buttons = [System.Windows.Forms.MessageBoxButtons]::OK, 
        [System.Windows.Forms.MessageBoxIcon]$Icon = [System.Windows.Forms.MessageBoxIcon]::None
    )
    Add-Type -AssemblyName System.Windows.Forms
    return [System.Windows.Forms.MessageBox]::Show($Message, $WindowTitle, $Buttons, $Icon)
}

<#
.SYNOPSIS
    Show input box popup and return the value entered by the user.
.DESCRIPTION
    Long description
.EXAMPLE
    $textEntered = Read-InputBoxDialog -Message "Please enter the word 'Banana'" -WindowTitle "Input Box Example" -DefaultText "Apple"
    if ($textEntered -eq $null) { Write-Host "You clicked Cancel" }
    elseif ($textEntered -eq "Banana") { Write-Host "Thanks for typing Banana" }
    else { Write-Host "You entered $textEntered" }
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
#>
function Read-InputBoxDialog() {
    param(
        [string]$Message, 
        [string]$WindowTitle, 
        [string]$DefaultText
    )
    Add-Type -AssemblyName Microsoft.VisualBasic
    return [Microsoft.VisualBasic.Interaction]::InputBox($Message, $WindowTitle, $DefaultText)
}

<#
.SYNOPSIS
    Show an Open File Dialog and return the file selected by the user.
.DESCRIPTION
    Long description
.EXAMPLE
    $filePath = Read-OpenFileDialog -WindowTitle "Select Text File Example" -InitialDirectory 'C:\' -Filter "Text files (*.txt)|*.txt"
    if (![string]::IsNullOrEmpty($filePath)) { Write-Host "You selected the file: $filePath" }
    else { "You did not select a file." }
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
#>
function Read-OpenFileDialog() {  
    param(
        [string]$WindowTitle, 
        [string]$InitialDirectory, 
        [string]$Filter = "All files (*.*)|*.*", 
        [switch]$AllowMultiSelect
    )
    Add-Type -AssemblyName System.Windows.Forms
    $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openFileDialog.Title = $WindowTitle
    if (![string]::IsNullOrWhiteSpace($InitialDirectory)) { $openFileDialog.InitialDirectory = $InitialDirectory }
    $openFileDialog.Filter = $Filter
    if ($AllowMultiSelect) { $openFileDialog.MultiSelect = $true }
    $openFileDialog.ShowHelp = $true    # Without this line the ShowDialog() function may hang depending on system configuration and running from console vs. ISE.
    $openFileDialog.ShowDialog() > $null
    if ($AllowMultiSelect) { return $openFileDialog.Filenames } else { return $openFileDialog.Filename }
}


<#
.SYNOPSIS
    Show an Open Folder Dialog and return the directory selected by the user.
.DESCRIPTION
    Long description
.EXAMPLE
    $directoryPath = Read-FolderBrowserDialog -Message "Please select a directory" -InitialDirectory 'C:\' -NoNewFolderButton
    if (![string]::IsNullOrEmpty($directoryPath)) { Write-Host "You selected the directory: $directoryPath" }
    else { "You did not select a directory." }
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
#>
function Read-FolderBrowserDialog() {
    param(
        [string]$Message, 
        [string]$InitialDirectory, 
        [switch]$NoNewFolderButton
    )
    $browseForFolderOptions = 0
    if ($NoNewFolderButton) { $browseForFolderOptions += 512 }
 
    $app = New-Object -ComObject Shell.Application
    $folder = $app.BrowseForFolder(0, $Message, $browseForFolderOptions, $InitialDirectory)
    if ($folder) { $selectedDirectory = $folder.Self.Path } else { $selectedDirectory = '' }
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($app) > $null
    return $selectedDirectory
}

<#
    .SYNOPSIS
    Prompts the user with a multi-line input box and returns the text they enter, or null if they cancelled the prompt.
     
    .DESCRIPTION
    Prompts the user with a multi-line input box and returns the text they enter, or null if they cancelled the prompt.
     
    .PARAMETER Message
    The message to display to the user explaining what text we are asking them to enter.
     
    .PARAMETER WindowTitle
    The text to display on the prompt window's title.
     
    .PARAMETER DefaultText
    The default text to show in the input box.
     
    .EXAMPLE
    $userText = Read-MultiLineInputDialog "Input some text please:" "Get User's Input"
     
    Shows how to create a simple prompt to get mutli-line input from a user.
     
    .EXAMPLE
    # Setup the default multi-line address to fill the input box with.
    $defaultAddress = @'
    John Doe
    123 St.
    Some Town, SK, Canada
    A1B 2C3
    '@
     
    $address = Read-MultiLineInputDialog "Please enter your full address, including name, street, city, and postal code:" "Get User's Address" $defaultAddress
    if ($address -eq $null)
    {
        Write-Error "You pressed the Cancel button on the multi-line input box."
    }
     
    Prompts the user for their address and stores it in a variable, pre-filling the input box with a default multi-line address.
    If the user pressed the Cancel button an error is written to the console.
     
    .EXAMPLE
    $inputText = Read-MultiLineInputDialog -Message "If you have a really long message you can break it apart`nover two lines with the powershell newline character:" -WindowTitle "Window Title" -DefaultText "Default text for the input box."
     
    Shows how to break the second parameter (Message) up onto two lines using the powershell newline character (`n).
    If you break the message up into more than two lines the extra lines will be hidden behind or show ontop of the TextBox.

    .EXAMPLE
    $multiLineText = Read-MultiLineInputBoxDialog -Message "Please enter some text. It can be multiple lines" -WindowTitle "Multi Line Example" -DefaultText "Enter some text here..."
    if ($multiLineText -eq $null) { Write-Host "You clicked Cancel" } else { Write-Host "You entered the following text: $multiLineText" }    
     
    .NOTES
    Name: Show-MultiLineInputDialog
    Author: Daniel Schroeder (originally based on the code shown at http://technet.microsoft.com/en-us/library/ff730941.aspx)
    Version: 1.0
#>
function Read-MultiLineInputBoxDialog() {
    param(
        [string]$Message, 
        [string]$WindowTitle, 
        [string]$DefaultText
    )

    Add-Type -AssemblyName System.Drawing
    Add-Type -AssemblyName System.Windows.Forms
     
    # Create the Label.
    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Size(10,10) 
    $label.Size = New-Object System.Drawing.Size(280,20)
    $label.AutoSize = $true
    $label.Text = $Message
     
    # Create the TextBox used to capture the user's text.
    $textBox = New-Object System.Windows.Forms.TextBox 
    $textBox.Location = New-Object System.Drawing.Size(10,40) 
    $textBox.Size = New-Object System.Drawing.Size(575,200)
    $textBox.AcceptsReturn = $true
    $textBox.AcceptsTab = $false
    $textBox.Multiline = $true
    $textBox.ScrollBars = 'Both'
    $textBox.Text = $DefaultText
     
    # Create the OK button.
    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Location = New-Object System.Drawing.Size(415,250)
    $okButton.Size = New-Object System.Drawing.Size(75,25)
    $okButton.Text = "OK"
    $okButton.Add_Click({ $form.Tag = $textBox.Text; $form.Close() })
     
    # Create the Cancel button.
    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object System.Drawing.Size(510,250)
    $cancelButton.Size = New-Object System.Drawing.Size(75,25)
    $cancelButton.Text = "Cancel"
    $cancelButton.Add_Click({ $form.Tag = $null; $form.Close() })
     
    # Create the form.
    $form = New-Object System.Windows.Forms.Form 
    $form.Text = $WindowTitle
    $form.Size = New-Object System.Drawing.Size(610,320)
    $form.FormBorderStyle = 'FixedSingle'
    $form.StartPosition = "CenterScreen"
    $form.AutoSizeMode = 'GrowAndShrink'
    $form.Topmost = $True
    $form.AcceptButton = $okButton
    $form.CancelButton = $cancelButton
    $form.ShowInTaskbar = $true
     
    # Add all of the controls to the form.
    $form.Controls.Add($label)
    $form.Controls.Add($textBox)
    $form.Controls.Add($okButton)
    $form.Controls.Add($cancelButton)
     
    # Initialize and show the form.
    $form.Add_Shown({$form.Activate()})
    $form.ShowDialog() > $null   # Trash the text of the button that was clicked.
     
    # Return the text that the user entered.
    return $form.Tag
}


###############################################################################
# Simple Textbased Powershell Menu
# Author : Michael Albert
# E-Mail : info@michlstechblog.info
# License: none, feel free to modify
# usage:
# Source the menu.ps1 file in your script:
# . .\menu.ps1
# fShowMenu requieres 2 Parameters:
# Parameter 1: [string]MenuTitle
# Parameter 2: [hashtable]@{[string]"ReturnString1"=[string]"Menu Entry 1";[string]"ReturnString2"=[string]"Menu Entry 2";[string]"ReturnString3"=[string]"Menu Entry 3"
# Return     : Select String
# For example:
# fShowMenu "Choose your favorite Band" @{"sl"="Slayer";"me"="Metallica";"ex"="Exodus";"an"="Anthrax"}
# #############################################################################

function Show-NavigationableMenu() {
    param (
        [System.String]$sMenuTitle,
        [System.Collections.Hashtable]$hMenuEntries        
    )
	# Orginal Konsolenfarben zwischenspeichern
	[System.Int16]$iSavedBackgroundColor=[System.Console]::BackgroundColor
	[System.Int16]$iSavedForegroundColor=[System.Console]::ForegroundColor
	# Menu Colors
	# inverse fore- and backgroundcolor 
	[System.Int16]$iMenuForeGroundColor=$iSavedForegroundColor
	[System.Int16]$iMenuBackGroundColor=$iSavedBackgroundColor
	[System.Int16]$iMenuBackGroundColorSelectedLine=$iMenuForeGroundColor
	[System.Int16]$iMenuForeGroundColorSelectedLine=$iMenuBackGroundColor
	# Alternative, colors
	#[System.Int16]$iMenuBackGroundColor=0
	#[System.Int16]$iMenuForeGroundColor=7
	#[System.Int16]$iMenuBackGroundColorSelectedLine=10
	# Init
	[System.Int16]$iMenuStartLineAbsolute=0
	[System.Int16]$iMenuLoopCount=0
	[System.Int16]$iMenuSelectLine=1
	[System.Int16]$iMenuEntries=$hMenuEntries.Count
	[Hashtable]$hMenu=@{};
	[Hashtable]$hMenuHotKeyList=@{};
	[Hashtable]$hMenuHotKeyListReverse=@{};
	[System.Int16]$iMenuHotKeyChar=0
	[System.String]$sValidChars=""
	[System.Console]::WriteLine(" "+$sMenuTitle)
	# Für die eindeutige Zuordnung Nummer -> Key
	$iMenuLoopCount=1
	# Start Hotkeys mit "1"!
	$iMenuHotKeyChar=49
	foreach ($sKey in $hMenuEntries.Keys){
		$hMenu.Add([System.Int16]$iMenuLoopCount,[System.String]$sKey)
		# Hotkey zuordnung zum Menueintrag
		$hMenuHotKeyList.Add([System.Int16]$iMenuLoopCount,[System.Convert]::ToChar($iMenuHotKeyChar))
		$hMenuHotKeyListReverse.Add([System.Convert]::ToChar($iMenuHotKeyChar),[System.Int16]$iMenuLoopCount)
		$sValidChars+=[System.Convert]::ToChar($iMenuHotKeyChar)
		$iMenuLoopCount++
		$iMenuHotKeyChar++
		# Weiter mit Kleinbuchstaben
		if($iMenuHotKeyChar -eq 58){$iMenuHotKeyChar=97}
		# Weiter mit Großbuchstaben
		elseif($iMenuHotKeyChar -eq 123){$iMenuHotKeyChar=65}
		# Jetzt aber ende
		elseif($iMenuHotKeyChar -eq 91){
			Write-Error " Menu too big!"
			exit(99)
		}
	}
	# Remember Menu start
	[System.Int16]$iBufferFullOffset=0
	$iMenuStartLineAbsolute=[System.Console]::CursorTop
	do{
		####### Draw Menu  #######
		[System.Console]::CursorTop=($iMenuStartLineAbsolute-$iBufferFullOffset)
		for ($iMenuLoopCount=1;$iMenuLoopCount -le $iMenuEntries;$iMenuLoopCount++){
			[System.Console]::Write("`r")
			[System.String]$sPreMenuline=""
			$sPreMenuline="  "+$hMenuHotKeyList[[System.Int16]$iMenuLoopCount]
			$sPreMenuline+=": "
			if ($iMenuLoopCount -eq $iMenuSelectLine){
				[System.Console]::BackgroundColor=$iMenuBackGroundColorSelectedLine
				[System.Console]::ForegroundColor=$iMenuForeGroundColorSelectedLine
			}
			if ($hMenuEntries.Item([System.String]$hMenu.Item($iMenuLoopCount)).Length -gt 0){
				[System.Console]::Write($sPreMenuline+$hMenuEntries.Item([System.String]$hMenu.Item($iMenuLoopCount)))
			}
			else{
				[System.Console]::Write($sPreMenuline+$hMenu.Item($iMenuLoopCount))
			}
			[System.Console]::BackgroundColor=$iMenuBackGroundColor
			[System.Console]::ForegroundColor=$iMenuForeGroundColor
			[System.Console]::WriteLine("")
		}
		[System.Console]::BackgroundColor=$iMenuBackGroundColor
		[System.Console]::ForegroundColor=$iMenuForeGroundColor
		[System.Console]::Write("  Your choice: " )
		if (($iMenuStartLineAbsolute+$iMenuLoopCount) -gt [System.Console]::BufferHeight){
			$iBufferFullOffset=($iMenuStartLineAbsolute+$iMenuLoopCount)-[System.Console]::BufferHeight
		}
		####### End Menu #######
		####### Read Kex from Console 
		$oInputChar=[System.Console]::ReadKey($true)
		# Down Arrow?
		if ([System.Int16]$oInputChar.Key -eq [System.ConsoleKey]::DownArrow){
			if ($iMenuSelectLine -lt $iMenuEntries){
				$iMenuSelectLine++
			}
		}
		# Up Arrow
		elseif([System.Int16]$oInputChar.Key -eq [System.ConsoleKey]::UpArrow){
			if ($iMenuSelectLine -gt 1){
				$iMenuSelectLine--
			}
		}
		elseif([System.Char]::IsLetterOrDigit($oInputChar.KeyChar)){
			[System.Console]::Write($oInputChar.KeyChar.ToString())	
		}
		[System.Console]::BackgroundColor=$iMenuBackGroundColor
		[System.Console]::ForegroundColor=$iMenuForeGroundColor
	} while(([System.Int16]$oInputChar.Key -ne [System.ConsoleKey]::Enter) -and ($sValidChars.IndexOf($oInputChar.KeyChar) -eq -1))
	
	# reset colors
	[System.Console]::ForegroundColor=$iSavedForegroundColor
	[System.Console]::BackgroundColor=$iSavedBackgroundColor
	if($oInputChar.Key -eq [System.ConsoleKey]::Enter){
		[System.Console]::Writeline($hMenuHotKeyList[$iMenuSelectLine])
		return([System.String]$hMenu.Item($iMenuSelectLine))
	}
	else{
		[System.Console]::Writeline("")
		return($hMenu[$hMenuHotKeyListReverse[$oInputChar.KeyChar]])
	}
}