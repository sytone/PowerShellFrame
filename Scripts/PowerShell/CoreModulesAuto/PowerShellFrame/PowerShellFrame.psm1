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
 
function script:Resolve-Aliases {
    param($line)
    [System.Management.Automation.PSParser]::Tokenize($line,[ref]$null) | % {
        if($_.Type -eq "Command") {
            $cmd = @(Get-Command $_.Content)[0]
            if($cmd.CommandType -eq "Alias") {
                $line = $line.Remove( $_.StartColumn -1, $_.Length ).Insert( $_.StartColumn -1, $cmd.Definition )
            }
        }
    }
    $line
}

<#
.SYNOPSIS
    Creates a alias that can take params lik UNIX
.DESCRIPTION
    Creates a alias that can take params like UNIX alias command, it will
    also place the $arg at the end so you can add commands. 
.EXAMPLE
    C:\PS> alias fred=start-process winword
    C:\PS> fred helloworld.docx
    
    This will start work with whatever you add at the end. 
#>
function alias {
    
    # pull together all the args and then split on =
    $alias,$cmd = [string]::join(" ",$args).split("=",2) | % { $_.trim()}
    $cmd = Resolve-Aliases $cmd
    
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
 

 

