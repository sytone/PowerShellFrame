PowerShellFrame
===============

The PowerShellFram is a framework for installing and running powershell to be more porductive. 


Installation
-------------

Run the following commands:

Command Window

    @powershell -NoProfile -ExecutionPolicy unrestricted -Command "iex ((new-object net.webclient).DownloadString('https://raw.github.com/sytone/PowerShellFrame/master/install.ps1'))" 

 

PowerShell Window

    iex ((new-object net.webclient).DownloadString(('https://raw.github.com/sytone/PowerShellFrame/master/install.ps1?x={0}' -f (Get-Random))))
    



