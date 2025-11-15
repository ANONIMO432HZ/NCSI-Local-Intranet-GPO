@echo off
chcp 65001 > nul
:: =====================================================================================
:: NCSI Local Server - Control Menu Principal
:: Orquestador de la Suite de Automatización NCSI
:: 
:: Autor: Anonimo
:: Versión: 1.0
:: Descripción: Script principal que maneja toda la suite con elevación automática
:: =====================================================================================

setlocal enabledelayedexpansion

:: Configuración de variables globales
set "SCRIPT_NAME=NCSI Control Menu"
set "SCRIPT_VERSION=1.0"
set "SCRIPT_DIR=%~dp0"
set "LOG_DIR=%TEMP%"
set "LOG_FILE=%LOG_DIR%\NCSI-Control-Menu-%date:~-4,4%%date:~-7,2%%date:~-10,2%.log"

:: Configuración de colores
for /f %%A in ('"prompt $H &echo on &for %%B in (1) do rem"') do set BS=%%A

:: =====================================================================================
:: VERIFICACIÓN DE PRIVILEGIOS DE ADMINISTRADOR Y AUTO-ELEVACIÓN
:: =====================================================================================

:CHECK_PRIVILEGES
net session >nul 2>&1
if %errorLevel% == 0 (
    goto :ADMIN_CONFIRMED
) else (
    call :LOG "INFO" "Elevando privilegios de administrador..."
    goto :ELEVATE_PRIVILEGES
)

:ELEVATE_PRIVILEGES
echo.
echo ╔═══════════════════════════════════════════════════════════════════════════════╗
echo ║                        🔐 ELEVACIÓN DE PRIVILEGIOS 🔐                        ║
echo ║                                                                               ║
echo ║  Este script requiere permisos de administrador para funcionar correctamente  ║
echo ║  Se abrirá una nueva ventana con privilegios elevados...                      ║
echo ║                                                                               ║
echo ║  Si aparece UAC (Control de Cuentas de Usuario), haga clic en "Sí"            ║
echo ╚═══════════════════════════════════════════════════════════════════════════════╝
echo.
pause

:: Crear script temporal para elevación
set "TEMP_ELEVATION_SCRIPT=%TEMP%\elevate_ncsi.bat"
echo @echo off > "%TEMP_ELEVATION_SCRIPT%"
echo cd /d "%SCRIPT_DIR%" >> "%TEMP_ELEVATION_SCRIPT%"
echo "%~0" ELEVATED >> "%TEMP_ELEVATION_SCRIPT%"
echo del "%TEMP_ELEVATION_SCRIPT%" >> "%TEMP_ELEVATION_SCRIPT%"

:: Ejecutar con privilegios de administrador
powershell -Command "Start-Process cmd -ArgumentList '/c \"%TEMP_ELEVATION_SCRIPT%\"' -Verb RunAs"
exit /b

:ADMIN_CONFIRMED
if "%1"=="ELEVATED" (
    call :LOG "SUCCESS" "Privilegios de administrador confirmados"
) else (
    call :LOG "SUCCESS" "Ejecutándose con privilegios de administrador"
)

:: =====================================================================================
:: INICIALIZACIÓN Y VERIFICACIÓN DEL ENTORNO
:: =====================================================================================

:INIT
call :LOG "INFO" "Iniciando %SCRIPT_NAME% v%SCRIPT_VERSION%"
call :LOG "INFO" "Directorio de scripts: %SCRIPT_DIR%"
call :LOG "INFO" "Archivo de log: %LOG_FILE%"

:: Verificar que los scripts de PowerShell existan
call :VERIFY_SCRIPTS
if !ERRORLEVEL! neq 0 (
    call :LOG "ERROR" "Scripts requeridos no encontrados"
    goto :ERROR_EXIT
)

:: Configurar título de la ventana
title %SCRIPT_NAME% v%SCRIPT_VERSION% - Administrador

:: =====================================================================================
:: MENÚ PRINCIPAL
:: =====================================================================================

:MAIN_MENU
cls
call :SHOW_HEADER
call :SHOW_MENU_OPTIONS
call :SHOW_FOOTER

echo.
set /p "choice=Seleccione una opción (1-13): "

:: Validar entrada
if "%choice%"=="" goto :INVALID_CHOICE
for /l %%i in (1,1,13) do if "%choice%"=="%%i" goto :PROCESS_CHOICE
goto :INVALID_CHOICE

:INVALID_CHOICE
call :LOG "WARNING" "Opción inválida seleccionada: %choice%"
echo.
call :COLORECHO 04 "Opción inválida. Por favor seleccione un número del 1 al 13."
echo.
pause
goto :MAIN_MENU

:PROCESS_CHOICE
call :LOG "INFO" "Usuario seleccionó opción %choice%"

if "%choice%"=="1" goto :QUICK_INSTALL
if "%choice%"=="2" goto :FULL_INSTALL
if "%choice%"=="3" goto :CREATE_BACKUP
if "%choice%"=="4" goto :RESTORE_BACKUP
if "%choice%"=="5" goto :VERIFY_CONFIG
if "%choice%"=="6" goto :UNINSTALL_NCSI
if "%choice%"=="7" goto :MONITOR_SERVER
if "%choice%"=="8" goto :CONFIGURE_GPO
if "%choice%"=="9" goto :RUN_DIAGNOSTICS
if "%choice%"=="10" goto :SETUP_SSL
if "%choice%"=="11" goto :HEALTH_CHECK
if "%choice%"=="12" goto :SHOW_STATUS
if "%choice%"=="13" goto :EXIT_PROGRAM

:: =====================================================================================
:: IMPLEMENTACIÓN DE OPCIONES DEL MENÚ
:: =====================================================================================

:QUICK_INSTALL
call :SHOW_ACTION_HEADER "INSTALACIÓN EXPRESS"
echo Esta opción instalará XAMPP y configurará NCSI automáticamente en ~5 minutos.
echo.
call :CONFIRM_ACTION "¿Desea continuar con la instalación express?"
if !ERRORLEVEL! neq 0 goto :MAIN_MENU

call :LOG "INFO" "Ejecutando instalación express..."
powershell -ExecutionPolicy Bypass -NoProfile -File "%SCRIPT_DIR%Quick-Install.ps1"
call :SHOW_RESULT !ERRORLEVEL! "Instalación Express"
pause
goto :MAIN_MENU

:FULL_INSTALL
call :SHOW_ACTION_HEADER "INSTALACIÓN COMPLETA"
echo Esta opción realizará una instalación completa con backup automático.
echo Incluye descarga de XAMPP, configuración completa y verificación.
echo.
call :CONFIRM_ACTION "¿Desea continuar con la instalación completa?"
if !ERRORLEVEL! neq 0 goto :MAIN_MENU

call :LOG "INFO" "Ejecutando instalación completa..."
powershell -ExecutionPolicy Bypass -NoProfile -File "%SCRIPT_DIR%NCSI-LocalServer-Automation.ps1" -Action Install
call :SHOW_RESULT !ERRORLEVEL! "Instalación Completa"
pause
goto :MAIN_MENU

:CREATE_BACKUP
call :SHOW_ACTION_HEADER "CREAR BACKUP"
echo Esta opción creará un backup de la configuración actual del registro.
echo El backup se guardará en el escritorio para restauración futura.
echo.
call :CONFIRM_ACTION "¿Desea crear un backup de la configuración actual?"
if !ERRORLEVEL! neq 0 goto :MAIN_MENU

call :LOG "INFO" "Creando backup de configuración..."
powershell -ExecutionPolicy Bypass -NoProfile -File "%SCRIPT_DIR%NCSI-LocalServer-Automation.ps1" -Action Backup
call :SHOW_RESULT !ERRORLEVEL! "Creación de Backup"
pause
goto :MAIN_MENU

:RESTORE_BACKUP
call :SHOW_ACTION_HEADER "RESTAURAR BACKUP"
echo Esta opción restaurará la configuración desde un backup previo.
echo Se mostrarán los backups disponibles para selección.
echo.
call :CONFIRM_ACTION "¿Desea restaurar desde un backup anterior?"
if !ERRORLEVEL! neq 0 goto :MAIN_MENU

call :LOG "INFO" "Restaurando desde backup..."
powershell -ExecutionPolicy Bypass -NoProfile -File "%SCRIPT_DIR%NCSI-LocalServer-Automation.ps1" -Action Restore
call :SHOW_RESULT !ERRORLEVEL! "Restauración de Backup"
pause
goto :MAIN_MENU

:VERIFY_CONFIG
call :SHOW_ACTION_HEADER "VERIFICAR CONFIGURACIÓN"
echo Esta opción ejecutará pruebas completas de la configuración NCSI.
echo Verificará servidor web, registro de Windows y conectividad.
echo.
call :CONFIRM_ACTION "¿Desea ejecutar la verificación de configuración?"
if !ERRORLEVEL! neq 0 goto :MAIN_MENU

call :LOG "INFO" "Ejecutando verificación de configuración..."
powershell -ExecutionPolicy Bypass -NoProfile -File "%SCRIPT_DIR%NCSI-LocalServer-Automation.ps1" -Action Test
call :SHOW_RESULT !ERRORLEVEL! "Verificación de Configuración"
pause
goto :MAIN_MENU

:UNINSTALL_NCSI
call :SHOW_ACTION_HEADER "DESINSTALAR NCSI"
echo   ADVERTENCIA: Esta opción desinstalará XAMPP completamente.
echo Se creará un backup automático antes de la desinstalación.
echo La configuración del registro no se eliminará automáticamente.
echo.
call :COLORECHO 06 "  Esta acción no es reversible automáticamente."
echo.
call :CONFIRM_ACTION "¿Está seguro de que desea desinstalar XAMPP?"
if !ERRORLEVEL! neq 0 goto :MAIN_MENU

call :LOG "INFO" "Ejecutando desinstalación..."
powershell -ExecutionPolicy Bypass -NoProfile -File "%SCRIPT_DIR%NCSI-LocalServer-Automation.ps1" -Action Uninstall
call :SHOW_RESULT !ERRORLEVEL! "Desinstalación"
pause
goto :MAIN_MENU

:MONITOR_SERVER
call :SHOW_ACTION_HEADER "MONITOREO CONTINUO"
echo Esta opción iniciará el monitoreo continuo del servidor NCSI.
echo El monitoreo continuará hasta que presione Ctrl+C para detenerlo.
echo Se verificará el estado cada 60 segundos por defecto.
echo.
call :CONFIRM_ACTION "¿Desea iniciar el monitoreo continuo del servidor?"
if !ERRORLEVEL! neq 0 goto :MAIN_MENU

call :LOG "INFO" "Iniciando monitoreo continuo..."
echo.
call :COLORECHO 0E "  Presione Ctrl+C para detener el monitoreo"
echo.
powershell -ExecutionPolicy Bypass -NoProfile -File "%SCRIPT_DIR%NCSI-Advanced-Tools.ps1" -Action Monitor
echo.
echo Monitoreo finalizado.
pause
goto :MAIN_MENU

:CONFIGURE_GPO
call :SHOW_ACTION_HEADER "CONFIGURACIÓN DE GPO"
echo Esta opción configurará automáticamente las Group Policy Objects (GPO).
echo Requiere permisos de Domain Admin y herramientas RSAT instaladas.
echo Se aplicará la configuración NCSI a través de Active Directory.
echo.
call :CONFIRM_ACTION "¿Desea configurar GPO automáticamente?"
if !ERRORLEVEL! neq 0 goto :MAIN_MENU

echo.
set /p "dc_server=Ingrese el nombre del Domain Controller (dejar vacío para autodetectar): "
if "!dc_server!"=="" (
    call :LOG "INFO" "Configurando GPO con autodetección de DC..."
    powershell -ExecutionPolicy Bypass -NoProfile -File "%SCRIPT_DIR%NCSI-Advanced-Tools.ps1" -Action GPOConfig
) else (
    call :LOG "INFO" "Configurando GPO con DC especificado: !dc_server!"
    powershell -ExecutionPolicy Bypass -NoProfile -File "%SCRIPT_DIR%NCSI-Advanced-Tools.ps1" -Action GPOConfig -DomainController "!dc_server!"
)
call :SHOW_RESULT !ERRORLEVEL! "Configuración de GPO"
pause
goto :MAIN_MENU

:RUN_DIAGNOSTICS
call :SHOW_ACTION_HEADER "DIAGNÓSTICOS AVANZADOS"
echo Esta opción ejecutará diagnósticos completos del sistema NCSI.
echo Incluye verificación de red, servicios, firewall y configuraciones.
echo Los resultados se mostrarán en pantalla y se guardarán en logs.
echo.
call :CONFIRM_ACTION "¿Desea ejecutar diagnósticos avanzados?"
if !ERRORLEVEL! neq 0 goto :MAIN_MENU

call :LOG "INFO" "Ejecutando diagnósticos avanzados..."
powershell -ExecutionPolicy Bypass -NoProfile -File "%SCRIPT_DIR%NCSI-Advanced-Tools.ps1" -Action Diagnostics
call :SHOW_RESULT !ERRORLEVEL! "Diagnósticos Avanzados"
pause
goto :MAIN_MENU

:SETUP_SSL
call :SHOW_ACTION_HEADER "CONFIGURACIÓN SSL"
echo Esta opción configurará SSL/HTTPS para el servidor XAMPP.
echo Se habilitarán los módulos SSL necesarios en Apache.
echo Para certificados personalizados, especifique la ruta cuando se solicite.
echo.
call :CONFIRM_ACTION "¿Desea configurar SSL para HTTPS?"
if !ERRORLEVEL! neq 0 goto :MAIN_MENU

echo.
set /p "cert_path=Ruta del certificado SSL (dejar vacío para configuración básica): "
if "!cert_path!"=="" (
    call :LOG "INFO" "Configurando SSL básico..."
    powershell -ExecutionPolicy Bypass -NoProfile -File "%SCRIPT_DIR%NCSI-Advanced-Tools.ps1" -Action SSLSetup
) else (
    call :LOG "INFO" "Configurando SSL con certificado: !cert_path!"
    powershell -ExecutionPolicy Bypass -NoProfile -File "%SCRIPT_DIR%NCSI-Advanced-Tools.ps1" -Action SSLSetup -SSLCertPath "!cert_path!"
)
call :SHOW_RESULT !ERRORLEVEL! "Configuración SSL"
pause
goto :MAIN_MENU

:HEALTH_CHECK
call :SHOW_ACTION_HEADER "VERIFICACIÓN DE SALUD"
echo Esta opción ejecutará una verificación completa de salud del sistema.
echo Verificará todos los componentes: NCSI, Apache, servicios y conectividad.
echo Se generará un reporte detallado del estado actual.
echo.
call :CONFIRM_ACTION "¿Desea ejecutar la verificación de salud?"
if !ERRORLEVEL! neq 0 goto :MAIN_MENU

call :LOG "INFO" "Ejecutando verificación de salud..."
powershell -ExecutionPolicy Bypass -NoProfile -File "%SCRIPT_DIR%NCSI-Advanced-Tools.ps1" -Action HealthCheck
call :SHOW_RESULT !ERRORLEVEL! "Verificación de Salud"
pause
goto :MAIN_MENU

:SHOW_STATUS
call :SHOW_ACTION_HEADER "ESTADO DEL SISTEMA"
echo Mostrando estado actual de todos los componentes NCSI...
echo.
call :LOG "INFO" "Mostrando estado del sistema..."
powershell -ExecutionPolicy Bypass -NoProfile -File "%SCRIPT_DIR%NCSI-LocalServer-Automation.ps1" -Action Status
echo.
pause
goto :MAIN_MENU

:EXIT_PROGRAM
call :LOG "INFO" "Saliendo del programa por solicitud del usuario"
echo.
call :COLORECHO 0A "Gracias por usar NCSI Control Menu"
echo.
echo Log de sesión guardado en: %LOG_FILE%
echo.
pause
exit /b 0

:: =====================================================================================
:: FUNCIONES AUXILIARES
:: =====================================================================================

:VERIFY_SCRIPTS
call :LOG "INFO" "Verificando scripts requeridos..."

if not exist "%SCRIPT_DIR%Quick-Install.ps1" (
    call :COLORECHO 04 "No se encontró: Quick-Install.ps1"
    exit /b 1
)

if not exist "%SCRIPT_DIR%NCSI-LocalServer-Automation.ps1" (
    call :COLORECHO 04 "No se encontró: NCSI-LocalServer-Automation.ps1"
    exit /b 1
)

if not exist "%SCRIPT_DIR%NCSI-Advanced-Tools.ps1" (
    call :COLORECHO 04 "No se encontró: NCSI-Advanced-Tools.ps1"
    exit /b 1
)

call :LOG "SUCCESS" "Todos los scripts requeridos están presentes"
exit /b 0

:SHOW_HEADER
echo.
echo ╔═══════════════════════════════════════════════════════════════════════════════╗
echo ║                        NCSI CONTROL MENU v%SCRIPT_VERSION%                    ║
echo ║                                                                               ║
echo ║               Suite de Automatización para Servidor NCSI Local                ║
echo ║                        Ejecutándose como Administrador                        ║
echo ╚═══════════════════════════════════════════════════════════════════════════════╝
goto :eof

:SHOW_MENU_OPTIONS
echo.
echo  ┌─────────────────────────────────────────────────────────────────────────────┐
echo  │                              INSTALACION Y SETUP                            │
echo  ├─────────────────────────────────────────────────────────────────────────────┤
echo  │  [1]  [OK] Instalacion Express        │ [2]  [CFG] Instalacion Completa     │
echo  │       (5 min - Automática)            │       (Backup + Verificación)       │
echo  │                                       │                                     │
echo  │  [3]  [BAK] Crear Backup              │ [4]  [RST] Restaurar Backup         │
echo  │       (Configuración actual)          │       (Desde backup previo)         │
echo  │                                       │                                     │
echo  │  [5]  [TST] Verificar Configuracion   │ [6]  [DEL] Desinstalar NCSI         │
echo  │       (Test completo)                 │       (Remover XAMPP)               │
echo  └─────────────────────────────────────────────────────────────────────────────┘
echo.
echo  ┌─────────────────────────────────────────────────────────────────────────────┐
echo  │                           HERRAMIENTAS AVANZADAS                            │
echo  ├─────────────────────────────────────────────────────────────────────────────┤
echo  │  [7]  [MON] Monitoreo Continuo        │ [8]  [GPO] Configuracion GPO        │
echo  │       (Vigilancia en tiempo real)     │       (Active Directory)            │
echo  │                                       │                                     │
echo  │  [9]  [DGN] Diagnosticos Avanzados    │ [10] [SSL] Configuracion SSL        │
echo  │       (Análisis completo)             │       (HTTPS Support)               │
echo  │                                       │                                     │
echo  │  [11] [HLT] Verificacion de Salud     │  [12] [STS] Estado del Sistema      │
echo  │       (Health Check)                  │       (Status Report)               │
echo  └─────────────────────────────────────────────────────────────────────────────┘
echo.
echo  ┌─────────────────────────────────────────────────────────────────────────────┐
echo  │  [13] Salir del Programa                                                    │
echo  └─────────────────────────────────────────────────────────────────────────────┘
goto :eof

:SHOW_FOOTER
echo.
echo  [TIP] Recomendacion: Comience con la opcion [1] para instalacion rapida
echo  [LOG] Todos los logs se guardan en: %LOG_FILE%
echo  [ADV] Para configuraciones empresariales, use las opciones 7-11
goto :eof

:SHOW_ACTION_HEADER
echo.
echo ╔═══════════════════════════════════════════════════════════════════════════════╗
echo ║  %~1
echo ╚═══════════════════════════════════════════════════════════════════════════════╝
echo.
goto :eof

:CONFIRM_ACTION
set /p "confirm=¿%~1 (S/N): "
if /i "%confirm%"=="S" exit /b 0
if /i "%confirm%"=="Y" exit /b 0
if /i "%confirm%"=="SI" exit /b 0
if /i "%confirm%"=="YES" exit /b 0
call :LOG "INFO" "Usuario canceló la acción: %~1"
echo.
call :COLORECHO 0E "Operación cancelada por el usuario."
echo.
exit /b 1

:SHOW_RESULT
if %1 equ 0 (
    call :LOG "SUCCESS" "%~2 completado exitosamente"
    echo.
    call :COLORECHO 0A "[OK] %~2 completado exitosamente"
    echo.
) else (
    call :LOG "ERROR" "%~2 falló con código de error %1"
    echo.
    call :COLORECHO 04 "%~2 falló. Revise los logs para más detalles."
    echo.
    call :COLORECHO 06 "Log file: %LOG_FILE%"
    echo.
)
goto :eof

:COLORECHO
set "color=%~1"
set "text=%~2"
for /f "delims=" %%a in ('echo prompt $E^| cmd') do set "ESC=%%a"
echo %ESC%[%color%m%text%%ESC%[0m
goto :eof

:LOG
set "level=%~1"
set "message=%~2"
set "timestamp=%date% %time%"
echo [%timestamp%] [%level%] %message% >> "%LOG_FILE%"
goto :eof

:ERROR_EXIT
echo.
call :COLORECHO 04 "Error crítico detectado. No se puede continuar."
echo.
echo Revise el archivo de log: %LOG_FILE%
echo.
pause
exit /b 1

:: =====================================================================================
:: FIN DEL SCRIPT
:: =====================================================================================