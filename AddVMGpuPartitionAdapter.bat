@echo off
setlocal enabledelayedexpansion
set /a x=0
echo PartitionableGpuName:
for /f %%i in ('PowerShell "Get-VMHostPartitionableGpu | Format-Wide -Column 1 -Property Name | Out-String -Width 120"') do (
    set PartitionName[!x!]=%%i
    echo !x!: %%i
    set /a x+=1
)
@echo.
set /a x=0
set /p x=Select(number, leave blank to use "0"):
@echo.
set /a x=%x%
set "SelectedPartitionableGpu=%%PartitionName[%x%]%%"
echo ValidPartitionCounts:
for /f "delims=	" %%i in ('PowerShell "$FormatEnumerationLimit=-1; Get-VMHostPartitionableGpu -Name '%SelectedPartitionableGpu%' | Format-Wide -Column 1 -Property ValidPartitionCounts"') do echo %%i
for /f %%i in ('PowerShell "Get-VMHostPartitionableGpu -Name '%SelectedPartitionableGpu%' | Format-Wide -Column 1 -Property PartitionCount"') do (
    set /a x=%%i
    echo SelectedPartitionCount: %%i
)
@echo.
set /p x=Select(number, leave blank to use selected):
@echo.
set /a x=%x%
for /f %%i in ('PowerShell "Set-VMHostPartitionableGpu -Name '%SelectedPartitionableGpu%' -PartitionCount '%x%'"') do next
set /p VMName=VMName(string, leave blank to skip):
@echo.
if defined %VMName% do (
    for /f %%i in ('PowerShell "Set-VM -AutomaticStopAction "ShutDown" -GuestControlledCacheTypes $true -LowMemoryMappedIoSpace 1Gb -HighMemoryMappedIoSpace 128Gb -VMName '%VMName%'; Add-VMGpuPartitionAdapter -VMName '%VMName%' -InstancePath '%SelectedPartitionableGpu%'"') do next
    if %x% equ 32 (
        reg add HKLM\SOFTWARE\Policies\Microsoft\Windows\HyperV /v RequireSupportedDeviceAssignment /t REG_DWORD /d 0
        reg add HKLM\SOFTWARE\Policies\Microsoft\Windows\HyperV /v RequireSecureDeviceAssignment /t REG_DWORD /d 0
    )
)
echo Done.
timeout /t 1 /nobreak >nul  2>nul
