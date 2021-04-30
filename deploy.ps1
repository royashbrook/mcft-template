# begin deployment configuration

    # project name will match the current parent folder
    $p = Split-Path -Leaf (Split-Path -Parent $MyInvocation.MyCommand.Path)
    # server we want to deploy to
    $s = "jobserver.local"
    # directory we want to deploy the project to
    $d = "\\$s\c`$\jobs\$p"
    # files that will be deployed
    $f = "ConvertTo-TaxFile.psm1,get-data.sql,job.ps1,README.md,settings.json,spec.msg" -split ","

# end deployment configuration

# ensure target directory exists
if(!(Test-Path $d)) {md $d}
# copy files if target dir exists
if(Test-Path $d){
    Copy-Item -Path $f -Destination $d
    $sb_dep = { param($p); schtasks /f /create /tn `"$p`" /tr `"powershell c:\jobs\$p\job.ps1`" /ru system /sc monthly /d 15 /st:10:00 }
    Invoke-Command -ComputerName $s -ScriptBlock $sb_dep -ArgumentList $p
    $runtask = "Invoke-Command -ComputerName `"$s`" -ScriptBlock { param(`$p); schtasks /run /tn `"`$p`" } -ArgumentList `"$p`""
    Set-Clipboard $runtask; "To run job now CTRL+V or manually call: $runtask"
}else{
    "Failed to create project folder."
}