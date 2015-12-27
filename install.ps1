# This will install and setup the local environment. 
# Read through it first or just trust the code.. Your choice, your risk. 

# @powershell -NoProfile -ExecutionPolicy unrestricted -Command "iex ((new-object net.webclient).DownloadString('https://raw.github.com/sytone/PowerShellFrame/master/install.ps1'))" && SET PATH=%PATH%;%systemdrive%\psf

$psfRemoteRoot = "https://raw.github.com/sytone/PowerShellFrame/master"
$psfLocalRoot =  Join-Path $env:USERPROFILE "psf"
$psfLocalTemp = Join-Path $psfLocalRoot "temp"
$psfLocalModules = Join-Path $psfLocalRoot "modules"

function Get-FileFromWeb($url,$outfile) {
  $cacheTime =  ((Get-Date)-((Get-Date).AddYears(-60))).TotalSeconds
  
  Invoke-WebRequest ("{0}?cache={1}" -f $url, $cacheTime) -outfile $outfile
}


Write-Host "Welcome to the PowerShelFrame (PSF) "
Write-Host "This is being installed at: $psfLocalRoot"

if(-not (Test-Path $psfLocalRoot)) {
  Write-Host "Creating PSF"
  New-Item $psfLocalRoot -Type Directory | Out-Null
  New-Item $psfLocalTemp -Type Directory | Out-Null
  New-Item $psfLocalModules -Type Directory | Out-Null 
  Get-FileFromWeb -url "$psfRemoteRoot/localenv.ps1" -outfile "$psfLocalRoot\localenv.ps1"
} else {
  Write-Host "Upgrading PSF"
  Remove-Item "$psfLocalRoot\localenv.ps1" -force
  Get-FileFromWeb -url "$psfRemoteRoot/localenv.ps1" -outfile "$psfLocalRoot\localenv.ps1"
}

Write-Host "Validating the profile $profile"
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

