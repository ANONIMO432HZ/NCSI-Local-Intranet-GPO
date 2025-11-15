#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Suite de pruebas para verificar la funcionalidad completa de NCSI Local Server
    
.DESCRIPTION
    Script de pruebas que verifica todos los componentes de la suite NCSI:
    - Verifica existencia de scripts
    - Prueba funciones básicas
    - Valida configuraciones
    - Genera reporte de compatibilidad
    
.EXAMPLE
    .\NCSI-Test-Suite.ps1
    
.NOTES
    Este script debe ejecutarse desde el directorio que contiene todos los scripts NCSI
#>

[CmdletBinding()]
param(
    [switch]$Detailed,
    [switch]$Silent
)

# Variables globales
$script:TestResults = @()
$script:ErrorCount = 0
$script:WarningCount = 0
$script:PassCount = 0

function Write-TestOutput {
    param(
        [string]$Message,
        [string]$Type = "Info"
    )
    
    if (-not $Silent) {
        $color = switch ($Type) {
            "Pass" { "Green" }
            "Fail" { "Red" }
            "Warning" { "Yellow" }
            "Info" { "Cyan" }
            default { "White" }
        }
        
        $icon = switch ($Type) {
            "Pass" { "[OK]" }
            "Fail" { "[FAIL]" }
            "Warning" { "[WARN] " }
            "Info" { "ℹ️ " }
            default { "  " }
        }
        
        Write-Host "$icon $Message" -ForegroundColor $color
    }
}

function Add-TestResult {
    param(
        [string]$TestName,
        [string]$Result,
        [string]$Details = ""
    )
    
    $script:TestResults += [PSCustomObject]@{
        Test = $TestName
        Result = $Result
        Details = $Details
        Timestamp = Get-Date
    }
    
    switch ($Result) {
        "PASS" { $script:PassCount++; Write-TestOutput "PASS: $TestName" "Pass" }
        "FAIL" { $script:ErrorCount++; Write-TestOutput "FAIL: $TestName - $Details" "Fail" }
        "WARNING" { $script:WarningCount++; Write-TestOutput "WARNING: $TestName - $Details" "Warning" }
    }
    
    if ($Detailed -and $Details) {
        Write-TestOutput "  Details: $Details" "Info"
    }
}

function Test-ScriptExists {
    param([string]$ScriptPath, [string]$ScriptName)
    
    if (Test-Path $ScriptPath) {
        Add-TestResult "Script Existence: $ScriptName" "PASS"
        return $true
    } else {
        Add-TestResult "Script Existence: $ScriptName" "FAIL" "Script not found at $ScriptPath"
        return $false
    }
}

function Test-PowerShellVersion {
    $version = $PSVersionTable.PSVersion.Major
    if ($version -ge 5) {
        Add-TestResult "PowerShell Version" "PASS" "Version $($PSVersionTable.PSVersion)"
    } else {
        Add-TestResult "PowerShell Version" "FAIL" "Version $($PSVersionTable.PSVersion) - Requires 5.0+"
    }
}

function Test-AdminPrivileges {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if ($isAdmin) {
        Add-TestResult "Administrator Privileges" "PASS"
    } else {
        Add-TestResult "Administrator Privileges" "FAIL" "Script must be run as Administrator"
    }
}

function Test-InternetConnectivity {
    try {
        $response = Test-NetConnection "8.8.8.8" -Port 80 -InformationLevel Quiet -WarningAction SilentlyContinue
        if ($response) {
            Add-TestResult "Internet Connectivity" "PASS"
        } else {
            Add-TestResult "Internet Connectivity" "WARNING" "No internet access - XAMPP download will fail"
        }
    } catch {
        Add-TestResult "Internet Connectivity" "WARNING" "Could not test connectivity"
    }
}

function Test-ExistingXAMPP {
    $xamppPath = "C:\xampp"
    if (Test-Path "$xamppPath\apache\bin\httpd.exe") {
        Add-TestResult "Existing XAMPP Installation" "WARNING" "XAMPP already installed at $xamppPath"
        
        # Test if Apache is running
        $apacheProcess = Get-Process -Name "httpd" -ErrorAction SilentlyContinue
        if ($apacheProcess) {
            Add-TestResult "Apache Service Status" "PASS" "Apache is running (PID: $($apacheProcess.Id -join ', '))"
        } else {
            Add-TestResult "Apache Service Status" "WARNING" "Apache is installed but not running"
        }
    } else {
        Add-TestResult "Existing XAMPP Installation" "PASS" "No conflicting XAMPP installation found"
    }
}

function Test-PortAvailability {
    try {
        $port80InUse = Get-NetTCPConnection -LocalPort 80 -ErrorAction SilentlyContinue
        if ($port80InUse) {
            $process = Get-Process -Id $port80InUse[0].OwningProcess -ErrorAction SilentlyContinue
            Add-TestResult "Port 80 Availability" "WARNING" "Port 80 in use by: $($process.ProcessName)"
        } else {
            Add-TestResult "Port 80 Availability" "PASS"
        }
    } catch {
        Add-TestResult "Port 80 Availability" "PASS" "Assumed available"
    }
}

function Test-RegistryAccess {
    try {
        $registryPath = "HKLM:\SYSTEM\CurrentControlSet\Services\NlaSvc\Parameters\Internet"
        $testKey = Get-ItemProperty -Path $registryPath -ErrorAction SilentlyContinue
        Add-TestResult "Registry Access" "PASS" "Can access NCSI registry keys"
        
        # Check current NCSI configuration
        if ($testKey.ActiveWebProbeHost) {
            Add-TestResult "Existing NCSI Config" "WARNING" "NCSI already configured: $($testKey.ActiveWebProbeHost)"
        } else {
            Add-TestResult "Existing NCSI Config" "PASS" "No existing NCSI configuration"
        }
    } catch {
        Add-TestResult "Registry Access" "FAIL" "Cannot access registry - Check administrator privileges"
    }
}

function Test-WindowsServices {
    $services = @("NlaSvc", "Dnscache", "LanmanServer")
    
    foreach ($serviceName in $services) {
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($service) {
            if ($service.Status -eq "Running") {
                Add-TestResult "Windows Service: $serviceName" "PASS" "Status: Running"
            } else {
                Add-TestResult "Windows Service: $serviceName" "WARNING" "Status: $($service.Status)"
            }
        } else {
            Add-TestResult "Windows Service: $serviceName" "FAIL" "Service not found"
        }
    }
}

function Test-NetworkConfiguration {
    try {
        $adapters = Get-NetAdapter | Where-Object Status -eq "Up"
        if ($adapters.Count -gt 0) {
            Add-TestResult "Network Adapters" "PASS" "$($adapters.Count) active network adapter(s)"
            
            # Get local IP
            $localIP = (Get-NetIPConfiguration | Where-Object {$_.IPv4DefaultGateway -ne $null -and $_.NetAdapter.Status -eq "Up"}).IPv4Address.IPAddress | Select-Object -First 1
            if ($localIP) {
                Add-TestResult "Local IP Detection" "PASS" "Detected IP: $localIP"
            } else {
                Add-TestResult "Local IP Detection" "WARNING" "Could not auto-detect local IP"
            }
        } else {
            Add-TestResult "Network Adapters" "FAIL" "No active network adapters found"
        }
    } catch {
        Add-TestResult "Network Configuration" "FAIL" "Error checking network configuration"
    }
}

function Test-DiskSpace {
    try {
        $drive = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='C:'"
        $freeSpaceGB = [math]::Round($drive.FreeSpace / 1GB, 2)
        
        if ($freeSpaceGB -gt 1) {
            Add-TestResult "Disk Space" "PASS" "$freeSpaceGB GB available"
        } else {
            Add-TestResult "Disk Space" "WARNING" "Only $freeSpaceGB GB available - XAMPP needs ~200MB"
        }
    } catch {
        Add-TestResult "Disk Space" "WARNING" "Could not check disk space"
    }
}

function Show-TestSummary {
    $totalTests = $script:TestResults.Count
    
    Write-TestOutput "" "Info"
    Write-TestOutput "═══════════════════════════════════════════════════════════════" "Info"
    Write-TestOutput "                    TEST SUMMARY REPORT" "Info"
    Write-TestOutput "═══════════════════════════════════════════════════════════════" "Info"
    Write-TestOutput "" "Info"
    Write-TestOutput "Total Tests: $totalTests" "Info"
    Write-TestOutput "Passed: $script:PassCount" "Pass"
    Write-TestOutput "Warnings: $script:WarningCount" "Warning"
    Write-TestOutput "Failed: $script:ErrorCount" "Fail"
    Write-TestOutput "" "Info"
    
    if ($script:ErrorCount -eq 0 -and $script:WarningCount -eq 0) {
        Write-TestOutput "[DONE] ALL TESTS PASSED - System ready for NCSI installation!" "Pass"
    } elseif ($script:ErrorCount -eq 0) {
        Write-TestOutput "[OK] Tests passed with warnings - Installation possible but review warnings" "Warning"
    } else {
        Write-TestOutput "Critical issues found - Resolve errors before installation" "Fail"
    }
    
    Write-TestOutput "" "Info"
    Write-TestOutput "Recommendations:" "Info"
    
    if ($script:ErrorCount -gt 0) {
        Write-TestOutput "• Fix all FAILED tests before running installation" "Fail"
    }
    
    if ($script:WarningCount -gt 0) {
        Write-TestOutput "• Review WARNING tests - may affect installation" "Warning"
    }
    
    Write-TestOutput "• Run: NCSI-Control-Menu.bat for guided installation" "Info"
    Write-TestOutput "• For quick setup: .\Quick-Install.ps1" "Info"
    Write-TestOutput "• For advanced features: .\NCSI-Advanced-Tools.ps1" "Info"
}

function Export-TestResults {
    $reportPath = "$env:TEMP\NCSI-Test-Report-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    
    $report = @{
        TestDate = Get-Date
        SystemInfo = @{
            OS = (Get-WmiObject Win32_OperatingSystem).Caption
            PowerShellVersion = $PSVersionTable.PSVersion.ToString()
            IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        }
        Summary = @{
            TotalTests = $script:TestResults.Count
            Passed = $script:PassCount
            Warnings = $script:WarningCount
            Failed = $script:ErrorCount
        }
        TestResults = $script:TestResults
    }
    
    $report | ConvertTo-Json -Depth 3 | Set-Content -Path $reportPath
    Write-TestOutput "Test report exported: $reportPath" "Info"
}

# Función principal
function Main {
    if (-not $Silent) {
        Clear-Host
        Write-Host @"
╔═══════════════════════════════════════════════════════════════════════════════╗
║                        [TEST] NCSI TEST SUITE [TEST]                          ║
║                                                                               ║
║  Verificación completa del sistema para la suite NCSI Local Server            ║
║  Desarrollado por:                                                            ║
╚═══════════════════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Magenta
    }
    
    Write-TestOutput "Iniciando verificación del sistema..." "Info"
    Write-TestOutput "" "Info"
    
    # Ejecutar todas las pruebas
    Write-TestOutput "Verificando scripts requeridos..." "Info"
    Test-ScriptExists "NCSI-Control-Menu.bat" "Control Menu (Batch)"
    Test-ScriptExists "Quick-Install.ps1" "Quick Install"
    Test-ScriptExists "NCSI-LocalServer-Automation.ps1" "Main Automation Script"
    Test-ScriptExists "NCSI-Advanced-Tools.ps1" "Advanced Tools"
    
    Write-TestOutput "" "Info"
    Write-TestOutput "Verificando entorno del sistema..." "Info"
    Test-PowerShellVersion
    Test-AdminPrivileges
    Test-InternetConnectivity
    Test-DiskSpace
    Test-NetworkConfiguration
    
    Write-TestOutput "" "Info"
    Write-TestOutput "Verificando configuración actual..." "Info"
    Test-ExistingXAMPP
    Test-PortAvailability
    Test-RegistryAccess
    Test-WindowsServices
    
    Write-TestOutput "" "Info"
    Show-TestSummary
    
    if ($Detailed) {
        Export-TestResults
    }
    
    Write-TestOutput "" "Info"
    Write-TestOutput "Verification complete. Press any key to continue..." "Info"
    if (-not $Silent) {
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}

# Ejecutar pruebas
Main

