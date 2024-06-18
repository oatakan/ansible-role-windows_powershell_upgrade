#!powershell

$ErrorActionPreference = "Stop"

# Function to convert a hashtable to JSON manually for compatibility with PowerShell 2
function ConvertTo-JsonManual {
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$Data
    )
    $json = "{"
    foreach ($key in $Data.Keys) {
        $value = $Data[$key]
        if ($value -is [hashtable]) {
            $value = ConvertTo-JsonManual -Data $value
        } else {
            $value = $value.ToString()
            $value = '"' + $value + '"'
        }
        $json += '"' + $key + '":' + $value + ','
    }
    $json = $json.TrimEnd(',') + "}"
    return $json
}

# Gather facts
$kernel_version = (Get-Item -Path "$env:SystemRoot\System32\kernel32.dll").VersionInfo.ProductVersion
$ps_version = "$($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor)"
$major_version = $kernel_version.Split('.')[0]

# Create facts hashtable
$facts = @{
    ansible_kernel = $kernel_version
    ansible_powershell_version = $ps_version
    ansible_distribution_major_version = $major_version
}

# Output facts as JSON
$result = @{
    changed = $false
    ansible_facts = $facts
}

$manualJson = ConvertTo-JsonManual -Data $result
Write-Output $manualJson