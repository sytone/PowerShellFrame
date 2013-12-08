# This will install and setup the local environment. 
# Read through it first or just trust the code.. Your choice, your risk. 

# @powershell -NoProfile -ExecutionPolicy unrestricted -Command "iex ((new-object net.webclient).DownloadString('https://raw.github.com/sytone/PowerShellFrame/master/install.ps1'))" && SET PATH=%PATH%;%systemdrive%\psf

Write-Host "Welcome to the PowerShelFrame (PSF) "
Write-Host "This is being installed at: $($env:systemdrive)\psf"

if(-not (Test-Path "$($env:systemdrive)\psf")) {
  Write-Host "Creating PSF"
  New-Item "$($env:systemdrive)\psf" -Type Directory | Out-Null
} else {
  Write-Host "Upgrading PSF"
}
