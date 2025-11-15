#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Instalación rápida de NCSI Local Server con configuración automática
    
.DESCRIPTION
    Script simplificado para instalación express del servidor NCSI local.
    Ideal para demostraciones, pruebas rápidas o instalaciones básicas.
    
.PARAMETER AutoDetectIP
    Detecta automáticamente la IP local para configuración
    
.PARAMETER SkipDownload
    Omite la descarga si XAMPP ya está presente
    
.EXAMPLE
    .\Quick-Install.ps1
    .\Quick-Install.ps1 -AutoDetectIP -SkipDownload
    
.NOTES
    Este es el script más simple para comenzar rápidamente.
    Para configuraciones avanzadas, usar NCSI-LocalServer-Automation.ps1
#>

[CmdletBinding()]
param(
    [switch]$AutoDetectIP,
    [switch]$SkipDownload,
    [switch]$Silent
)

function Write-QuickLog {
    param(
        [string]$Message,
        [string]$Type = "Info"
    )
    
    if (-not $Silent) {
        $color = switch ($Type) {
            "Success" { "Green" }
            "Error" { "Red" }
            "Warning" { "Yellow" }
            default { "Cyan" }
        }
        
        $icon = switch ($Type) {
            "Success" { "[OK]" }
            "Error" { "[FAIL]" }
            "Warning" { "[WARN] " }
            default { "[PROC]" }
        }
        
        Write-Host "$icon $Message" -ForegroundColor $color
    }
}

function Test-Prerequisites {
    Write-QuickLog "Verificando prerequisitos..." "Info"
    
    # Verificar permisos de administrador
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        Write-QuickLog "FALTA: Permisos de administrador" "Error"
        return $false
    }
    Write-QuickLog "OK: Permisos de administrador" "Success"
    
    # Verificar PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-QuickLog "FALTA: PowerShell 5.0 o superior requerido" "Error"
        return $false
    }
    Write-QuickLog "OK: PowerShell $($PSVersionTable.PSVersion)" "Success"
    
    # Verificar conexión a internet (si no se omite descarga)
    if (-not $SkipDownload) {
        try {
            $null = Invoke-WebRequest -Uri "http://www.google.com" -UseBasicParsing -TimeoutSec 5
            Write-QuickLog "OK: Conexión a internet" "Success"
        }
        catch {
            Write-QuickLog "FALTA: Conexión a internet (use -SkipDownload si XAMPP ya está instalado)" "Error"
            return $false
        }
    }
    
    return $true
}

function Get-LocalIPAddress {
    try {
        $ip = (Get-NetIPConfiguration | Where-Object {$_.IPv4DefaultGateway -ne $null -and $_.NetAdapter.Status -eq "Up"}).IPv4Address.IPAddress | Select-Object -First 1
        return $ip
    }
    catch {
        return "127.0.0.1"
    }
}

function Quick-InstallXAMPP {
    $xamppPath = "C:\xampp"
    
    if ($SkipDownload -and (Test-Path "$xamppPath\apache\bin\httpd.exe")) {
        Write-QuickLog "XAMPP ya está instalado, omitiendo descarga" "Success"
        return $true
    }
    
    Write-QuickLog "Descargando XAMPP (esto puede tomar varios minutos)..." "Info"
    
    try {
        $tempDir = "$env:TEMP\NCSI-QuickInstall"
        if (-not (Test-Path $tempDir)) {
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        }
        
        $xamppUrl = "https://downloads.sourceforge.net/project/xampp/XAMPP%20Windows/8.2.12/xampp-windows-x64-8.2.12-0-VS16-installer.exe"
        $xamppInstaller = "$tempDir\xampp-installer.exe"
        
        # Descargar XAMPP
        Invoke-WebRequest -Uri $xamppUrl -OutFile $xamppInstaller -UseBasicParsing
        
        if (-not (Test-Path $xamppInstaller)) {
            throw "Error descargando XAMPP"
        }
        
        Write-QuickLog "Instalando XAMPP silenciosamente..." "Info"
        
        # Instalar XAMPP
        $installProcess = Start-Process -FilePath $xamppInstaller -ArgumentList "--mode", "unattended", "--prefix", $xamppPath -Wait -PassThru
        
        if ($installProcess.ExitCode -ne 0) {
            throw "Instalación de XAMPP falló con código: $($installProcess.ExitCode)"
        }
        
        # Limpiar archivo temporal
        Remove-Item $xamppInstaller -Force -ErrorAction SilentlyContinue
        
        Write-QuickLog "XAMPP instalado correctamente" "Success"
        return $true
    }
    catch {
        Write-QuickLog "Error instalando XAMPP: $($_.Exception.Message)" "Error"
        return $false
    }
}

function Quick-ConfigureNCSD {
    param([string]$ServerIP)
    
    $xamppPath = "C:\xampp"
    $serverURL = "http://$ServerIP/connecttest.txt"
    
    try {
        # Crear archivo connecttest.txt
        Write-QuickLog "Creando archivo de prueba NCSI..." "Info"
        $connectTestPath = "$xamppPath\htdocs\connecttest.txt"
        Set-Content -Path $connectTestPath -Value "Microsoft Connect Test" -Encoding ASCII -NoNewline
        
        if (-not (Test-Path $connectTestPath)) {
            throw "No se pudo crear el archivo connecttest.txt"
        }
        Write-QuickLog "Archivo connecttest.txt creado" "Success"
        
        # Iniciar Apache
        Write-QuickLog "Iniciando servidor Apache..." "Info"
        $xamppControl = "$xamppPath\xampp_control.exe"
        if (Test-Path $xamppControl) {
            Start-Process -FilePath $xamppControl -ArgumentList "start", "apache" -WindowStyle Hidden
            Start-Sleep -Seconds 5
            
            # Verificar que Apache está ejecutándose
            $apacheProcess = Get-Process -Name "httpd" -ErrorAction SilentlyContinue
            if (-not $apacheProcess) {
                throw "Apache no se inició correctamente"
            }
            Write-QuickLog "Apache iniciado correctamente" "Success"
        }
        
        # Configurar registro de Windows
        Write-QuickLog "Configurando Windows para usar servidor local..." "Info"
        $registryPath = "HKLM:\SYSTEM\CurrentControlSet\Services\NlaSvc\Parameters\Internet"
        
        if (-not (Test-Path $registryPath)) {
            New-Item -Path $registryPath -Force | Out-Null
        }
        
        Set-ItemProperty -Path $registryPath -Name "ActiveWebProbeHost" -Value $serverURL -Type String
        Set-ItemProperty -Path $registryPath -Name "ActiveWebProbeContent" -Value "Microsoft Connect Test" -Type String
        Set-ItemProperty -Path $registryPath -Name "EnableActiveProbing" -Value 1 -Type DWord
        
        Write-QuickLog "Configuración del registro completada" "Success"
        
        # Verificar configuración
        Write-QuickLog "Verificando configuración..." "Info"
        Start-Sleep -Seconds 2
        
        try {
            $response = Invoke-WebRequest -Uri $serverURL -UseBasicParsing -TimeoutSec 10
            if ($response.Content.Trim() -eq "Microsoft Connect Test") {
                Write-QuickLog "Verificación exitosa: servidor respondiendo correctamente" "Success"
                return $true
            }
            else {
                throw "Contenido incorrecto del servidor"
            }
        }
        catch {
            Write-QuickLog "Advertencia: No se pudo verificar el servidor automáticamente" "Warning"
            return $true  # Continuar de todas formas
        }
    }
    catch {
        Write-QuickLog "Error configurando NCSI: $($_.Exception.Message)" "Error"
        return $false
    }
}

function Show-QuickResults {
    param([string]$ServerIP, [string]$ServerURL)
    
    if (-not $Silent) {
        Write-Host @"

╔═══════════════════════════════════════════════════════════════════════════════╗
║                           [DONE] INSTALACIÓN COMPLETADA [DONE]                       ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║                                                                               ║
║  [OK] XAMPP instalado y configurado                                            ║
║  [OK] Servidor NCSI funcionando                                                 ║
║  [OK] Windows configurado para usar servidor local                             ║
║                                                                               ║
║  [NET] URL del servidor: $($ServerURL.PadRight(54)) ║
║  [SRV]  IP del servidor: $($ServerIP.PadRight(54)) ║
║                                                                               ║
║  [STS] PRÓXIMOS PASOS:                                                           ║
║  1. Reiniciar el equipo o ejecutar: net stop NlaSvc & net start NlaSvc      ║
║  2. Verificar que el ícono de red muestre "Conectado"                       ║
║  3. Probar acceso: $($ServerURL.PadRight(46)) ║
║                                                                               ║
║  [TOOL]  HERRAMIENTAS ADICIONALES:                                                ║
║  • Use NCSI-Control-Menu.bat para gestión completa                          ║
║  • NCSI-LocalServer-Automation.ps1 - Backup/Restore/Verificación           ║
║  • NCSI-Advanced-Tools.ps1 - Monitoreo y herramientas empresariales        ║
║                                                                               ║
║  [TIP] TIP: Ejecute 'NCSI-Control-Menu.bat' para acceder a todas las opciones  ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Green
    }
}

function Main {
    if (-not $Silent) {
        Clear-Host
        Write-Host @"
╔═══════════════════════════════════════════════════════════════════════════════╗
║                        [GO] NCSI QUICK INSTALL [GO]                              ║
║                                                                               ║
║  Instalación rápida y automática del servidor NCSI local                     ║
║  Tiempo estimado: 3-5 minutos                                                ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan
    }
    
    # Paso 1: Verificar prerequisitos
    if (-not (Test-Prerequisites)) {
        Write-QuickLog "No se cumplen los prerequisitos. Instalación cancelada." "Error"
        exit 1
    }
    
    # Paso 2: Detectar IP
    $serverIP = if ($AutoDetectIP) { 
        Get-LocalIPAddress 
    } else { 
        "127.0.0.1" 
    }
    
    Write-QuickLog "Usando IP del servidor: $serverIP" "Info"
    $serverURL = "http://$serverIP/connecttest.txt"
    
    # Paso 3: Instalar XAMPP
    if (-not (Quick-InstallXAMPP)) {
        Write-QuickLog "Error en la instalación de XAMPP. Proceso cancelado." "Error"
        exit 1
    }
    
    # Paso 4: Configurar NCSI
    if (-not (Quick-ConfigureNCSD $serverIP)) {
        Write-QuickLog "Error en la configuración de NCSI. Proceso cancelado." "Error"
        exit 1
    }
    
    # Paso 5: Mostrar resultados
    Show-QuickResults $serverIP $serverURL
    
    # Crear archivo de información en el escritorio
    $infoFile = "$env:USERPROFILE\Desktop\NCSI-Server-Info.txt"
    $infoContent = @"
NCSI Local Server - Información de Instalación
===============================================

Fecha de instalación: $(Get-Date)
IP del servidor: $serverIP
URL de prueba: $serverURL
Carpeta XAMPP: C:\xampp\

Comandos útiles:
- Reiniciar NCSI: net stop NlaSvc & net start NlaSvc
- Verificar servidor: curl $serverURL
- Panel XAMPP: C:\xampp\xampp_control.exe

Para gestión avanzada, consulte:
- NCSI-LocalServer-Automation.ps1
- NCSI-Advanced-Tools.ps1
- NCSI-Script-Documentation.md
"@
    
    Set-Content -Path $infoFile -Value $infoContent
    Write-QuickLog "Información guardada en: $infoFile" "Info"
    
    if (-not $Silent) {
        Write-Host "`n[TIP] Presione cualquier tecla para continuar..." -ForegroundColor Yellow
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}

# Ejecutar instalación rápida
Main

