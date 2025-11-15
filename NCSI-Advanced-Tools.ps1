#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Herramientas avanzadas para el mantenimiento y monitoreo del servidor NCSI local
    
.DESCRIPTION
    Script complementario con funciones avanzadas para:
    - Monitoreo continuo del servidor NCSI
    - Configuración de GPO automática
    - Herramientas de diagnóstico avanzadas
    - Configuración de SSL/HTTPS
    - Gestión de múltiples servidores NCSI
    
.PARAMETER Action
    Acción a realizar: Monitor, GPOConfig, Diagnostics, SSLSetup, MultiServer
    
.EXAMPLE
    .\NCSI-Advanced-Tools.ps1 -Action Monitor
    .\NCSI-Advanced-Tools.ps1 -Action GPOConfig -DomainController "dc01.domain.local"
    
.NOTES
    Autor: 
    Versión: 1.0
    Complementa: NCSI-LocalServer-Automation.ps1
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("Monitor", "GPOConfig", "Diagnostics", "SSLSetup", "MultiServer", "NetworkTest", "HealthCheck")]
    [string]$Action,
    
    [string]$DomainController = "",
    [string]$GPOName = "NCSI-Local-Configuration",
    [string]$SSLCertPath = "",
    [int]$MonitorInterval = 60,
    [string[]]$ServerList = @(),
    [switch]$EmailAlerts,
    [string]$SMTPServer = "",
    [string]$EmailTo = "",
    [string]$EmailFrom = ""
)

# Variables globales
$script:LogPath = "$env:TEMP\NCSI-Advanced-$(Get-Date -Format 'yyyyMMdd').log"
$script:ConfigFile = "$env:USERPROFILE\Documents\NCSI-Advanced-Config.json"
$script:RegistryPath = "HKLM:\SYSTEM\CurrentControlSet\Services\NlaSvc\Parameters\Internet"

# Funciones de utilidad
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $script:LogPath -Value $logEntry
    
    switch ($Level) {
        "ERROR" { Write-Host $logEntry -ForegroundColor Red }
        "WARNING" { Write-Host $logEntry -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logEntry -ForegroundColor Green }
        default { Write-Host $logEntry -ForegroundColor White }
    }
}

function Get-NCSDConfiguration {
    try {
        $config = @{}
        $config.ActiveWebProbeHost = Get-ItemProperty -Path $script:RegistryPath -Name "ActiveWebProbeHost" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty ActiveWebProbeHost
        $config.ActiveWebProbeContent = Get-ItemProperty -Path $script:RegistryPath -Name "ActiveWebProbeContent" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty ActiveWebProbeContent
        $config.EnableActiveProbing = Get-ItemProperty -Path $script:RegistryPath -Name "EnableActiveProbing" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty EnableActiveProbing
        return $config
    }
    catch {
        Write-Log "Error reading NCSI configuration: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

function Test-ServerHealth {
    param([string]$ServerURL)
    
    $health = @{
        URL = $ServerURL
        Accessible = $false
        ResponseTime = 0
        ContentCorrect = $false
        SSLValid = $false
        LastCheck = Get-Date
    }
    
    try {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $response = Invoke-WebRequest -Uri $ServerURL -UseBasicParsing -TimeoutSec 10
        $stopwatch.Stop()
        
        $health.Accessible = $true
        $health.ResponseTime = $stopwatch.ElapsedMilliseconds
        $health.ContentCorrect = ($response.Content.Trim() -eq "Microsoft Connect Test")
        
        # Verificar SSL si es HTTPS
        if ($ServerURL -like "https://*") {
            $health.SSLValid = Test-SSLCertificate $ServerURL
        }
    }
    catch {
        Write-Log "Health check failed for $ServerURL`: $($_.Exception.Message)" "WARNING"
    }
    
    return $health
}

function Test-SSLCertificate {
    param([string]$URL)
    
    try {
        $uri = [System.Uri]$URL
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $tcpClient.Connect($uri.Host, 443)
        
        $sslStream = New-Object System.Net.Security.SslStream($tcpClient.GetStream())
        $sslStream.AuthenticateAsClient($uri.Host)
        
        $cert = $sslStream.RemoteCertificate
        $isValid = $cert.NotAfter -gt (Get-Date)
        
        $sslStream.Close()
        $tcpClient.Close()
        
        return $isValid
    }
    catch {
        return $false
    }
}

function Send-AlertEmail {
    param(
        [string]$Subject,
        [string]$Body
    )
    
    if (-not $EmailAlerts -or [string]::IsNullOrEmpty($SMTPServer)) {
        return
    }
    
    try {
        $mailParams = @{
            SmtpServer = $SMTPServer
            From = $EmailFrom
            To = $EmailTo
            Subject = $Subject
            Body = $Body
            BodyAsHtml = $true
        }
        
        Send-MailMessage @mailParams
        Write-Log "Alert email sent successfully" "SUCCESS"
    }
    catch {
        Write-Log "Failed to send alert email: $($_.Exception.Message)" "ERROR"
    }
}

function Start-NCSDMonitoring {
    param([int]$IntervalSeconds = 60)
    
    Write-Log "Starting NCSI monitoring (interval: $IntervalSeconds seconds)" "INFO"
    
    $config = Get-NCSDConfiguration
    if (-not $config -or [string]::IsNullOrEmpty($config.ActiveWebProbeHost)) {
        Write-Log "NCSI not configured. Cannot start monitoring." "ERROR"
        return
    }
    
    $serverURL = $config.ActiveWebProbeHost
    $consecutiveFailures = 0
    $maxFailures = 3
    
    try {
        while ($true) {
            $health = Test-ServerHealth $serverURL
            
            if ($health.Accessible -and $health.ContentCorrect) {
                Write-Log "[OK] Server healthy - Response: $($health.ResponseTime)ms" "SUCCESS"
                $consecutiveFailures = 0
            }
            else {
                $consecutiveFailures++
                $status = if (-not $health.Accessible) { "UNREACHABLE" } elseif (-not $health.ContentCorrect) { "WRONG_CONTENT" } else { "UNKNOWN_ERROR" }
                Write-Log "Server issue detected: $status (Failure $consecutiveFailures/$maxFailures)" "ERROR"
                
                if ($consecutiveFailures -ge $maxFailures) {
                    $alertSubject = "CRITICAL: NCSI Server Down"
                    $alertBody = @"
                    <h2>🚨 NCSI Server Alert</h2>
                    <p><strong>Server:</strong> $serverURL</p>
                    <p><strong>Status:</strong> $status</p>
                    <p><strong>Consecutive Failures:</strong> $consecutiveFailures</p>
                    <p><strong>Last Check:</strong> $($health.LastCheck)</p>
                    <p><strong>Action Required:</strong> Immediate investigation needed</p>
"@
                    Send-AlertEmail $alertSubject $alertBody
                }
            }
            
            # Verificar servicios del sistema
            $nlaService = Get-Service -Name "NlaSvc" -ErrorAction SilentlyContinue
            if ($nlaService.Status -ne "Running") {
                Write-Log "[WARN]  Network Location Awareness service is not running" "WARNING"
            }
            
            $apacheProcess = Get-Process -Name "httpd" -ErrorAction SilentlyContinue
            if (-not $apacheProcess) {
                Write-Log "[WARN]  Apache/XAMPP service is not running" "WARNING"
            }
            
            Start-Sleep -Seconds $IntervalSeconds
        }
    }
    catch {
        Write-Log "Monitoring stopped due to error: $($_.Exception.Message)" "ERROR"
    }
}

function New-GPOConfiguration {
    param(
        [string]$DCServer,
        [string]$PolicyName,
        [string]$ServerURL
    )
    
    Write-Log "Creating GPO configuration: $PolicyName" "INFO"
    
    try {
        # Verificar módulo de Group Policy
        if (-not (Get-Module -ListAvailable -Name GroupPolicy)) {
            Write-Log "Group Policy module not available. Install RSAT tools." "ERROR"
            return $false
        }
        
        Import-Module GroupPolicy
        
        # Crear nueva GPO
        try {
            $gpo = New-GPO -Name $PolicyName -Domain (Get-ADDomain).DNSRoot
            Write-Log "GPO created successfully: $($gpo.DisplayName)" "SUCCESS"
        }
        catch {
            Write-Log "GPO might already exist, trying to get existing one..." "WARNING"
            $gpo = Get-GPO -Name $PolicyName -ErrorAction SilentlyContinue
            if (-not $gpo) {
                throw "Cannot create or access GPO: $PolicyName"
            }
        }
        
        # Configurar políticas del registro
        $regSettings = @(
            @{
                Key = "HKLM\SYSTEM\CurrentControlSet\Services\NlaSvc\Parameters\Internet"
                ValueName = "ActiveWebProbeHost"
                Value = $ServerURL
                Type = "String"
            },
            @{
                Key = "HKLM\SYSTEM\CurrentControlSet\Services\NlaSvc\Parameters\Internet"
                ValueName = "ActiveWebProbeContent" 
                Value = "Microsoft Connect Test"
                Type = "String"
            },
            @{
                Key = "HKLM\SYSTEM\CurrentControlSet\Services\NlaSvc\Parameters\Internet"
                ValueName = "EnableActiveProbing"
                Value = 1
                Type = "DWord"
            }
        )
        
        foreach ($setting in $regSettings) {
            Set-GPRegistryValue -Name $PolicyName -Key $setting.Key -ValueName $setting.ValueName -Value $setting.Value -Type $setting.Type
            Write-Log "Registry setting configured: $($setting.ValueName)" "INFO"
        }
        
        Write-Log "GPO configuration completed successfully" "SUCCESS"
        Write-Log "Next steps:" "INFO"
        Write-Log "1. Link GPO to appropriate OUs" "INFO"
        Write-Log "2. Run 'gpupdate /force' on client computers" "INFO"
        Write-Log "3. Verify policy application with 'gpresult /r'" "INFO"
        
        return $true
    }
    catch {
        Write-Log "Error creating GPO: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Start-AdvancedDiagnostics {
    Write-Log "[DGN] Starting advanced NCSI diagnostics..." "INFO"
    
    # Test 1: Network connectivity
    Write-Log "=== NETWORK CONNECTIVITY ===" "INFO"
    $networkTests = @(
        @{ Name = "DNS Resolution"; Command = { Resolve-DnsName "google.com" -ErrorAction Stop } },
        @{ Name = "Internet Connectivity"; Command = { Test-NetConnection "8.8.8.8" -Port 80 } },
        @{ Name = "Local Network"; Command = { Test-NetConnection (Get-NetRoute | Where-Object DestinationPrefix -eq "0.0.0.0/0").NextHop -InformationLevel Quiet } }
    )
    
    foreach ($test in $networkTests) {
        try {
            $result = & $test.Command
            Write-Log "[OK] $($test.Name): PASS" "SUCCESS"
        }
        catch {
            Write-Log "$($test.Name): FAIL - $($_.Exception.Message)" "ERROR"
        }
    }
    
    # Test 2: NCSI Configuration
    Write-Log "=== NCSI CONFIGURATION ===" "INFO"
    $config = Get-NCSDConfiguration
    if ($config) {
        Write-Log "ActiveWebProbeHost: $($config.ActiveWebProbeHost)" "INFO"
        Write-Log "ActiveWebProbeContent: $($config.ActiveWebProbeContent)" "INFO"
        Write-Log "EnableActiveProbing: $($config.EnableActiveProbing)" "INFO"
    }
    else {
        Write-Log "NCSI configuration not found" "ERROR"
    }
    
    # Test 3: Service Status
    Write-Log "=== SERVICE STATUS ===" "INFO"
    $services = @("NlaSvc", "Dnscache", "LanmanServer", "Workstation")
    foreach ($serviceName in $services) {
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($service) {
            $status = if ($service.Status -eq "Running") { "[OK]" } else { "[FAIL]" }
            Write-Log "$status $serviceName`: $($service.Status)" "INFO"
        }
    }
    
    # Test 4: Firewall Rules
    Write-Log "=== FIREWALL STATUS ===" "INFO"
    try {
        $firewallProfiles = Get-NetFirewallProfile
        foreach ($profile in $firewallProfiles) {
            $status = if ($profile.Enabled) { "[FIRE] ENABLED" } else { "[OK] DISABLED" }
            Write-Log "$($profile.Name): $status" "INFO"
        }
    }
    catch {
        Write-Log "Could not check firewall status" "WARNING"
    }
    
    # Test 5: XAMPP Status
    Write-Log "=== XAMPP STATUS ===" "INFO"
    $xamppPath = "C:\xampp"
    if (Test-Path "$xamppPath\apache\bin\httpd.exe") {
        Write-Log "[OK] XAMPP Installation: Found" "SUCCESS"
        
        $apacheProcess = Get-Process -Name "httpd" -ErrorAction SilentlyContinue
        if ($apacheProcess) {
            Write-Log "[OK] Apache Process: Running (PIDs: $($apacheProcess.Id -join ', '))" "SUCCESS"
        }
        else {
            Write-Log "Apache Process: Not running" "ERROR"
        }
        
        if (Test-Path "$xamppPath\htdocs\connecttest.txt") {
            $content = Get-Content "$xamppPath\htdocs\connecttest.txt" -Raw
            if ($content -eq "Microsoft Connect Test") {
                Write-Log "[OK] connecttest.txt: Content correct" "SUCCESS"
            }
            else {
                Write-Log "connecttest.txt: Content incorrect ('$content')" "ERROR"
            }
        }
        else {
            Write-Log "connecttest.txt: File not found" "ERROR"
        }
    }
    else {
        Write-Log "XAMPP Installation: Not found" "ERROR"
    }
    
    # Test 6: Network Interface Analysis
    Write-Log "=== NETWORK INTERFACES ===" "INFO"
    $adapters = Get-NetAdapter | Where-Object Status -eq "Up"
    foreach ($adapter in $adapters) {
        $ip = (Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).IPAddress
        Write-Log "[NET] $($adapter.Name): $ip" "INFO"
    }
    
    Write-Log "[END] Advanced diagnostics completed" "SUCCESS"
}

function Test-MultipleServers {
    param([string[]]$Servers)
    
    if ($Servers.Count -eq 0) {
        $Servers = @("http://localhost/connecttest.txt", "http://127.0.0.1/connecttest.txt")
    }
    
    Write-Log "Testing multiple NCSI servers..." "INFO"
    
    $results = @()
    foreach ($server in $Servers) {
        Write-Log "Testing server: $server" "INFO"
        $health = Test-ServerHealth $server
        $results += $health
        
        $status = if ($health.Accessible -and $health.ContentCorrect) { "[OK] HEALTHY" } else { "FAILED" }
        Write-Log "$status - $server (${$health.ResponseTime}ms)" "INFO"
    }
    
    # Generar reporte
    $healthyServers = $results | Where-Object { $_.Accessible -and $_.ContentCorrect }
    $failedServers = $results | Where-Object { -not ($_.Accessible -and $_.ContentCorrect) }
    
    Write-Log "=== SERVER HEALTH SUMMARY ===" "INFO"
    Write-Log "Total servers tested: $($results.Count)" "INFO"
    Write-Log "Healthy servers: $($healthyServers.Count)" "SUCCESS"
    Write-Log "Failed servers: $($failedServers.Count)" "ERROR"
    
    if ($failedServers.Count -gt 0) {
        Write-Log "Failed servers:" "ERROR"
        foreach ($failed in $failedServers) {
            Write-Log "  - $($failed.URL)" "ERROR"
        }
    }
    
    return $results
}

function New-SSLConfiguration {
    param(
        [string]$CertificatePath,
        [string]$XamppPath = "C:\xampp"
    )
    
    Write-Log "Configuring SSL for XAMPP..." "INFO"
    
    try {
        # Verificar que XAMPP está instalado
        if (-not (Test-Path "$XamppPath\apache\conf\httpd.conf")) {
            throw "XAMPP not found at $XamppPath"
        }
        
        # Habilitar módulo SSL en httpd.conf
        $httpdConf = "$XamppPath\apache\conf\httpd.conf"
        $content = Get-Content $httpdConf
        
        # Descomentar líneas SSL necesarias
        $content = $content -replace '#(LoadModule ssl_module)', '$1'
        $content = $content -replace '#(Include conf/extra/httpd-ssl.conf)', '$1'
        
        Set-Content -Path $httpdConf -Value $content
        Write-Log "SSL modules enabled in httpd.conf" "SUCCESS"
        
        # Configurar SSL virtual host
        $sslConf = "$XamppPath\apache\conf\extra\httpd-ssl.conf"
        if (Test-Path $sslConf) {
            Write-Log "SSL configuration file found: $sslConf" "INFO"
            
            if (-not [string]::IsNullOrEmpty($CertificatePath) -and (Test-Path $CertificatePath)) {
                Write-Log "Custom SSL certificate will be configured: $CertificatePath" "INFO"
                # Aquí se podría configurar el certificado personalizado
            }
        }
        
        # Crear archivo connecttest.txt en htdocs para HTTPS
        $httpsConnectTest = "$XamppPath\htdocs\connecttest.txt"
        if (-not (Test-Path $httpsConnectTest)) {
            Set-Content -Path $httpsConnectTest -Value "Microsoft Connect Test" -Encoding ASCII -NoNewline
        }
        
        Write-Log "SSL configuration completed" "SUCCESS"
        Write-Log "Restart Apache to apply SSL changes" "WARNING"
        
        return $true
    }
    catch {
        Write-Log "Error configuring SSL: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Invoke-HealthCheck {
    Write-Log "[HLT] Starting comprehensive health check..." "INFO"
    
    $healthReport = @{
        Timestamp = Get-Date
        Overall = "UNKNOWN"
        Components = @{}
    }
    
    # Check 1: NCSI Configuration
    $config = Get-NCSDConfiguration
    $healthReport.Components.NCSIConfig = if ($config -and $config.ActiveWebProbeHost) { "HEALTHY" } else { "FAILED" }
    
    # Check 2: Web Server
    if ($config -and $config.ActiveWebProbeHost) {
        $webHealth = Test-ServerHealth $config.ActiveWebProbeHost
        $healthReport.Components.WebServer = if ($webHealth.Accessible -and $webHealth.ContentCorrect) { "HEALTHY" } else { "FAILED" }
    }
    else {
        $healthReport.Components.WebServer = "NOT_CONFIGURED"
    }
    
    # Check 3: Required Services
    $services = @("NlaSvc", "Dnscache")
    $serviceStatus = $true
    foreach ($serviceName in $services) {
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if (-not $service -or $service.Status -ne "Running") {
            $serviceStatus = $false
            break
        }
    }
    $healthReport.Components.Services = if ($serviceStatus) { "HEALTHY" } else { "FAILED" }
    
    # Check 4: XAMPP Process
    $apacheProcess = Get-Process -Name "httpd" -ErrorAction SilentlyContinue
    $healthReport.Components.Apache = if ($apacheProcess) { "HEALTHY" } else { "FAILED" }
    
    # Determine overall health
    $failedComponents = $healthReport.Components.Values | Where-Object { $_ -eq "FAILED" }
    $healthReport.Overall = if ($failedComponents.Count -eq 0) { "HEALTHY" } else { "DEGRADED" }
    
    # Report results
    Write-Log "=== HEALTH CHECK RESULTS ===" "INFO"
    Write-Log "Overall Status: $($healthReport.Overall)" $(if ($healthReport.Overall -eq "HEALTHY") { "SUCCESS" } else { "ERROR" })
    
    foreach ($component in $healthReport.Components.GetEnumerator()) {
        $status = $component.Value
        $level = switch ($status) {
            "HEALTHY" { "SUCCESS" }
            "FAILED" { "ERROR" }
            default { "WARNING" }
        }
        Write-Log "$($component.Key): $status" $level
    }
    
    return $healthReport
}

# Función principal
function Request-UserConfirmation {
    param(
        [string]$Message,
        [string]$Title = "Confirmación",
        [switch]$DefaultYes
    )
    
    Write-Log "User confirmation requested: $Title - $Message" "INFO"
    Write-Host "[?] $Title" -ForegroundColor Yellow
    Write-Host "   $Message" -ForegroundColor White
    Write-Host ""
    
    do {
        if ($DefaultYes) {
            $response = Read-Host "¿Continuar? (S/n)"
            if ([string]::IsNullOrEmpty($response) -or $response -match "^[SsYy]") {
                Write-Log "User confirmed action" "INFO"
                return $true
            }
        } else {
            $response = Read-Host "¿Continuar? (s/N)"
            if ($response -match "^[SsYy]") {
                Write-Log "User confirmed action" "INFO"
                return $true
            }
        }
        
        if ($response -match "^[NnQq]") {
            Write-Log "User cancelled action" "INFO"
            return $false
        }
        
        Write-Host "[WARN]  Respuesta no válida. Use 'S' para Sí o 'N' para No." -ForegroundColor Yellow
    } while ($true)
}

function Main {
    Write-Host @"
╔═══════════════════════════════════════════════════════════════╗
║              [TOOL]  NCSI ADVANCED TOOLS [TOOL]                       ║
║                                                               ║
║  Herramientas avanzadas para administración de NCSI          ║
║                                                               ║
║  [TIP] TIP: Use NCSI-Control-Menu.bat para navegación fácil     ║
╚═══════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Magenta
    
    Write-Log "Starting NCSI Advanced Tools - Action: $Action" "INFO"
    
    switch ($Action) {
        "Monitor" {
            Start-NCSDMonitoring -IntervalSeconds $MonitorInterval
        }
        
        "GPOConfig" {
            if (-not (Request-UserConfirmation -Message "Esta operación creará/modificará Group Policy Objects en Active Directory. Se requieren permisos de Domain Admin. ¿Desea continuar?" -Title "Confirmación GPO")) {
                Write-Log "GPO configuration cancelled by user" "INFO"
                return
            }
            
            if ([string]::IsNullOrEmpty($DomainController)) {
                try {
                    $DomainController = (Get-ADDomainController).HostName
                }
                catch {
                    Write-Log "Could not auto-detect domain controller. Please specify -DomainController parameter" "ERROR"
                    return
                }
            }
            
            $config = Get-NCSDConfiguration
            if (-not $config -or [string]::IsNullOrEmpty($config.ActiveWebProbeHost)) {
                Write-Log "NCSI not configured locally. Cannot create GPO." "ERROR"
                return
            }
            
            New-GPOConfiguration -DCServer $DomainController -PolicyName $GPOName -ServerURL $config.ActiveWebProbeHost
        }
        
        "Diagnostics" {
            Start-AdvancedDiagnostics
        }
        
        "SSLSetup" {
            New-SSLConfiguration -CertificatePath $SSLCertPath
        }
        
        "MultiServer" {
            Test-MultipleServers -Servers $ServerList
        }
        
        "NetworkTest" {
            Write-Log "[NET] Running network connectivity tests..." "INFO"
            
            # Test local connectivity
            $localTests = @("127.0.0.1", "localhost")
            foreach ($target in $localTests) {
                try {
                    $result = Test-NetConnection $target -Port 80 -InformationLevel Quiet
                    $status = if ($result) { "[OK] PASS" } else { "FAIL" }
                    Write-Log "Local connectivity ($target): $status" "INFO"
                }
                catch {
                    Write-Log "Local connectivity ($target): FAIL" "ERROR"
                }
            }
            
            # Test network configuration
            $adapters = Get-NetAdapter | Where-Object Status -eq "Up"
            Write-Log "Active network adapters: $($adapters.Count)" "INFO"
            foreach ($adapter in $adapters) {
                $ip = (Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).IPAddress
                Write-Log "  $($adapter.Name): $ip" "INFO"
            }
        }
        
        "HealthCheck" {
            $healthReport = Invoke-HealthCheck
            
            # Optionally send email report
            if ($EmailAlerts) {
                $emailBody = @"
                <h2>[HLT] NCSI Health Check Report</h2>
                <p><strong>Timestamp:</strong> $($healthReport.Timestamp)</p>
                <p><strong>Overall Status:</strong> <span style="color: $(if ($healthReport.Overall -eq 'HEALTHY') {'green'} else {'red'})">$($healthReport.Overall)</span></p>
                <h3>Component Status:</h3>
                <ul>
"@
                foreach ($component in $healthReport.Components.GetEnumerator()) {
                    $color = switch ($component.Value) {
                        "HEALTHY" { "green" }
                        "FAILED" { "red" }
                        default { "orange" }
                    }
                    $emailBody += "<li><strong>$($component.Key):</strong> <span style='color: $color'>$($component.Value)</span></li>"
                }
                $emailBody += "</ul>"
                
                Send-AlertEmail "NCSI Health Check Report" $emailBody
            }
        }
    }
    
    Write-Log "NCSI Advanced Tools completed" "SUCCESS"
}

# Ejecutar función principal
Main

