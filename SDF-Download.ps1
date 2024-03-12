param (
    [Parameter(Mandatory = $true)]
    [string]$Environment
)

if ($Environment -ne "TEST" -and $Environment -ne "PRODUCTION") {
    throw "Invalid environment specified. Please use 'TEST' or 'PRODUCTION'."
}

# Rest of your script
Write-Host "Environment is set to $Environment"



function Ensure-DirectoryExists {
    param(
        [string]$Path
    )

    if (-not (Test-Path -Path $Path -PathType Container)) {
        New-Item -Path $Path -ItemType Directory
        Write-Host "Created directory: $Path"
    } else {
        Write-Host "Directory already exists: $Path"
    }
}

$SolutranSFTPHost = "vendor.cnwictransfer.com"

# directory / path handling section
$basePathEnv = $env:CNWIC_PAYMENT_BASEPATH
if ($Environment -eq "TEST") {
	$basePathEnv = Join-Path -Path $basePathEnv -ChildPath $Environment
}
$dlPath = "DOWNLOAD"
$igPath = "INGESTION"
$basePath = Join-Path -Path $basePathEnv -ChildPath $dlPath
$basePathOld = Join-Path -Path $basePathEnv -ChildPath $igPath
Write-Host "basePathEnv is set to $basePathEnv"
Write-Host "basePath is set to $basePath"
Write-Host "basePathOld is set to $basePathOld"

#throw "Currently testing.  Ending Script."


Ensure-DirectoryExists -Path $basePath
$new = "Unprocessed"
$old = "Processed"
$WorkingPathOld = Join-Path -Path $basePathOld -ChildPath $old
Ensure-DirectoryExists -Path $WorkingPathOld
$WorkingPath = Join-Path -Path $basePath -ChildPath $new
Ensure-DirectoryExists -Path $WorkingPath
Write-Host "`$WorkingPath = $WorkingPath"

$SdfPrefix = "C2EBTPMT_"
$SdfSuffix = "????.SDF*"
$fMissing = @()
$fPresent = @()
$fWeekend = @()

$Today = Get-Date

for ($i = 0; $i -gt -6; $i--)
{
	Write-Host "`r`nFor Loop: `$i is $i"
	$d = $Today.AddDays($i)
	Write-Host "`$d = $d" 
	$ddow = "{0:dddd}" -f ($d)
	Write-Host "`$ddow = $ddow"
	$ds = "{0:yyMMdd}" -f ($d)
	$fn = $SdfPrefix + $ds + $SdfSuffix

	if (($ddow -ne "Saturday") -and ($ddow -ne "Sunday")) 
	{
		Write-Host "Looking for file $fn in location $WorkingPath . . . "
		Test-Path $WorkingPath"\"$fn
		if ((Test-Path $WorkingPath"\"$fn) -or (Test-Path $WorkingPathOld"\"$fn)) { $fPresent += $fn }
		else { $fMissing += $fn }
	} 
	else 
	{ 
		write-host "dow in sat, sun.  not looking for $fn . . . "
		$fWeekend += $fn
	}
}	
	
Write-Host "`r`n`$fPresent:"
Write-Host $fPresent
Write-Host "`r`n`$fMissing:"
Write-Host $fMissing
Write-Host "`r`n`$fWeekend:"
Write-Host $fWeekend

Get-Location
$credential = Import-CliXml -Path .\Solutran_SFTP_Credentials.xml
#Write-Host "`r`nPassword: "
#Write-Host $credential.GetNetworkCredential().Password
$usr = $credential.GetNetworkCredential().Username
$pwd = $credential.GetNetworkCredential().Password
$connectString = "open -hostkey=/M8nayRH8kB8Jcs3Se2Du9ZCZ486oVZhQ+YzyNfUe4s sftp://${usr}:${pwd}@${SolutranSFTPHost}"
#$connectString = "open sftp://"$credential.GetNetworkCredential().User":"$credential.GetNetworkCredential().Password"@"$SolutranSFTPHost
Write-Host "`$connectString:"
Write-Host $connectString
Set-Location $WorkingPath
$WINSCP_Script = ".\Test.WINSCP.script"
#Remove-item $WINSCP_Script
Add-Content $WINSCP_Script "# Connect"
Add-Content $WINSCP_Script $connectString
Add-Content $WINSCP_Script "# Change remote directory to /csc"
Add-Content $WINSCP_Script "cd /csc"
foreach ($f in $fMissing)
{
	Add-Content $WINSCP_Script "get ${f}"
}
Add-Content $WINSCP_Script "# Disconnect"
Add-Content $WINSCP_Script "close "
Add-Content $WINSCP_Script "# Exit WinSCP"
Add-Content $WINSCP_Script "exit"
#Add-Content $WINSCP_Script "#Stuff"
#Add-Content $WINSCP_Script $credential.GetNetworkCredential().Password

Write-Host "Executing winscp with script $WINSCP_Script . . . "
winscp.com /script=$WINSCP_Script > winscp.output.log
Write-Host "Removing .transferred from any downloaded files . . ."
Get-ChildItem *.transferred | Rename-Item -NewName { $_.Name -replace '.transferred','' }
Remove-item $WINSCP_Script
#read-host