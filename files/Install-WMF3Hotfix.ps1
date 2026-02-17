#Requires -Version 3.0
<#PSScriptInfo
.VERSION 1.0
.GUID 6cf319d1-8c50-460b-99ee-71b11cf7270d
.AUTHOR
    Jordan Borean <jborean93@gmail.com>
.COPYRIGHT
    Jordan Borean 2017
.TAGS
    PowerShell,Ansible,WinRM,WMF,Hotfix
.LICENSEURI https://github.com/jborean93/ansible-windows/blob/master/LICENSE
.PROJECTURI https://github.com/jborean93/ansible-windows
.RELEASENOTES
    Version 1.0: 2017-09-27
        Initial script created
#>

<#
.DESCRIPTION
The script will install the WinRM hotfix KB2842230 which fixes the memory
issues that occur when running over WinRM with WMF 3.0.
The script will;
    1. Detect if running on PS version 3.0 and exit if it is not
    2. Check if KB2842230 is already installed and exit if it is
    3. Download the hotfix from Microsoft server's based on the OS version
    4. Extract the .msu file from the downloaded hotfix
    5. Install the .msu silently
    6. Detect if a reboot is required and prompt whether the user wants to restart

Once the install is complete, if the install process returns an exit
code of 3010, it will ask the user whether to restart the computer now
or whether it will be done later.

See https://github.com/jborean93/ansible-windows/tree/master/scripts for more
details.
.PARAMETER Verbose
    [switch] - Whether to display Verbose logs on the console
.EXAMPLE
    powershell.exe -ExecutionPolicy ByPass -File Install-WMF3Hotfix.ps1
.EXAMPLE
    powershell.exe -ExecutionPolicy ByPass -File Install-WMF3Hotfix.ps1 -Verbose
#>

[CmdletBinding()]
Param()

$ErrorActionPreference = "Stop"
if ($verbose) {
    $VerbosePreference = "Continue"
}

Function Run-Process($executable, $arguments) {
    $process = New-Object -TypeName System.Diagnostics.Process
    $psi = $process.StartInfo
    $psi.FileName = $executable
    $psi.Arguments = $arguments
    Write-Verbose -Message "starting new process '$executable $arguments'"
    $process.Start() | Out-Null

    $process.WaitForExit() | Out-Null
    $exit_code = $process.ExitCode
    Write-Verbose -Message "process completed with exit code '$exit_code'"

    return $exit_code
}

Function Download-File($url, $path) {
    Write-Verbose -Message "downloading url '$url' to '$path'"
    $client = New-Object -TypeName System.Net.WebClient
    $client.DownloadFile($url, $path)
}

Function Extract-Zip($zip, $dest) {
    Write-Verbose -Message "extracting '$zip' to '$dest'"
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem > $null
        $legacy = $false
    } catch {
        $legacy = $true
    }

    if ($legacy) {
        $shell = New-Object -ComObject Shell.Application
        $zip_src = $shell.NameSpace($zip)
        $zip_dest = $shell.NameSpace($dest)
        $zip_dest.CopyHere($zip_src.Items(), 1044)
    } else {
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zip, $dest)
    }
}

$tmp_dir = $env:temp
$kb = "KB2842230"
if ($PSVersionTable.PSVersion.Major -ne 3) {
    Write-Verbose -Message "$kb is only applicable with Powershell v3, no action required"
    exit 0
}

$hotfix_installed = Get-Hotfix -Id $kb -ErrorAction SilentlyContinue
if ($hotfix_installed -ne $null) {
    Write-Verbose -Message "$kb is already installed"
    exit 0
}

if (-not (Test-Path -Path $tmp_dir)) {
    New-Item -Path $tmp_dir -ItemType Directory > $null
}
$os_version = [Version](Get-Item -Path "$env:SystemRoot\System32\kernel32.dll").VersionInfo.ProductVersion
$host_string = "$($os_version.Major).$($os_version.Minor)-$($env:PROCESSOR_ARCHITECTURE)"
switch($host_string) {
    "6.0-x86" {
        $url = $null
    }
    "6.0-AMD64" {
        $url = $null
    }
    "6.1-x86" {
        $url = $null
    }
    "6.1-AMD64" {
        $url = $null
    }
    "6.2-x86" {
        $url = "https://catalog.s.download.windowsupdate.com/d/msdownload/update/software/htfx/2013/07/windows8-rt-kb2842230-x86_ba30b9f56e801eb6dc4915312514340c613780fc.msu"
    }
    "6.2-AMD64" {
        $url = "https://catalog.s.download.windowsupdate.com/d/msdownload/update/software/htfx/2013/07/windows8-rt-kb2842230-x64_6b06f4059b82eaa8140e91e9f30c7b3a72640741.msu"
    }
}

if ([String]::IsNullOrWhiteSpace($url)) {
    Write-Error -Message "No public Microsoft download URL was found for $host_string and $kb. Provide an internal mirror URL and install manually."
    exit 1
}

if ($url -match "\.msu($|\?)") {
    $filename = $url.Split("/")[-1]
    $file_path = "$tmp_dir\$filename"
    Download-File -url $url -path $file_path
    $file = Get-Item -Path $file_path
} else {
    $filename = $url.Split("/")[-1]
    $compressed_file = "$tmp_dir\$($filename).zip"
    Download-File -url $url -path $compressed_file
    Extract-Zip -zip $compressed_file -dest $tmp_dir
    $file = Get-Item -Path "$tmp_dir\*$kb*.msu"
}
if ($file -eq $null) {
    Write-Error -Message "unable to find extracted msu file for hotfix KB"
    exit 1
}

$exit_code = Run-Process -executable $file.FullName -arguments "/quiet /norestart"
if ($exit_code -eq 3010) {
    Write-Verbose "need to restart computer after hotfix $kb install"
    Restart-Computer -Force
} elseif ($exit_code -ne 0) {
    Write-Error -Message "failed to install hotfix $($kb): exit code $exit_code"
} else {
    Write-Verbose -Message "hotfix $kb install complete"
}
exit $exit_code