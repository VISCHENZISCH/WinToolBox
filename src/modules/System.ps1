# System information, through CIM: wmic was removed from recent versions of Windows.

function Show-SystemInfo {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $computer = Get-CimInstance -ClassName Win32_ComputerSystem
    $bios = Get-CimInstance -ClassName Win32_BIOS
    $cpu = @(Get-CimInstance -ClassName Win32_Processor)
    $uptime = (Get-Date) - $os.LastBootUpTime

    $summary = [ordered]@{
        'Computer'   = $os.CSName
        'System'     = '{0} ({1}, build {2})' -f $os.Caption, $os.OSArchitecture, $os.BuildNumber
        'Model'      = '{0} {1}' -f $computer.Manufacturer, $computer.Model
        'BIOS'       = $bios.SMBIOSBIOSVersion
        'Processor'  = '{0} ({1} cores, {2} threads)' -f $cpu[0].Name.Trim(), ($cpu | Measure-Object -Property NumberOfCores -Sum).Sum, ($cpu | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum
        'Memory'     = '{0} free of {1}' -f (Format-Bytes ($os.FreePhysicalMemory * 1KB)), (Format-Bytes $computer.TotalPhysicalMemory)
        'Last boot'  = '{0:yyyy-MM-dd HH:mm} (up {1} d {2} h)' -f $os.LastBootUpTime, $uptime.Days, $uptime.Hours
    }
    Write-Details $summary

    Write-Section 'Local drives'
    Write-Table -Rows @(Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType=3' | Select-Object @{ n = 'Drive'; e = { $_.DeviceID } },
        @{ n = 'Label'; e = { $_.VolumeName } }, @{ n = 'Format'; e = { $_.FileSystem } },
        @{ n = 'Free'; e = { Format-Bytes $_.FreeSpace } },
        @{ n = 'Size'; e = { Format-Bytes $_.Size } })
}

function Show-StartupPrograms {
    Write-Table -Empty 'No startup programs.' -Rows @(Get-CimInstance -ClassName Win32_StartupCommand | Sort-Object Name | Select-Object Name, User, Location, Command)
}

function Show-FailedServices {
    $services = @(Get-CimInstance -ClassName Win32_Service -Filter "StartMode='Auto' AND State<>'Running' AND ExitCode<>0")
    if ($services.Count -eq 0) {
        Write-Status OK 'No failed automatic services.'
        return
    }
    Write-Table -Rows @($services | Select-Object Name, DisplayName, ExitCode)
}

function Show-SystemMenu {
    Show-Menu -Title 'System information' -Items @(
        @{ Section = 'OVERVIEW'; Key = '1'; Label = 'System summary'; Hint = 'hardware, memory, drives'; Action = { Show-SystemInfo } }
        @{ Section = 'ACTIVITY'; Key = '2'; Label = 'Startup programs'; Action = { Show-StartupPrograms } }
        @{ Section = 'ACTIVITY'; Key = '3'; Label = 'Failed automatic services'; Action = { Show-FailedServices } }
    )
}
