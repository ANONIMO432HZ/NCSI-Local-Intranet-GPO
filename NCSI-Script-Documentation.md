# 🚀 Documentación del Script de Automatización NCSI

## 📋 Descripción General

El script `NCSI-LocalServer-Automation.ps1` es una solución completa que automatiza todo el proceso de configuración de un servidor NCSI local, desde la descarga de XAMPP hasta la configuración del registro de Windows.

## 🎯 Características Principales

### ✨ Funciones Automatizadas
- **📥 Descarga automática de XAMPP** - Obtiene la versión más reciente
- **⚙️ Instalación silenciosa** - Sin intervención del usuario
- **📄 Creación del archivo de prueba** - `connecttest.txt` con contenido correcto
- **🔧 Configuración del registro** - Parámetros NCSI automáticos
- **💾 Sistema de backup/restore** - Protección de configuraciones existentes
- **🧪 Verificación completa** - Tests de conectividad y configuración
- **📊 Monitoreo de estado** - Información detallada del sistema

### 🛡️ Características de Seguridad
- **🔒 Requiere permisos de administrador**
- **💾 Backup automático antes de cambios**
- **🔄 Capacidad de restauración completa**
- **📝 Logging detallado de todas las operaciones**

## 🔧 Requisitos del Sistema

### Requisitos Mínimos
- **Sistema Operativo**: Windows 10/11 (64-bit)
- **PowerShell**: Versión 5.0 o superior
- **Permisos**: Administrador del sistema
- **Espacio en disco**: ~150 MB para XAMPP
- **Red**: Conexión a internet para descarga inicial

### Puertos Utilizados
- **Puerto 80** - Servidor web Apache (HTTP)
- **Puerto 443** - HTTPS (opcional, si se configura SSL)

## 📖 Guía de Uso

### 🚀 Instalación Completa
```powershell
# Instalación básica (IP automática)
.\NCSI-LocalServer-Automation.ps1 -Action Install

# Instalación con IP específica
.\NCSI-LocalServer-Automation.ps1 -Action Install -ServerIP "192.168.1.100"

# Instalación forzada (sobrescribe instalación existente)
.\NCSI-LocalServer-Automation.ps1 -Action Install -Force

# Instalación silenciosa (sin output colorizado)
.\NCSI-LocalServer-Automation.ps1 -Action Install -Silent
```

### 📊 Verificación de Estado
```powershell
# Ver estado completo del sistema
.\NCSI-LocalServer-Automation.ps1 -Action Status

# Ejecutar pruebas de configuración
.\NCSI-LocalServer-Automation.ps1 -Action Test
```

### 💾 Gestión de Backups
```powershell
# Crear backup manual
.\NCSI-LocalServer-Automation.ps1 -Action Backup

# Restaurar desde backup (interactivo)
.\NCSI-LocalServer-Automation.ps1 -Action Restore
```

### 🗑️ Desinstalación
```powershell
# Desinstalar XAMPP (mantiene configuración de registro)
.\NCSI-LocalServer-Automation.ps1 -Action Uninstall

# Desinstalación completa con restauración de backup
.\NCSI-LocalServer-Automation.ps1 -Action Uninstall
.\NCSI-LocalServer-Automation.ps1 -Action Restore
```

## 📋 Parámetros Detallados

| Parámetro | Tipo | Descripción | Valor por Defecto |
|:----------|:-----|:------------|:------------------|
| `Action` | String | Acción a realizar: Install, Uninstall, Backup, Restore, Status, Test | *Obligatorio* |
| `ServerIP` | String | IP del servidor NCSI (auto-detecta si no se especifica) | IP local automática |
| `XamppPath` | String | Ruta de instalación de XAMPP | `C:\xampp` |
| `Force` | Switch | Fuerza reinstalación sobre instalación existente | `$false` |
| `Silent` | Switch | Ejecuta sin output colorizado | `$false` |

## 🔍 Archivos Generados

### 📁 Estructura de Directorios
```
C:\xampp\                           # Instalación de XAMPP
├── apache\                         # Servidor web Apache
├── htdocs\                         # Documentos web
│   └── connecttest.txt             # Archivo de prueba NCSI
├── logs\                           # Logs del servidor
└── xampp_control.exe              # Panel de control

%USERPROFILE%\Desktop\              # Backups del usuario
├── NCSI-Backup-YYYYMMDD-HHMMSS\   # Carpetas de backup
│   ├── NCSI-Registry-Backup.reg   # Backup del registro
│   └── NCSI-Config-Backup.json    # Configuración en JSON

%TEMP%\                             # Archivos temporales
└── NCSI-Setup-YYYYMMDD-HHMMSS.log # Log detallado
```

### 📝 Configuración del Registro
```
HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\NlaSvc\Parameters\Internet\
├── ActiveWebProbeHost = "http://[IP]/connecttest.txt"
├── ActiveWebProbeContent = "Microsoft Connect Test"
└── EnableActiveProbing = 1 (DWORD)
```

## 🚨 Solución de Problemas

### ❌ Problemas Comunes

#### Error: "No se puede conectar a internet"
**Causa**: Sin conexión para descargar XAMPP  
**Solución**: 
1. Verificar conexión a internet
2. Configurar proxy si es necesario
3. Descargar XAMPP manualmente y usar instalación local

#### Error: "Puerto 80 en uso"
**Causa**: Otro servicio usa el puerto 80  
**Solución**:
```powershell
# Identificar proceso usando puerto 80
netstat -ano | findstr ":80"

# Detener servicio conflictivo (ej: IIS)
Stop-Service -Name "W3SVC" -Force

# O cambiar puerto en XAMPP (manual)
```

#### Error: "Permisos insuficientes"
**Causa**: Script no ejecutado como administrador  
**Solución**:
```powershell
# Ejecutar PowerShell como administrador
# Verificar con:
[Security.Principal.WindowsIdentity]::GetCurrent().Groups -contains [Security.Principal.SecurityIdentifier]"S-1-5-32-544"
```

### 🔧 Comandos de Diagnóstico
```powershell
# Verificar estado del servicio NCSI
Get-Service -Name "NlaSvc" | Select-Object Status, StartType

# Probar conectividad local
Invoke-WebRequest -Uri "http://localhost/connecttest.txt" -UseBasicParsing

# Verificar configuración del registro
Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\NlaSvc\Parameters\Internet"

# Ver procesos de Apache
Get-Process -Name "httpd" -ErrorAction SilentlyContinue

# Reiniciar servicio Network Location Awareness
Restart-Service -Name "NlaSvc" -Force
```

## 🔄 Proceso de Actualización

### Para actualizar XAMPP:
1. **Backup actual**:
   ```powershell
   .\NCSI-LocalServer-Automation.ps1 -Action Backup
   ```

2. **Desinstalar versión actual**:
   ```powershell
   .\NCSI-LocalServer-Automation.ps1 -Action Uninstall
   ```

3. **Reinstalar con versión nueva**:
   ```powershell
   .\NCSI-LocalServer-Automation.ps1 -Action Install -Force
   ```

### Para cambiar IP del servidor:
1. **Reconfigurar con nueva IP**:
   ```powershell
   .\NCSI-LocalServer-Automation.ps1 -Action Install -ServerIP "nueva.ip.aqui" -Force
   ```

## 🎯 Mejores Prácticas

### 🔐 Seguridad
- **Siempre crear backup antes de cambios importantes**
- **Usar IP estática para el servidor en producción**
- **Configurar firewall para permitir solo tráfico interno**
- **Monitorear logs regularmente**

### ⚡ Rendimiento
- **Usar SSD para instalación de XAMPP**
- **Configurar inicio automático de servicios**
- **Implementar monitoreo de salud del servidor**

### 🏢 Entorno Empresarial
- **Usar GPO para configuración masiva de clientes**
- **Implementar servidor dedicado para NCSI**
- **Documentar cambios en Active Directory**
- **Establecer procedimientos de mantenimiento**

## 📞 Soporte y Contacto

### 🐛 Reporte de Errores
Si encuentra problemas con el script:

1. **Revisar el log detallado**: `%TEMP%\NCSI-Setup-*.log`
2. **Ejecutar diagnósticos**: `.\NCSI-LocalServer-Automation.ps1 -Action Status`
3. **Verificar requisitos del sistema**
4. **Consultar la sección de solución de problemas**

### 📚 Recursos Adicionales
- [Documentación oficial de NCSI - Microsoft Learn](https://learn.microsoft.com/en-us/windows-server/networking/ncsi/)
- [Documentación de XAMPP](https://www.apachefriends.org/docs/)
- [PowerShell Documentation](https://docs.microsoft.com/en-us/powershell/)

---

**Desarrollado por: **  
**Versión: 1.0**  
**Última actualización: $(Get-Date)**