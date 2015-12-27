# 
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
    [CmdletBinding(SupportsShouldProcess,ConfirmImpact='High')]
 
    Param (
        [switch]$AsAdministrator,
        [switch]$Force
    )
 
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


function Update-PSF {
    [CmdletBinding()]
    Param(
        [switch]$WhatIf
    )
    $cacheTime =  ((Get-Date)-((Get-Date).AddYears(-60))).TotalSeconds 
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
}

function Add-DirectoryToPath($Directory) {
	if (-not ($ENV:PATH.Contains($Directory))) {
		$ENV:PATH += ";$Directory"
	}
}

function Install-Tools {
	Write-Host "Installing Chocolatey"
	if(-not $env:path -match "Chocolatey") {
	  iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))
	}
	
	Write-Host "Installing Boxstarter"
	if($env:path -match "Boxstarter" -and -not $env:path -match "Boxstarter" ) {
	  CINST Boxstarter
	}
}

set-alias sudo elevate-process;
set-alias reload Restart-Host;
set-alias updatepsf Update-PSF;

switch ( $Host.Name ) {
    'Windows PowerShell ISE Host' {
        $Global:Color_Label = "DarkCyan"
        $Global:Color_Value_1 = "Magenta"
        $Global:Color_Value_2 = "DarkGreen"
        $HostWidth = 80

        Import-Module ISEPack 

        $PSISE.options.FontName = "Consolas"
        $psise.Options.ConsolePaneBackgroundColor = "Black"
        $psise.Options.ConsolePaneTextBackgroundColor = "Black"
        $psise.Options.ConsolePaneForegroundColor = "LightGreen"

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
        $pswindow.ForegroundColor = "Green"
        $pswindow.BackgroundColor = "Black"
        $newsize = $pswindow.buffersize
        $newsize.height = 3000
        $newsize.width = 150
        $pswindow.buffersize = $newsize

        $newsize = $pswindow.windowsize
        $newsize.height = 50
        $newsize.width = 150
        $pswindow.windowsize = $newsize

        $Global:Color_Label = "Cyan"
        $Global:Color_Value_1 = "Green"
        $Global:Color_Value_2 = "Yellow"
        $HostWidth = $Host.UI.RawUI.WindowSize.Width
        
        # Set a nice title for the window. 
	$id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
	$wp = new-object System.Security.Principal.WindowsPrincipal($id)
	$admin = [System.Security.Principal.WindowsBuiltInRole]::Administrator
	$IsAdmin = $wp.IsInRole($admin)
	
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
# Setup a scripts path for all scripts. 
#
if(-not (Test-Path ".\Scripts\PowerShell") {
  New-Item ".\Scripts\PowerShell" -ItemType Directory 
  New-Item ".\Scripts\PowerShell\CoreModulesManual" -ItemType Directory
  New-Item ".\Scripts\PowerShell\CoreModulesAuto" -ItemType Directory
  New-Item ".\Scripts\PowerShell\CoreFunctions" -ItemType Directory 
  
}

if (-not (Test-Path Scripts:)) {
	New-PSDrive -name Scripts -psprovider FileSystem -root .\Scripts\PowerShell -Description "Scripts Folder" -Scope Global | Out-Null
}
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
