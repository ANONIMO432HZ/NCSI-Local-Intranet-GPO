#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Script de automatización completa para configurar servidor NCSI local
    
.DESCRIPTION
    Este script automatiza todo el proceso de configuración de un servidor NCSI local:
    - Descarga e instalación de XAMPP
    - Configuración del archivo connecttest.txt
    - Configuración del registro de Windows
    - Backup y restauración de configuraciones
    - Verificación del estado del servicio
    
.PARAMETER Action
    Acción a realizar: Install, Uninstall, Backup, Restore, Status, Test
    
.PARAMETER ServerIP
    Dirección IP del servidor NCSI (por defecto: IP local)
    
.PARAMETER XamppPath
    Ruta de instalación de XAMPP (por defecto: C:\xampp)
    
.EXAMPLE
    .\NCSI-LocalServer-Automation.ps1 -Action Install
    .\NCSI-LocalServer-Automation.ps1 -Action Status
    .\NCSI-LocalServer-Automation.ps1 -Action Restore
    
.NOTES
    Autor: 
    Versión: 1.0
    Requiere: PowerShell 5.0+, Permisos de Administrador
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("Install", "Uninstall", "Backup", "Restore", "Status", "Test")]
    [string]$Action,
    
    [string]$ServerIP = "",
    
    [string]$XamppPath = "C:\xampp",
    
    [switch]$Force,
    
    [switch]$Silent
)

# Variables globales
$script:LogFile = "$env:TEMP\NCSI-Setup-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$script:BackupPath = "$env:USERPROFILE\Desktop\NCSI-Backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$script:RegistryPath = "HKLM:\SYSTEM\CurrentControlSet\Services\NlaSvc\Parameters\Internet"
$script:XamppDownloadUrl = "https://downloads.sourceforge.net/project/xampp/XAMPP%20Windows/8.2.12/xampp-windows-x64-8.2.12-0-VS16-installer.exe"
$script:ConnectTestContent = "Microsoft Connect Test"

# Configuración de colores para output
$ColorScheme = @{
    Success = "Green"
    Warning = "Yellow" 
    Error = "Red"
    Info = "Cyan"
    Header = "Magenta"
}

function Write-ColoredOutput {
    param(
        [string]$Message,
        [string]$Type = "Info"
    )
    
    $color = $ColorScheme[$Type]
    if (-not $Silent) {
        Write-Host $Message -ForegroundColor $color
    }
    Add-Content -Path $script:LogFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Type] $Message"
}

function Test-AdminPrivileges {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Request-UserConfirmation {
    param(
        [string]$Message,
        [string]$Title = "Confirmación",
        [switch]$DefaultYes
    )
    
    Write-ColoredOutput "[?] $Title" "Warning"
    Write-ColoredOutput "   $Message" "Info"
    Write-ColoredOutput "" "Info"
    
    do {
        if ($DefaultYes) {
            $response = Read-Host "¿Continuar? (S/n)"
            if ([string]::IsNullOrEmpty($response) -or $response -match "^[SsYy]") {
                return $true
            }
        } else {
            $response = Read-Host "¿Continuar? (s/N)"
            if ($response -match "^[SsYy]") {
                return $true
            }
        }
        
        if ($response -match "^[NnQq]") {
            return $false
        }
        
    Write-ColoredOutput "[!] Respuesta no valida. Use 'S' para Si o 'N' para No." "Warning"
    } while ($true)
}

function Get-LocalIP {
    try {
        $ip = (Get-NetIPConfiguration | Where-Object {$_.IPv4DefaultGateway -ne $null -and $_.NetAdapter.Status -eq "Up"}).IPv4Address.IPAddress | Select-Object -First 1
        return $ip
    }
    catch {
        return "127.0.0.1"
    }
}

function Show-Banner {
    if (-not $Silent) {
        Write-Host @"
╔═══════════════════════════════════════════════════════════════════════════════╗
║                        NCSI LOCAL SERVER AUTOMATION                          ║
║                                                                               ║
║  Automatización completa para servidor NCSI local con XAMPP                  ║
║  Incluye: Instalación, Configuración, Backup, Restore y Verificación        ║
║                                                                               ║
║  [TIP] Use NCSI-Control-Menu.bat para una experiencia mas amigable           ║
║                                                                               ║
║  Desarrollado por:  | Versión: 1.0                                   ║
╚═══════════════════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor $ColorScheme.Header
    }
}

function Test-InternetConnection {
    try {
        $response = Invoke-WebRequest -Uri "http://www.google.com" -UseBasicParsing -TimeoutSec 10
        return $true
    }
    catch {
        return $false
    }
}

function Download-XAMPP {
    param([string]$DownloadPath)
    
    Write-ColoredOutput "[PROC] Descargando XAMPP..." "Info"
    
    try {
        # Crear directorio temporal si no existe
        $tempDir = "$env:TEMP\NCSI-Setup"
        if (-not (Test-Path $tempDir)) {
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        }
        
        $xamppInstaller = "$tempDir\xampp-installer.exe"
        
        # Verificar conexión a internet
        if (-not (Test-InternetConnection)) {
            throw "No se puede conectar a internet para descargar XAMPP"
        }
        
        # Descargar con progreso
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($script:XamppDownloadUrl, $xamppInstaller)
        
        if (Test-Path $xamppInstaller) {
            Write-ColoredOutput "[OK] XAMPP descargado exitosamente" "Success"
            return $xamppInstaller
        }
        else {
            throw "Error al descargar XAMPP"
        }
    }
    catch {
        Write-ColoredOutput "Error descargando XAMPP: $($_.Exception.Message)" "Error"
        return $null
    }
}

function Install-XAMPP {
    param([string]$InstallerPath)
    
    Write-ColoredOutput "[PROC] Instalando XAMPP..." "Info"
    
    try {
        # Verificar si XAMPP ya está instalado
        if (Test-Path "$XamppPath\apache\bin\httpd.exe") {
            if (-not $Force) {
                Write-ColoredOutput "[WARN]  XAMPP ya está instalado. Use -Force para reinstalar" "Warning"
                return $true
            }
        }
        
        # Instalar XAMPP silenciosamente
        $installArgs = @(
            "--mode", "unattended"
            "--prefix", $XamppPath
        )
        
        $process = Start-Process -FilePath $InstallerPath -ArgumentList $installArgs -Wait -PassThru
        
        if ($process.ExitCode -eq 0) {
            Write-ColoredOutput "[OK] XAMPP instalado exitosamente" "Success"
            return $true
        }
        else {
            throw "Instalación falló con código: $($process.ExitCode)"
        }
    }
    catch {
        Write-ColoredOutput "Error instalando XAMPP: $($_.Exception.Message)" "Error"
        return $false
    }
}

function Create-ConnectTestFile {
    try {
        $htdocsPath = "$XamppPath\htdocs"
        $connectTestPath = "$htdocsPath\connecttest.txt"
        
        Write-ColoredOutput "[PROC] Creando archivo connecttest.txt..." "Info"
        
        # Verificar que la carpeta htdocs existe
        if (-not (Test-Path $htdocsPath)) {
            throw "Carpeta htdocs no encontrada en $htdocsPath"
        }
        
        # Crear archivo con contenido exacto
        Set-Content -Path $connectTestPath -Value $script:ConnectTestContent -Encoding ASCII -NoNewline
        
        if (Test-Path $connectTestPath) {
            # Verificar contenido
            $content = Get-Content $connectTestPath -Raw
            if ($content -eq $script:ConnectTestContent) {
                Write-ColoredOutput "[OK] Archivo connecttest.txt creado correctamente" "Success"
                return $true
            }
            else {
                throw "El contenido del archivo no coincide"
            }
        }
        else {
            throw "No se pudo crear el archivo"
        }
    }
    catch {
        Write-ColoredOutput "Error creando connecttest.txt: $($_.Exception.Message)" "Error"
        return $false
    }
}

function Start-XamppServices {
    try {
        Write-ColoredOutput "[PROC] Iniciando servicios de XAMPP..." "Info"
        
        $xamppControl = "$XamppPath\xampp_control.exe"
        if (-not (Test-Path $xamppControl)) {
            throw "XAMPP Control no encontrado"
        }
        
        # Iniciar Apache
        Start-Process -FilePath $xamppControl -ArgumentList "start", "apache" -Wait
        
        # Esperar un momento para que el servicio inicie
        Start-Sleep -Seconds 3
        
        # Verificar que Apache está ejecutándose
        $apacheProcess = Get-Process -Name "httpd" -ErrorAction SilentlyContinue
        if ($apacheProcess) {
            Write-ColoredOutput "[OK] Servicios de XAMPP iniciados correctamente" "Success"
            return $true
        }
        else {
            throw "Apache no se está ejecutando"
        }
    }
    catch {
        Write-ColoredOutput "Error iniciando servicios: $($_.Exception.Message)" "Error"
        return $false
    }
}

function Backup-RegistrySettings {
    try {
        Write-ColoredOutput "[PROC] Creando backup del registro..." "Info"
        
        # Crear directorio de backup
        if (-not (Test-Path $script:BackupPath)) {
            New-Item -ItemType Directory -Path $script:BackupPath -Force | Out-Null
        }
        
        # Backup del registro
        $backupFile = "$script:BackupPath\NCSI-Registry-Backup.reg"
        
        # Exportar configuración actual
        $regExportCmd = "reg export `"$($script:RegistryPath.Replace('HKLM:', 'HKEY_LOCAL_MACHINE'))`" `"$backupFile`""
        Invoke-Expression $regExportCmd
        
        # Crear archivo de configuración actual
        $currentConfig = @{
            BackupDate = Get-Date
            OriginalSettings = @{}
        }
        
        # Guardar valores actuales
        try {
            $currentConfig.OriginalSettings.ActiveWebProbeHost = Get-ItemProperty -Path $script:RegistryPath -Name "ActiveWebProbeHost" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty ActiveWebProbeHost
        } catch { $currentConfig.OriginalSettings.ActiveWebProbeHost = $null }
        
        try {
            $currentConfig.OriginalSettings.ActiveWebProbeContent = Get-ItemProperty -Path $script:RegistryPath -Name "ActiveWebProbeContent" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty ActiveWebProbeContent
        } catch { $currentConfig.OriginalSettings.ActiveWebProbeContent = $null }
        
        try {
            $currentConfig.OriginalSettings.EnableActiveProbing = Get-ItemProperty -Path $script:RegistryPath -Name "EnableActiveProbing" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty EnableActiveProbing
        } catch { $currentConfig.OriginalSettings.EnableActiveProbing = $null }
        
        # Guardar configuración en JSON
        $configFile = "$script:BackupPath\NCSI-Config-Backup.json"
        $currentConfig | ConvertTo-Json | Set-Content -Path $configFile
        
        Write-ColoredOutput "[OK] Backup creado en: $script:BackupPath" "Success"
        return $true
    }
    catch {
        Write-ColoredOutput "Error creando backup: $($_.Exception.Message)" "Error"
        return $false
    }
}

function Set-RegistrySettings {
    param([string]$ServerURL)
    
    try {
        Write-ColoredOutput "[PROC] Configurando registro de Windows..." "Info"
        
        # Verificar/crear la clave del registro
        if (-not (Test-Path $script:RegistryPath)) {
            New-Item -Path $script:RegistryPath -Force | Out-Null
        }
        
        # Configurar ActiveWebProbeHost
        Set-ItemProperty -Path $script:RegistryPath -Name "ActiveWebProbeHost" -Value $ServerURL -Type String
        
        # Configurar ActiveWebProbeContent
        Set-ItemProperty -Path $script:RegistryPath -Name "ActiveWebProbeContent" -Value $script:ConnectTestContent -Type String
        
        # Configurar EnableActiveProbing
        Set-ItemProperty -Path $script:RegistryPath -Name "EnableActiveProbing" -Value 1 -Type DWord
        
        Write-ColoredOutput "[OK] Configuración del registro completada" "Success"
        Write-ColoredOutput "   - URL del sondeo: $ServerURL" "Info"
        Write-ColoredOutput "   - Contenido esperado: $script:ConnectTestContent" "Info"
        Write-ColoredOutput "   - Sondeo activo: Habilitado" "Info"
        
        return $true
    }
    catch {
        Write-ColoredOutput "Error configurando registro: $($_.Exception.Message)" "Error"
        return $false
    }
}

function Test-NCSDConfiguration {
    param([string]$ServerURL)
    
    try {
        Write-ColoredOutput "[PROC] Verificando configuración NCSI..." "Info"
        
        # Test 1: Verificar archivo connecttest.txt accesible
        try {
            $response = Invoke-WebRequest -Uri $ServerURL -UseBasicParsing -TimeoutSec 10
            if ($response.Content.Trim() -eq $script:ConnectTestContent) {
                Write-ColoredOutput "[OK] Archivo connecttest.txt accesible y contenido correcto" "Success"
            }
            else {
                Write-ColoredOutput "Contenido incorrecto en connecttest.txt" "Error"
                return $false
            }
        }
        catch {
            Write-ColoredOutput "No se puede acceder a $ServerURL" "Error"
            return $false
        }
        
        # Test 2: Verificar configuración del registro
        try {
            $regHost = Get-ItemProperty -Path $script:RegistryPath -Name "ActiveWebProbeHost" -ErrorAction Stop | Select-Object -ExpandProperty ActiveWebProbeHost
            $regContent = Get-ItemProperty -Path $script:RegistryPath -Name "ActiveWebProbeContent" -ErrorAction Stop | Select-Object -ExpandProperty ActiveWebProbeContent
            $regProbing = Get-ItemProperty -Path $script:RegistryPath -Name "EnableActiveProbing" -ErrorAction Stop | Select-Object -ExpandProperty EnableActiveProbing
            
            if ($regHost -eq $ServerURL -and $regContent -eq $script:ConnectTestContent -and $regProbing -eq 1) {
                Write-ColoredOutput "[OK] Configuración del registro correcta" "Success"
            }
            else {
                Write-ColoredOutput "Configuración del registro incorrecta" "Error"
                return $false
            }
        }
        catch {
            Write-ColoredOutput "Error leyendo configuración del registro" "Error"
            return $false
        }
        
        # Test 3: Verificar servicios XAMPP
        $apacheProcess = Get-Process -Name "httpd" -ErrorAction SilentlyContinue
        if ($apacheProcess) {
            Write-ColoredOutput "[OK] Servicio Apache ejecutándose" "Success"
        }
        else {
            Write-ColoredOutput "[WARN]  Servicio Apache no está ejecutándose" "Warning"
        }
        
        Write-ColoredOutput "[DONE] Verificación completada exitosamente" "Success"
        return $true
    }
    catch {
        Write-ColoredOutput "Error en verificación: $($_.Exception.Message)" "Error"
        return $false
    }
}

function Restore-RegistrySettings {
    param([string]$BackupPath)
    
    try {
        Write-ColoredOutput "[PROC] Restaurando configuración del registro..." "Info"
        
        $configFile = "$BackupPath\NCSI-Config-Backup.json"
        if (-not (Test-Path $configFile)) {
            throw "Archivo de configuración de backup no encontrado"
        }
        
        $backupConfig = Get-Content $configFile | ConvertFrom-Json
        
        # Restaurar valores originales
        foreach ($setting in $backupConfig.OriginalSettings.PSObject.Properties) {
            if ($setting.Value -ne $null) {
                Set-ItemProperty -Path $script:RegistryPath -Name $setting.Name -Value $setting.Value
                Write-ColoredOutput "   Restaurado: $($setting.Name) = $($setting.Value)" "Info"
            }
            else {
                # Eliminar la entrada si no existía antes
                Remove-ItemProperty -Path $script:RegistryPath -Name $setting.Name -ErrorAction SilentlyContinue
                Write-ColoredOutput "   Eliminado: $($setting.Name)" "Info"
            }
        }
        
        Write-ColoredOutput "[OK] Configuración restaurada desde backup del $($backupConfig.BackupDate)" "Success"
        return $true
    }
    catch {
        Write-ColoredOutput "Error restaurando configuración: $($_.Exception.Message)" "Error"
        return $false
    }
}

function Remove-XAMPP {
    try {
        Write-ColoredOutput "[PROC] Desinstalando XAMPP..." "Info"
        
        # Detener servicios primero
        try {
            $xamppControl = "$XamppPath\xampp_control.exe"
            if (Test-Path $xamppControl) {
                Start-Process -FilePath $xamppControl -ArgumentList "stop", "apache" -Wait
            }
        }
        catch {
            Write-ColoredOutput "[WARN]  No se pudieron detener los servicios automáticamente" "Warning"
        }
        
        # Eliminar procesos
        Get-Process -Name "httpd" -ErrorAction SilentlyContinue | Stop-Process -Force
        Get-Process -Name "xampp_control" -ErrorAction SilentlyContinue | Stop-Process -Force
        
        # Eliminar directorio
        if (Test-Path $XamppPath) {
            Remove-Item -Path $XamppPath -Recurse -Force
            Write-ColoredOutput "[OK] XAMPP desinstalado correctamente" "Success"
        }
        else {
            Write-ColoredOutput "[WARN]  XAMPP no estaba instalado" "Warning"
        }
        
        return $true
    }
    catch {
        Write-ColoredOutput "Error desinstalando XAMPP: $($_.Exception.Message)" "Error"
        return $false
    }
}

function Show-Status {
    Write-ColoredOutput "[MON] Estado actual del sistema NCSI Local:" "Header"
    Write-ColoredOutput "===========================================" "Info"
    
    # Estado de XAMPP
    if (Test-Path "$XamppPath\apache\bin\httpd.exe") {
        Write-ColoredOutput "📦 XAMPP: Instalado en $XamppPath" "Success"
        
        # Estado del servicio Apache
        $apacheProcess = Get-Process -Name "httpd" -ErrorAction SilentlyContinue
        if ($apacheProcess) {
            Write-ColoredOutput "[GO] Apache: Ejecutándose (PID: $($apacheProcess.Id -join ', '))" "Success"
        }
        else {
            Write-ColoredOutput "⛔ Apache: Detenido" "Warning"
        }
    }
    else {
        Write-ColoredOutput "📦 XAMPP: No instalado" "Error"
    }
    
    # Estado del archivo connecttest.txt
    $connectTestPath = "$XamppPath\htdocs\connecttest.txt"
    if (Test-Path $connectTestPath) {
        $content = Get-Content $connectTestPath -Raw
        if ($content -eq $script:ConnectTestContent) {
            Write-ColoredOutput "📄 connecttest.txt: Correcto" "Success"
        }
        else {
            Write-ColoredOutput "📄 connecttest.txt: Contenido incorrecto" "Error"
        }
    }
    else {
        Write-ColoredOutput "📄 connecttest.txt: No encontrado" "Error"
    }
    
    # Estado del registro
    try {
        $regHost = Get-ItemProperty -Path $script:RegistryPath -Name "ActiveWebProbeHost" -ErrorAction Stop | Select-Object -ExpandProperty ActiveWebProbeHost
        $regContent = Get-ItemProperty -Path $script:RegistryPath -Name "ActiveWebProbeContent" -ErrorAction Stop | Select-Object -ExpandProperty ActiveWebProbeContent
        $regProbing = Get-ItemProperty -Path $script:RegistryPath -Name "EnableActiveProbing" -ErrorAction Stop | Select-Object -ExpandProperty EnableActiveProbing
        
        Write-ColoredOutput "[ADV] Registro de Windows:" "Info"
        Write-ColoredOutput "   - URL del sondeo: $regHost" "Info"
        Write-ColoredOutput "   - Contenido esperado: $regContent" "Info"
        Write-ColoredOutput "   - Sondeo activo: $(if($regProbing -eq 1){'Habilitado'}else{'Deshabilitado'})" "Info"
    }
    catch {
        Write-ColoredOutput "[ADV] Registro: No configurado" "Warning"
    }
    
    # IP local actual
    $localIP = Get-LocalIP
    Write-ColoredOutput "[NET] IP Local: $localIP" "Info"
    
    # Backups disponibles
    $backupFolders = Get-ChildItem -Path "$env:USERPROFILE\Desktop" -Filter "NCSI-Backup-*" -Directory | Sort-Object Name -Descending
    if ($backupFolders) {
        Write-ColoredOutput "[BAK] Backups disponibles:" "Info"
        $backupFolders | ForEach-Object {
            Write-ColoredOutput "   - $($_.Name)" "Info"
        }
    }
    else {
        Write-ColoredOutput "[BAK] Backups: Ninguno encontrado" "Warning"
    }
}

# Función principal
function Main {
    Show-Banner
    
    # Verificar permisos de administrador
    if (-not (Test-AdminPrivileges)) {
        Write-ColoredOutput "Este script requiere permisos de administrador" "Error"
        Write-ColoredOutput "   Ejecute PowerShell como administrador e intente nuevamente" "Info"
        exit 1
    }
    
    # Determinar IP del servidor si no se especifica
    if ([string]::IsNullOrEmpty($ServerIP)) {
        $ServerIP = Get-LocalIP
    }
    
    $ServerURL = "http://$ServerIP/connecttest.txt"
    
    Write-ColoredOutput "[LOG] Log file: $script:LogFile" "Info"
    Write-ColoredOutput "[SRV]  Servidor: $ServerURL" "Info"
    Write-ColoredOutput "" "Info"
    
    switch ($Action) {
        "Install" {
            Write-ColoredOutput "[GO] Iniciando instalación completa de NCSI Local..." "Header"
            
            # Solicitar confirmación para instalación
            if (-not (Request-UserConfirmation -Message "Esta operación descargará e instalará XAMPP (~150MB) y configurará el registro de Windows para NCSI local. ¿Desea continuar?" -Title "Confirmación de Instalación" -DefaultYes)) {
                Write-ColoredOutput "Instalación cancelada por el usuario" "Warning"
                exit 0
            }
            
            # Paso 1: Backup
            Write-ColoredOutput "[STS] PASO 1: Creando backup..." "Info"
            if (-not (Backup-RegistrySettings)) {
                if (-not (Request-UserConfirmation -Message "No se pudo crear el backup automáticamente. ¿Desea continuar sin backup? ADVERTENCIA: Sin backup, no podrá restaurar la configuración original automáticamente." -Title "Error de Backup")) {
                    Write-ColoredOutput "Instalación cancelada - No se pudo crear backup" "Error"
                    exit 1
                }
            }
            
            # Paso 2: Descargar XAMPP
            Write-ColoredOutput "[STS] PASO 2: Descargando XAMPP..." "Info"
            $xamppInstaller = Download-XAMPP
            if (-not $xamppInstaller) {
                Write-ColoredOutput "No se pudo descargar XAMPP" "Error"
                exit 1
            }
            
            # Paso 3: Instalar XAMPP
            Write-ColoredOutput "[STS] PASO 3: Instalando XAMPP..." "Info"
            if (-not (Install-XAMPP $xamppInstaller)) {
                Write-ColoredOutput "Error instalando XAMPP" "Error"
                exit 1
            }
            
            # Paso 4: Crear archivo connecttest.txt
            Write-ColoredOutput "[STS] PASO 4: Creando archivo de prueba..." "Info"
            if (-not (Create-ConnectTestFile)) {
                Write-ColoredOutput "Error creando archivo de prueba" "Error"
                exit 1
            }
            
            # Paso 5: Iniciar servicios
            Write-ColoredOutput "[STS] PASO 5: Iniciando servicios..." "Info"
            if (-not (Start-XamppServices)) {
                Write-ColoredOutput "Error iniciando servicios" "Error"
                exit 1
            }
            
            # Paso 6: Configurar registro
            Write-ColoredOutput "[STS] PASO 6: Configurando Windows..." "Info"
            if (-not (Set-RegistrySettings $ServerURL)) {
                Write-ColoredOutput "Error configurando registro" "Error"
                exit 1
            }
            
            # Paso 7: Verificar configuración
            Write-ColoredOutput "[STS] PASO 7: Verificando configuración..." "Info"
            if (Test-NCSDConfiguration $ServerURL) {
                Write-ColoredOutput "[DONE] ¡Instalación completada exitosamente!" "Success"
                Write-ColoredOutput "   URL del servidor: $ServerURL" "Info"
                Write-ColoredOutput "   Backup guardado en: $script:BackupPath" "Info"
                Write-ColoredOutput "" "Info"
                Write-ColoredOutput "[TIP] Reinicie el servicio de Network Location Awareness o reinicie el equipo para aplicar cambios" "Warning"
            }
            
            # Limpiar archivo temporal
            if (Test-Path $xamppInstaller) {
                Remove-Item $xamppInstaller -Force
            }
        }
        
        "Uninstall" {
            Write-ColoredOutput "[DEL]  Iniciando desinstalación de NCSI Local..." "Header"
            
            # Solicitar confirmación para desinstalación
            if (-not (Request-UserConfirmation -Message "Esta operación eliminará XAMPP completamente del sistema. La configuración del registro no se eliminará automáticamente. ¿Está seguro de que desea continuar?" -Title "Confirmación de Desinstalación")) {
                Write-ColoredOutput "Desinstalación cancelada por el usuario" "Warning"
                exit 0
            }
            
            # Crear backup antes de desinstalar
            Write-ColoredOutput "[STS] Creando backup antes de desinstalar..." "Info"
            Backup-RegistrySettings
            
            # Eliminar XAMPP
            Write-ColoredOutput "[STS] Eliminando XAMPP..." "Info"
            Remove-XAMPP
            
            # Nota sobre registro
            Write-ColoredOutput "[WARN]  La configuración del registro no se ha eliminado automáticamente" "Warning"
            Write-ColoredOutput "   Use la acción 'Restore' con un backup previo para restaurar la configuración original" "Info"
            Write-ColoredOutput "   O ejecute desde el menú principal: NCSI-Control-Menu.bat > Opción 4" "Info"
            
            Write-ColoredOutput "[OK] Desinstalación completada" "Success"
        }
        
        "Backup" {
            Write-ColoredOutput "[BAK] Creando backup de la configuración actual..." "Header"
            if (Backup-RegistrySettings) {
                Write-ColoredOutput "[OK] Backup creado exitosamente en: $script:BackupPath" "Success"
            }
        }
        
        "Restore" {
            Write-ColoredOutput "[PROC] Restaurando configuración desde backup..." "Header"
            
            # Mostrar backups disponibles
            $backupFolders = Get-ChildItem -Path "$env:USERPROFILE\Desktop" -Filter "NCSI-Backup-*" -Directory | Sort-Object Name -Descending
            
            if (-not $backupFolders) {
                Write-ColoredOutput "No se encontraron backups disponibles" "Error"
                exit 1
            }
            
            Write-ColoredOutput "[DIR] Backups disponibles:" "Info"
            for ($i = 0; $i -lt $backupFolders.Count; $i++) {
                Write-ColoredOutput "   [$i] $($backupFolders[$i].Name)" "Info"
            }
            
            Write-ColoredOutput "" "Info"
            $selection = Read-Host "Seleccione el backup a restaurar (0-$($backupFolders.Count-1))"
            
            try {
                $selectedBackup = $backupFolders[[int]$selection]
                if (Restore-RegistrySettings $selectedBackup.FullName) {
                    Write-ColoredOutput "[OK] Configuración restaurada exitosamente" "Success"
                    Write-ColoredOutput "[TIP] Reinicie el servicio de Network Location Awareness para aplicar cambios" "Warning"
                }
            }
            catch {
                Write-ColoredOutput "Selección inválida o error restaurando backup" "Error"
            }
        }
        
        "Status" {
            Show-Status
        }
        
        "Test" {
            Write-ColoredOutput "[TEST] Ejecutando pruebas de configuración..." "Header"
            Test-NCSDConfiguration $ServerURL
        }
    }
    
    Write-ColoredOutput "" "Info"
    Write-ColoredOutput "[LOG] Log detallado guardado en: $script:LogFile" "Info"
}

# Ejecutar función principal
Main

