#set location to script path
Set-Location (Split-Path -Parent $MyInvocation.MyCommand.Path)

#import modules
Import-Module Add-PrefixForLogging
Import-Module Send-FileViaEmail
Import-Module Get-DataTableFromSQL
Import-Module .\ConvertTo-TaxFile.psm1 #custom for this job
Import-Module Get-FilesForMCTF

#get config, set some global variables
$global:cfg           = Get-Content settings.json -Raw | ConvertFrom-Json
[string]$global:file  = $global:cfg.file_format -f (get-date).AddMonths(-1)

#define main
function main{
    "`n`n"
    l "Start"
    l "Get Data"
    Get-FilesForMCTF $global:cfg $global:file
    l "Use Data"
    l (Send-FileViaEmail "$($global:file).zip" $global:cfg.mail )
    l "End"
    "`n`n"
}
#run main, output to screen and log
& { main } 2>&1 | Tee-Object -Append ($global:cfg.log_format -f (get-date))