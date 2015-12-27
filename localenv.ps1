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
 
    Param(
        [switch]$AsAdministrator,
        [switch]$Force
    )
 
    $proc = Get-Process -Id $PID
    $cmdArgs = [Environment]::GetCommandLineArgs() | Select-Object -Skip 1
 
    $params = @{ FilePath = $proc.Path }
    if ($AsAdministrator) { $params.Verb = 'runas' }
    if ($cmdArgs) { $params.ArgumentList = $cmdArgs }
 
   if ($Force -or $PSCmdlet.ShouldProcess($proc.Name,"Restart the console"))
   {
        if ($host.Name -eq 'Windows PowerShell ISE Host' -and $psISE.PowerShellTabs.Files.IsSaved -contains $false)
        {
            if ($Force -or $PSCmdlet.ShouldProcess('Unsaved work detected?','Unsaved work detected. Save changes?','Confirm'))
           {
                foreach ($IseTab in $psISE.PowerShellTabs)
                {
                    $IseTab.Files | ForEach-Object {
 
                        if ($_.IsUntitled -and !$_.IsSaved)
                        {
                            $_.SaveAs($_.FullPath,[System.Text.Encoding]::UTF8)
                        }
                        elseif(!$_.IsSaved)
                        {
                            $_.Save()
                        }
                    }
                }
            }
            else
            {
                foreach ($IseTab in $psISE.PowerShellTabs)
                {
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
    
    iex ((new-object net.webclient).DownloadString('https://raw.github.com/sytone/PowerShellFrame/master/install.ps1'))

}

set-alias sudo elevate-process;
set-alias reload Restart-Host;
set-alias updatepsf Update-PSF;
