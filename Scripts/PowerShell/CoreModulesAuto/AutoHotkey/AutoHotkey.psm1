function Install-AutoHotkey {
    $f = New-TemporaryFile
    Invoke-WebRequest -Uri "https://autohotkey.com/download/ahk-u64.zip" -OutFile $f
    Move-Item -Path $f -Destination "$f.zip"
    $installPath = Get-PsfConfig -Key ToolsPath
    $Destination = (Join-Path $installPath "ahk")  # this folder MUST exist     
    New-Item -Path $Destination -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
    Unblock-File $Destination    # use this in PowerShell v3 to unblock downloaded data
    $helper = New-Object -ComObject Shell.Application
    $files = $helper.NameSpace("$f.zip").Items()
    $helper.NameSpace($Destination).CopyHere($files)     
    
    if($Global:IsAdmin) {
        cmd /c "assoc .ahk=AutoHotkeyScript"
        cmd /c "ftype AutoHotkeyScript=""$Destination\AutoHotkey.exe"" ""%1"" %*"
    } else {
        Write-Host "WARNING: AHK file type may not be registered as this is not running as a admin process" -ForegroundColor Red
        Write-Host " Run the following commands in a elevated console (not powershell)"
        Write-Host " assoc .ahk=AutoHotkeyScript" -ForegroundColor Green
        Write-Host " ftype AutoHotkeyScript=""$Destination\AutoHotkey.exe"" ""%1"" %*" -ForegroundColor Green
    }
}
