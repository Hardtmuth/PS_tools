#Requires -RunAsAdministrator

# Get Default params from CSV (need to redone for use MarkDown)
$defaults = Import-Csv -Path .\vm_params.csv;`
[string]$hv_Host_def = $defaults | Select-Object -ExpandProperty host;`
[string]$hv_Name_def = $defaults | Select-Object -ExpandProperty name;`
[int32]$hv_Generation_def = $defaults | Select-Object -ExpandProperty generation;`
[int32]$hv_Cpu_def = $defaults | Select-Object -ExpandProperty cpu;`
[int64]$hv_Memory_def = $defaults | Select-Object -ExpandProperty memory;`
#[string]$hv_Switch_def = $defaults | Select-Object -ExpandProperty vswitch;` - get default switch from host
[int32]$hv_Vhdsize_def = $defaults | Select-Object -ExpandProperty vhdsize;`
[string]$hv_storevm_def = $defaults | Select-Object -ExpandProperty storevm;`
[string]$hv_storevhd_def = $defaults | Select-Object -ExpandProperty storevhd;`

$host_confirm = $(Write-Host 'Do you want to create a VM on this host? (Default: n) (y/n): ' -ForegroundColor Yellow; Read-Host);`
if(-not($host_confirm)) {
    $host_confirm = "n";`
    Write-Host $host_confirm;`
}

if ($host_confirm -match "[yY]") {
    [string]$hv_Host = hostname;`
} elseif ($host_confirm -match "[nN]") {
    [string]$hv_Host = $(Write-Host "Input Hyper-v hostname on which need to create new VM (Default: $hv_Host_def): " -ForegroundColor Yellow; Read-Host);`
    if (-not($hv_Host)) {
        $hv_Host = $hv_Host_def;`
        Write-Host $hv_Host;`
    }
}
try {
    Test-Connection -ComputerName $hv_Host -Quiet -Count 1 -ErrorAction Stop | Out-Null
}
catch [System.Net.NetworkInformation.PingException] {
    Write-Host "-----------------------------------------------------" -ForegroundColor Red;`
    Write-Host "Connection test to remote host '$hv_Host' was failed." -ForegroundColor Red;`
    Write-Host "-----------------------------------------------------" -ForegroundColor Red;`
    Write-Host "Make sure WinRM is enabled on the remote host.`nIn the firewall there is an exception for the WinRM service,`nwhich allows access to this computer." -ForegroundColor Red;`
    Write-Host "-----------------------------------------------------" -ForegroundColor Red;`
    Exit
}
# User request for needed params
[string]$vm_Name = $(Write-Host "Input NAME for new VM (Default: $hv_Name_def): " -ForegroundColor Yellow; Read-Host);`
if(-not($vm_Name)) {
    $vm_Name = $hv_Name_def;`
    Write-Host $vm_Name;`
}
[int32]$vm_Generation = $(Write-Host "Set generation type for new VM (Default: $hv_Generation_def) (1/2): " -ForegroundColor Yellow; Read-Host);`
if(-not($vm_Generation)) {
    $vm_Generation = $hv_Generation_def;`
    Write-Host $vm_Generation;`
}
if ($vm_Generation -ne 1 -and $vm_Generation -ne "2") {
    Write-Host "-----------------------------------------------------" -ForegroundColor Red;`
    Write-Host "an ERROR of generation type of created VM" -ForegroundColor Red;`
    Write-Host "-----------------------------------------------------" -ForegroundColor Red;`
    Exit
}

# Display avaliable RAM
$avaliable_memory = Get-CimInstance -Class Win32_OperatingSystem -ComputerName $hv_Host | Select-Object -ExpandProperty FreePhysicalMemory;`
$print_avaliable_memory = [Math]::Round(($avaliable_memory / 1MB), 3);`
Write-Host "Avaliable memory on Host: $print_avaliable_memory GB" -ForegroundColor Green;`
[string]$memory_confirm = $(Write-Host "Will new VM use dynamic memory? (Default: n) (y/n): " -ForegroundColor Yellow; Read-Host);`
if(-not($memory_confirm)) {
    $memory_confirm = "n";`
    Write-Host $memory_confirm;`
}
if ($memory_confirm -match "[yY]") {
    [bool]$dyn_vm_Memory = $true;`
    [int64]$min_vm_Memory = $(Write-Host "Input MINimum RAM size for new VM (MB): " -ForegroundColor Yellow; Read-Host);`
    [int64]$max_vm_Memory = $(Write-Host "Input MAXimum RAM size for new VM (MB): " -ForegroundColor Yellow; Read-Host);`
    [int64]$start_vm_Memory = $(Write-Host "Input starting RAM size for new VM (MB): " -ForegroundColor Yellow; Read-Host);`
    
    # Convert to bytes
    $min_vm_Memory = 1MB*$min_vm_Memory;`
    $max_vm_Memory = 1MB*$max_vm_Memory;`
    $start_vm_Memory = 1MB*$star_vm_tMemory;`
    $print_vm_memory = $vm_Memory;`
    [int64]$vm_Memory = $minvm_Memory;`
} else {
    [int64]$vm_Memory = $(Write-Host "Input RAM size for new VM (Default: $hv_Memory_def) (MB): " -ForegroundColor Yellow; Read-Host);`
    if(-not($vm_Memory)) {
        $vm_Memory = $hv_Memory_def;`
        Write-Host $vm_Memory "MB";`
    }
    # Convert to bytes
    $print_vm_memory = $vm_Memory;`
    $vm_Memory = 1MB*$vm_Memory;`
}
Write-Host "List of avalible switches on host: " -ForegroundColor Yellow;`
$get_switches = Get-VMSwitch -ComputerName $hv_Host | Select-Object -ExpandProperty Name;`
foreach ($sw in $get_switches) {
    Write-Host $sw -ForegroundColor Green;`
}
$def_hv_switch = $get_switches | Select-Object -First 1
[string]$vm_Switch = $(Write-Host "Input a virtual switch name for new VM (Default: $def_hv_switch): " -ForegroundColor Yellow; Read-Host);`
if(-not($vm_Switch)) {
    $vm_Switch = $def_hv_switch;`
    Write-Host $vm_Switch;`
}

# Display CPU usage info
$cpu_usage_persent = Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average | Select-Object -ExpandProperty Average;`
Write-Host "CPU Usage persent on Host: $cpu_usage_persent %" -ForegroundColor Green;`
[int32]$vm_Cpu = $(Write-Host "Input number of CPUs for new VM (Default: $hv_Cpu_def): " -ForegroundColor Yellow; Read-Host);`
if(-not($vm_Cpu)) {
    $vm_Cpu = $hv_Cpu_def;`
    Write-Host $vm_Cpu;`
}

# Display avaliable disk space on Host
Write-Host "Avaliable disk space on Host:" -ForegroundColor Green;`
Get-CimInstance win32_logicaldisk -ComputerName $hv_Host | Format-Table @{n="Letter"; e={$_.DeviceID}}, @{n="Avaliable size (GB)"; e={[math]::Round($_.FreeSpace/1GB,2)}};`
[string]$vm_Path = $(Write-Host "Input path for new VM config files (Default: $hv_storevm_def)" -ForegroundColor Yellow; Read-Host);`
if(-not($vm_Path)) {
    $vm_Path = $hv_storevm_def;`
    Write-Host $vm_Path;`
}
[string]$new_VM_Path = $vm_Path;`
[string]$vhd_Path = $(Write-Host "Input path where .vhdx will reside (Default: $hv_storevhd_def)" -ForegroundColor Yellow; Read-Host);`
if(-not($vhd_Path)) {
    $vhd_Path = $hv_storevhd_def;`
    Write-Host $vhd_Path;`
}
[string]$new_VM_VHD = $vhd_Path+$vm_Name+".vhdx";`
[int64]$vhd_Size = $(Write-Host "Input VHD Size (Default: $hv_Vhdsize_def) (GB): " -ForegroundColor Yellow; Read-Host);`
if(-not($vhd_Size)) {
    $vhd_Size = $hv_Vhdsize_def;`
    Write-Host $vhd_Size "GB";`
}
$print_vhd_Size = $vhd_Size;`
# Converts GB to bytes
$vhd_Size = [math]::round($vhd_Size *1Gb, 3);`

# Confirm creating VM
Write-Host "-----------------------------------------------------" -ForegroundColor Yellow;`
Write-Host "Please check all parameters before create VM" -ForegroundColor Red;`
Write-Host "-----------------------------------------------------" -ForegroundColor Yellow;`

Write-Host "Creating VM on Hyper-v host: " -NoNewline -ForegroundColor Green;`
Write-Host "$hv_Host" -ForegroundColor Cyan;`
Write-Host "With name: " -NoNewline -ForegroundColor Green;`
Write-Host "$vm_Name" -ForegroundColor Cyan;`
Write-Host "Generation type: " -NoNewline -ForegroundColor Green;`
Write-Host $vm_generation -ForegroundColor Cyan;`
Write-Host "Virtual CPUs number: " -NoNewline -ForegroundColor Green;`
Write-Host $vm_Cpu -ForegroundColor Cyan;`
Write-Host "Starting memory: " -NoNewline  -ForegroundColor Green;`
Write-Host $print_vm_memory "MB" -ForegroundColor Cyan;`
Write-Host "Connected to virtual switch: " -NoNewline -ForegroundColor Green;`
Write-Host $vm_Switch -ForegroundColor Cyan;`
Write-Host "Size of created VHD is: " -NoNewline -ForegroundColor Green;`
Write-Host $print_vhd_Size "GB" -ForegroundColor Cyan;`
Write-Host "Stored at: " -NoNewline -ForegroundColor Green;`
Write-Host $new_VM_Path -ForegroundColor Cyan;`
Write-Host "With its .vhdx stored at: " -NoNewline -ForegroundColor Green;`
Write-Host $new_VM_VHD -ForegroundColor Cyan;`
Write-Host "-----------------------------------------------------" -ForegroundColor Yellow;`
$create_confirm = $(Write-Host 'If all parameters right, input "yes" to proseed: ' -ForegroundColor Red; Read-Host);`

if ($create_confirm -match "[yes]") {
    # Create new VM
    try {
        New-VM -ComputerName $hv_Host `
               -Name $vm_Name `
               -Generation $vm_Generation `
               -MemoryStartupBytes $vm_Memory `
               -Path $new_VM_Path `
               -NewVHDPath $new_VM_VHD `
               -NewVHDSizeBytes $vhd_Size `
               | Out-Null;`
        # Paused script for a few seconds to allow VM creation to complete
        Start-Sleep 5;`
        Add-VMNetworkAdapter -ComputerName $hv_Host –VMName $vm_Name –Switchname $vm_Switch;`
        Set-VMProcessor -ComputerName $hv_Host –VMName $vm_Name –count $vm_cpu;`

        if ($dyn_vm_Memory -eq $true) {
            Set-VMMemory -ComputerName $hv_Host –VMName $vm_Name -DynamicMemoryEnabled $true `
                                  -MinimumBytes $minMemory `
                                  -StartupBytes $startMemory `
                                  -MaximumBytes $maxMemory
        }
        # Paused script for a few seconds to allow VM config to complete
        Start-Sleep 8 

        # Display information of created new VM
        Get-VM -ComputerName $hv_Host -VMName $vm_Name | Select-Object Name,State,Generation,ProcessorCount,`
                                                                       @{Label="RAM Memory (MB)";Expression={($_.MemoryStartup/1MB)}},`
                                                                       Path,Status
                                                       | Format-Table -AutoSize;`
        Write-Host "-----------------------------------------------------" -ForegroundColor Yellow;`
        Write-Host "new VM was successfully created" -ForegroundColor Green;`
        Write-Host "-----------------------------------------------------" -ForegroundColor Yellow;`
    } catch {
        Write-Host "an ERROR was encountered creating the new VM" -ForegroundColor Red;`
        Write-Error $_;`
    }
} else {
    Write-Host "Your answer was do not 'yes'" -ForegroundColor Red;`
    Exit
}

# Confirm mount ISO
$mount_confirm = $(Write-Host 'Do you want to mount an ISO image and start installing the OS (work only on AD/non core server) (Default: n) (y/n): ' -ForegroundColor Yellow; Read-Host);`
if (-not($mount_confirm)) {
    $mount_confirm = "n"
}
if ($mount_confirm -match "[yY]") {
    # Mount ISO
    Write-Host "List of avalible ISOs on host: " -ForegroundColor Yellow;`
    $get_iso = Invoke-Command -ComputerName $hv_Host -ScriptBlock {Get-ChildItem -Path C:\ISO\*.iso -Recurse  | Select-Object -ExpandProperty Fullname } -ErrorAction SilentlyContinue;`
    foreach ($iso in $get_iso) {
        Write-Host $iso -ForegroundColor Green;`
    }
    [string]$mount_iso = $(Write-Host "Input path to ISO for mount in new VM: " -ForegroundColor Yellow; Read-Host);`
    Add-VMDvdDrive -ComputerName $hv_Host -VMName $vm_Name -Path $mount_iso;`
    
    # Disable secureboot if Linux
    if ($vm_Generation -eq 2) {
        Write-Host "-----------------------------------------------------" -ForegroundColor Yellow;`
        [string]$os_confirm = $(Write-Host "If you need to instal Linux based OS you need to disable SecureBoot  on created VM.`nDisable SecureBoot on created VM (y/n): " -ForegroundColor Red; Read-Host);`
        if ($os_confirm -match "[yY]") {
        Set-VMFirmware -ComputerName $hv_Host -VMName $vm_Name -EnableSecureBoot Off;`
        }
        $dvd_drive = Get-VMFirmware -ComputerName $hv_Host -VMName $vm_Name | Select-Object -ExpandProperty BootOrder `
                                                | Where-Object { $_.Device -match "DvdDrive" };`

        Set-VMFirmware -ComputerName $hv_Host -VMName $vm_Name -FirstBootDevice $dvd_drive;`
    }
    
    # Start Process to intall OS
    vmconnect.exe $hv_Host $vm_Name; # works on AD

} else {
    Write-Host "Goodbye" -ForegroundColor Green;`
    Exit
}