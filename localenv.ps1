# 
function elevate-process {
	$file, [string]$arguments = $args;
	$psi = new-object System.Diagnostics.ProcessStartInfo $file;
	$psi.Arguments = $arguments;
	$psi.Verb = "runas";
	$psi.WorkingDirectory = get-location;
	[System.Diagnostics.Process]::Start($psi);
}

function Restart-Host
{
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
