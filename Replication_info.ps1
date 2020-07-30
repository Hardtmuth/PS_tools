#   Hosts lists variables
$Hostslist = "node01","node02","node03","node05","node10","node11"

#   Command to collect data on the old AD
Get-VMReplication -ComputerName $Hostslist `
    | Where-Object {$_.ReplicationHealth -eq "Critical" -or $_.ReplicationHealth -eq "Warning"} `
    | Select-Object -Property Health,PrimaryServer,VMName,State `
    | Sort-Object -Property PrimaryServer `
    | Format-Table -AutoSize `
    | Out-String -Width 200 `
    | Out-File -FilePath c:\repl_nfo.txt

#   Scriptblock for send message in telegram group
$token = "input_your_token"
$chat_id = "input_your_chat_id"
$text = Get-Content -Path c:\repl_nfo.txt | Out-String
$result = ""
If (($text).length -le 2) {
    $result = "VM Replications is Fine, on all of hosts in this AD"
} else {
    $result = Get-Content -Path "c:\repl_nfo.txt" | Out-String
}

$payload = @{
    "chat_id" = $chat_id;
    "text" = $result;
    "parse_mode" = 'html';
}

# If error output: Invoke-WebRequest : Запрос был прерван: Не удалось создать защищенный канал SSL/TLS.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Invoke-WebRequest `
    -Uri ("https://api.telegram.org/bot{0}/sendMessage" -f $token) `
    -Method Post `
    -ContentType "application/json;charset=utf-8" `
    -Body (ConvertTo-Json -Compress -InputObject $payload)

#   P.S.
#   Script to add scheduled task in Windows
$Action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NonInteractive -NoLogo -NoProfile -WindowStyle Hidden -File "C:\Path\to\your\script_file.ps1"'
$Trigger = New-ScheduledTaskTrigger -Daily -At 7am
$Settings = New-ScheduledTaskSettingsSet
$Task = New-ScheduledTask -Action $Action -Trigger $Trigger -Settings $Settings
Register-ScheduledTask -TaskName 'Check Replication Health' -InputObject $Task #-User 'username' -Password 'passhere'

