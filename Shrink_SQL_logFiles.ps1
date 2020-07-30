# Check/Install SqlServer module for PS
$SqlServer_module_version = Get-Module SqlServer -ListAvailable | Select-Object -Property Name,Version;`

if (!$SqlServer_module_version) {
    Write-Host "For this script work you need to install Powershell module 'SqlServer'" -ForegroundColor Green;`
    $confirm_install_module = $(Write-Host "Are you sure to want to install Powershell module 'SqlServer'? (y/n): " -ForegroundColor Yellow; Read-Host);`
    
    if ($confirm_install_module -match "[yY]") {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;`
        Install-Module -Name SqlServer -AllowClobber;`
    } else {
        Write-Host "Your choice was NO. Good Bye" -ForegroundColor Red;`
        exit
    }

} else {
    Write-Host "Installed module info: " -ForegroundColor Green;`
    Write-Host $SqlServer_module_version -ForegroundColor Yellow;`
    
    # Set variables
    $hostname = hostname;`
    $ins = "$hostname";`
    Write-Host "Input Username and Passwort to login on your SQL Server: " -ForegroundColor Yellow;`
    $cred = Get-Credential;`
    $params = @{Credential=$cred; ServerInstance=$ins};`
    # FOR TEST
    #$Username = 'sa'
    #$Password = 'Mrt5hkmrt5hk'
    #$params1 = @{username=$Username; password=$Password; ServerInstance=$ins};`

    # Set queries
    $db_list_quer = "SELECT name, database_id, recovery_model_desc AS [Recovery Model]
                     FROM sys.databases  
                     GO";`

    $db_full_rm_list = "SELECT name, database_id, recovery_model_desc AS [Recovery Model]
                        FROM sys.databases
                        WHERE recovery_model_desc = 'FULL' 
                        GO";`

    $log_size_in_MB_quer = "SELECT name, type_desc, size * 8 / 1024 AS [size_MB]
                            FROM sys.master_files
                            WHERE type_desc = 'LOG'
                            GO";`

    $log_size_more_than_300_MB_quer = "SELECT name, type_desc, size * 8 / 1024 AS [size_MB]
                                       FROM sys.master_files
                                       WHERE type_desc = 'LOG' AND size * 8 / 1024 > 300
                                       GO";`

    # Get db info
    try {
        Invoke-Sqlcmd @params -Query $db_list_quer | Format-Table ;`
    } catch {
        Write-Host "an ERROR was encountered connecting to SQL Server" -ForegroundColor Red;`
        Write-Error $_
        Exit
    }
    
    $rm_full_list = Invoke-Sqlcmd @params -Query $db_full_rm_list | Select-Object -Property name, recovery_model_desc ;`

    if (!$rm_full_list) {
        Write-Host "All bases have SIMPLE recovery model" -ForegroundColor Green;
    } else {
        # Show list DBs for change recovery model
        Write-Host "For shrinked has works you need to change recovery model from FULL to SIMPLE." -ForegroundColor Yellow;`
        Write-Host "Databases for change recovery model:" -ForegroundColor Yellow;`
        
        foreach ($rm in $rm_full_list) {
            Write-Host  $rm.name -ForegroundColor Cyan;`
        }

        $confirm_change_rm = Read-Host "Are you sure to want to change recovery model? (y/n): "

        if ($confirm_change_rm -match "[yY]") {
            # Start change recovery model if answer "YES"
            foreach ($db_frm in $rm_full_list) {
                $rm_change = $db_frm.name;`
                Write-Host "Now changed is: " $rm_change -ForegroundColor Green;`
                $change_rm_quer = "ALTER DATABASE $rm_change
                                   SET RECOVERY SIMPLE
                                   GO";`
                Invoke-Sqlcmd @params -Query $change_rm_quer;`
                Write-Host "Database '$rm_change' changed recovery model" -ForegroundColor Green;`
            }
        } else {
            # Message if answer "NO"
            Write-Host "Your choice was NO" -ForegroundColor Red;
        }
    }

    # Get logfiles info
    Invoke-Sqlcmd @params -Query $log_size_in_MB_quer | Format-Table ;`
    $shrink_list = Invoke-Sqlcmd @params -Query $log_size_more_than_300_MB_quer | Select-Object -Property name, size;`

    # Ceck DB list for shrink
    if (!$shrink_list) {
        Write-Host "All DBs have logfiles size less than 300 MB. Nothing to do" -ForegroundColor Green;`
    } else {
        # Show list DBs for shrink
        Write-Host "Databases for shrink:" -ForegroundColor Yellow;`

        foreach ($sh in $shrink_list) {
            Write-Host  $sh.name -ForegroundColor Cyan;`
        }
        
        # User confirmation request
        $confirm_shrink = Read-Host "Are you sure you want to shrink logfiles? (y/n): "
        
        if ($confirm_shrink -match "[yY]") {
            # Start shrink if answer "YES"
            foreach ($db in $shrink_list) {
                $shrinkedfile = $db.name;`
                Write-Host "Now shrinked is: " $shrinkedfile -ForegroundColor Green;`
                Invoke-Sqlcmd @params -Database $shrinkedfile.Replace("_log", "") -Query "DBCC SHRINKFILE ($shrinkedfile, 1)";`
                Write-Host "Database '$shrinkedfile' log file is shrinked" -ForegroundColor Green;`
            }
        } else {
            # Message if answer "NO"
            Write-Host "Your Choice was NO" -ForegroundColor Red;
            exit
        }
        # Сompletion message
        Invoke-Sqlcmd @params -Query $log_size_in_MB_quer | Select-Object -Property name, size | Format-Table;` # FIXME - need to test finish  output (don't showing size)
        Write-Host "Shrink logfiles for needed DBs is Done" -ForegroundColor Green;
    }
}
