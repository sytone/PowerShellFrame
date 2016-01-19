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
        [String]$GatewayHostName
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
        $f = New-TemporaryFile
        $rdpFile = "{0}.rdp" -f $f.FullName
        $rdpString | Set-Content $rdpFile
        Start-Process $rdpFile
    }
 }
 

 

