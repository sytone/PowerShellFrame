# This will install and setup the local environment. 
# Read through it first or just trust the code.. Your choice, your risk. 

# @powershell -NoProfile -ExecutionPolicy unrestricted -Command "iex ((new-object net.webclient).DownloadString('https://raw.github.com/sytone/PowerShellFrame/master/install.ps1'))" && SET PATH=%PATH%;%systemdrive%\psf

$psGallery = Get-PackageProvider -Name PowerShellGet -ErrorAction SilentlyContinue
if(!$psGallery) {
  Write-Host "Unable to install addtional modules from PowerShell Gallery using package provider. Aborting!" -ForegroundColor Yellow
  Write-Error "PowerShellGet not avaliable from 'Get-PackageProvider -Name PowerShellGet'"
}

Push-Location $env:USERPROFILE 

$psfRemoteRoot = "https://raw.githubusercontent.com/sytone/PowerShellFrame/master"
$psfLocalRoot =  Join-Path $env:USERPROFILE "psf"
$psfLocalTemp = Join-Path $psfLocalRoot "temp"
$psfLocalModules = Join-Path $psfLocalRoot "modules"

function Get-FileFromWeb($url,$outfile) {
  $cacheTime =  Get-Random -Maximum 10000000 -Minimum 0
  Invoke-WebRequest ("{0}?cache={1}" -f $url, $cacheTime) -outfile $outfile
}

Write-Host "-------------------------------------------------------------------------------"
Write-Host "    Welcome to the PowerShelFrame (PSF) Installer"
Write-Host ""
Write-Host " - This is being installed at: $psfLocalRoot"

if(-not (Test-Path $psfLocalRoot)) {
  Write-Host " - Creating PSF"
  New-Item $psfLocalRoot -Type Directory | Out-Null
  New-Item $psfLocalTemp -Type Directory | Out-Null
  New-Item $psfLocalModules -Type Directory | Out-Null 
  Get-FileFromWeb -url "$psfRemoteRoot/localenv.ps1" -outfile "$psfLocalRoot\localenv.ps1"
  Get-FileFromWeb -url "$psfRemoteRoot/tips.txt" -outfile "$psfLocalRoot\tips.txt"
} else {
  Write-Host " - Upgrading PSF"
  if((Test-Path "$psfLocalRoot\localenv.ps1")) {
    Remove-Item "$psfLocalRoot\localenv.ps1" -Force
  }
  Get-FileFromWeb -url "$psfRemoteRoot/localenv.ps1" -outfile "$psfLocalRoot\localenv.ps1"
  Get-FileFromWeb -url "$psfRemoteRoot/tips.txt" -outfile "$psfLocalRoot\tips.txt"
}


# 
# Test the Scripts directories are in place.  
#
Write-Host " - Checking Scripts"
$ScriptsRoot = (Join-Path $env:USERPROFILE "Scripts")  
if(-not (Test-Path $ScriptsRoot)) {
    New-Item $ScriptsRoot -ItemType Directory | Out-Null
}

$PowerShellScriptsRoot = (Join-Path $ScriptsRoot "PowerShell")  
if(-not (Test-Path $PowerShellScriptsRoot)) {
  New-Item $PowerShellScriptsRoot -ItemType Directory | Out-Null
  New-Item (Join-Path $PowerShellScriptsRoot "CoreModulesManual") -ItemType Directory | Out-Null
  New-Item (Join-Path $PowerShellScriptsRoot "CoreModulesAuto") -ItemType Directory | Out-Null
  New-Item (Join-Path $PowerShellScriptsRoot "CoreFunctions") -ItemType Directory | Out-Null
}

$AhkScriptsRoot = (Join-Path $ScriptsRoot "AHK")  
if(-not (Test-Path $AhkScriptsRoot)) {
  New-Item $AhkScriptsRoot -ItemType Directory | Out-Null
}

# These are core modules used by PSF. 
Write-Host " - Adding/Updating PSF Modules"
if(-not (Test-Path (Join-Path $PowerShellScriptsRoot "CoreModulesAuto\AutoHotkey"))) { 
    New-Item (Join-Path $PowerShellScriptsRoot "CoreModulesAuto\AutoHotkey") -ItemType Directory | Out-Null
} else {
  if((Test-Path (Join-Path $PowerShellScriptsRoot "CoreModulesAuto\AutoHotkey\AutoHotkey.psm1"))) {
    Remove-Item (Join-Path $PowerShellScriptsRoot "CoreModulesAuto\AutoHotkey\AutoHotkey.psm1") -force | Out-Null
  }
}
Get-FileFromWeb -url "$psfRemoteRoot/Scripts/PowerShell/CoreModulesAuto/AutoHotkey/AutoHotkey.psm1" -outfile (Join-Path $PowerShellScriptsRoot "CoreModulesAuto\AutoHotkey\AutoHotkey.psm1")

# Cleanup old versions. 
if((Test-Path (Join-Path $PowerShellScriptsRoot "CoreModulesAuto\PowerShellFrame"))) { 
  Remove-Item (Join-Path $PowerShellScriptsRoot "CoreModulesAuto\PowerShellFrame") -recurse -force | Out-Null
}

# Install from powershell gallery.
Install-Module -Name PowerShellFrame -Scope CurrentUser -Force -SkipPublisherCheck -ErrorAction SilentlyContinue

Write-Host " - Validating the profile $profile for this instance of powershell"
Write-Host " NOTE: You may have to update the `$profile for other instances where the profile path changes."
$envLoadLine = "`n. $psfLocalRoot\localenv.ps1   #LOCALENV - May change in future`n"
if ((Test-Path $profile) -eq $false) {
  New-Item $profile -type file -force -ea 0 | Out-Null
  $envLoadLine | Set-Content  ($profile)
} else {
  
  (Get-Content ($profile)) | Foreach-Object {
      $_ -replace '^.+#LOCALENV.+$', ($envLoadLine)
    } | Set-Content  ($profile)
    
  $mi = Select-String -Path $profile -Pattern "#LOCALENV"
  if(!$mi.Matches) { 
    $profileData = (Get-Content ($profile)) 
    ($profileData += $envLoadLine) | Set-Content  ($profile)
  }
}

# Install any packages. 
#$githubfs = Get-Module -Name GithubFS -ListAvailable
#if(!$githubfs) {
#  find-package -Name GithubFS | Install-Package -Force -Scope CurrentUser
#}

Write-Host "-------------------------------------------------------------------------------"

Pop-Location






