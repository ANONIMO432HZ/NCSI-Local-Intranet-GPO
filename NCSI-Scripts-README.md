# 🚀 NCSI Local Server - Suite de Scripts de Automatización

## 📋 Descripción General

Esta suite de scripts de PowerShell automatiza completamente la implementación y gestión de un servidor NCSI (Network Connectivity Status Indicator) local. Incluye desde instalación básica hasta herramientas avanzadas de monitoreo y gestión empresarial.

## 📦 Contenido de la Suite

### 🎯 Scripts Principales

| Script | Propósito | Nivel | Descripción |
|:-------|:----------|:------|:------------|
| **`Quick-Install.ps1`** | 🚀 Instalación Express | Básico | Instalación automática en 5 minutos |
| **`NCSI-LocalServer-Automation.ps1`** | ⚙️ Gestión Completa | Intermedio | Automatización completa con backup/restore |
| **`NCSI-Advanced-Tools.ps1`** | 🛠️ Herramientas Avanzadas | Avanzado | Monitoreo, GPO, diagnósticos, SSL |

### 📚 Documentación

| Archivo | Contenido |
|:--------|:----------|
| **`NCSI-Script-Documentation.md`** | Documentación detallada de uso y configuración |
| **`NCSI-Scripts-README.md`** | Este archivo - Guía general de la suite |

## 🚦 Guía de Inicio Rápido

### 🟢 Para Usuarios Básicos (Instalación Rápida)

```powershell
# 1. Descargar todos los scripts
# 2. Abrir PowerShell como Administrador
# 3. Ejecutar instalación express
.\Quick-Install.ps1

# ¡Listo! En 5 minutos tendrás tu servidor NCSI funcionando
```

### 🟡 Para Usuarios Intermedios (Control Completo)

```powershell
# Instalación completa con todas las características
.\NCSI-LocalServer-Automation.ps1 -Action Install

# Ver estado del sistema
.\NCSI-LocalServer-Automation.ps1 -Action Status

# Crear backup antes de cambios
.\NCSI-LocalServer-Automation.ps1 -Action Backup

# Verificar funcionamiento
.\NCSI-LocalServer-Automation.ps1 -Action Test
```

### 🔴 Para Administradores Avanzados (Empresarial)

```powershell
# Monitoreo continuo del servidor
.\NCSI-Advanced-Tools.ps1 -Action Monitor -MonitorInterval 30

# Configuración automática de GPO
.\NCSI-Advanced-Tools.ps1 -Action GPOConfig -GPOName "NCSI-Corporativo"

# Diagnósticos avanzados
.\NCSI-Advanced-Tools.ps1 -Action Diagnostics

# Health check completo
.\NCSI-Advanced-Tools.ps1 -Action HealthCheck
```

## 🎯 Casos de Uso por Escenario

### 🏠 Escenario: Instalación Doméstica/SOHO
**Objetivo**: Eliminar el mensaje "Sin Internet" en red doméstica

```powershell
# Solución rápida y simple
.\Quick-Install.ps1 -AutoDetectIP
```

**Resultado**: Servidor local funcionando en 5 minutos

---

### 🏢 Escenario: Oficina Pequeña (5-50 PCs)
**Objetivo**: Servidor NCSI centralizado para toda la oficina

```powershell
# 1. Instalar en un servidor/PC dedicado con IP fija
.\NCSI-LocalServer-Automation.ps1 -Action Install -ServerIP "192.168.1.100"

# 2. Configurar clientes manualmente o via script
# En cada cliente, ejecutar solo la configuración de registro:
$ServerURL = "http://192.168.1.100/connecttest.txt"
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\NlaSvc\Parameters\Internet" -Name "ActiveWebProbeHost" -Value $ServerURL
```

**Resultado**: Un servidor para toda la red

---

### 🏭 Escenario: Empresa con Active Directory
**Objetivo**: Implementación masiva via GPO

```powershell
# 1. Instalar servidor NCSI en infraestructura
.\NCSI-LocalServer-Automation.ps1 -Action Install -ServerIP "ncsi.empresa.local"

# 2. Configurar GPO automáticamente
.\NCSI-Advanced-Tools.ps1 -Action GPOConfig -DomainController "dc01.empresa.local" -GPOName "NCSI-Empresarial"

# 3. Monitoreo continuo
.\NCSI-Advanced-Tools.ps1 -Action Monitor -EmailAlerts -SMTPServer "mail.empresa.local"
```

**Resultado**: Implementación empresarial completa con monitoreo

---

### 🔐 Escenario: Entorno de Alta Seguridad
**Objetivo**: NCSI con SSL y monitoreo avanzado

```powershell
# 1. Instalación con SSL
.\NCSI-LocalServer-Automation.ps1 -Action Install
.\NCSI-Advanced-Tools.ps1 -Action SSLSetup -SSLCertPath "C:\certs\ncsi.pfx"

# 2. Configuración con HTTPS
$ServerURL = "https://ncsi.segura.local/connecttest.txt"
# Configurar registro con HTTPS...

# 3. Monitoreo con alertas
.\NCSI-Advanced-Tools.ps1 -Action HealthCheck -EmailAlerts
```

**Resultado**: Servidor seguro con monitoreo y alertas

## ⚙️ Características por Script

### 🚀 Quick-Install.ps1
- ✅ **Instalación en 5 minutos**
- ✅ **Cero configuración manual**
- ✅ **Detección automática de IP**
- ✅ **Verificación automática**
- ✅ **Creación de archivo informativo**

### ⚙️ NCSI-LocalServer-Automation.ps1
- ✅ **Descarga automática de XAMPP**
- ✅ **Instalación silenciosa completa**
- ✅ **Sistema de backup/restore**
- ✅ **Configuración de registro completa**
- ✅ **Verificación y testing integrados**
- ✅ **Logging detallado**
- ✅ **Gestión completa del ciclo de vida**

### 🛠️ NCSI-Advanced-Tools.ps1
- ✅ **Monitoreo en tiempo real**
- ✅ **Configuración automática de GPO**
- ✅ **Diagnósticos avanzados de red**
- ✅ **Configuración de SSL/HTTPS**
- ✅ **Gestión de múltiples servidores**
- ✅ **Health checks programados**
- ✅ **Sistema de alertas por email**

## 🔧 Requisitos Técnicos

### Requisitos Mínimos
- **SO**: Windows 10/11 (64-bit)
- **PowerShell**: 5.0+
- **Permisos**: Administrador local
- **RAM**: 4 GB (para XAMPP)
- **Disco**: 200 MB libres
- **Red**: Tarjeta de red activa

### Requisitos para Funciones Avanzadas
- **Active Directory**: Para configuración de GPO
- **RSAT Tools**: Para gestión de políticas de grupo
- **SMTP Server**: Para alertas por email
- **Certificados SSL**: Para implementaciones HTTPS

## 📊 Comparación de Scripts

| Característica | Quick-Install | Automation | Advanced-Tools |
|:---------------|:-------------:|:----------:|:--------------:|
| **Tiempo instalación** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐ |
| **Facilidad de uso** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐ |
| **Características** | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Backup/Restore** | ❌ | ✅ | ✅ |
| **Monitoreo** | ❌ | ❌ | ✅ |
| **GPO Integration** | ❌ | ❌ | ✅ |
| **SSL Support** | ❌ | ❌ | ✅ |
| **Alertas Email** | ❌ | ❌ | ✅ |
| **Diagnósticos** | ❌ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |

## 🛡️ Mejores Prácticas de Seguridad

### 🔒 Configuración Segura
```powershell
# 1. Siempre crear backup antes de cambios
.\NCSI-LocalServer-Automation.ps1 -Action Backup

# 2. Usar IP estática en producción
.\NCSI-LocalServer-Automation.ps1 -Action Install -ServerIP "IP_FIJA_AQUI"

# 3. Configurar firewall para permitir solo tráfico interno
New-NetFirewallRule -DisplayName "NCSI-Server" -Direction Inbound -Protocol TCP -LocalPort 80 -Action Allow -LocalAddress "192.168.0.0/16"

# 4. Implementar monitoreo
.\NCSI-Advanced-Tools.ps1 -Action Monitor -EmailAlerts
```

### 🔐 Hardening del Servidor
```powershell
# 1. Configurar HTTPS en lugar de HTTP
.\NCSI-Advanced-Tools.ps1 -Action SSLSetup

# 2. Limitar acceso solo a redes internas
# 3. Implementar logging centralizado
# 4. Monitoreo de health continuo
```

## 🚨 Solución de Problemas

### ❓ Problemas Comunes

#### "Error: No se puede descargar XAMPP"
**Causa**: Sin conexión a internet o proxy bloqueando  
**Solución**:
```powershell
# Usar instalación rápida sin descarga
.\Quick-Install.ps1 -SkipDownload

# O configurar proxy si es necesario
$env:HTTP_PROXY = "http://proxy.empresa.com:8080"
.\NCSI-LocalServer-Automation.ps1 -Action Install
```

#### "Error: Puerto 80 en uso"
**Causa**: IIS u otro servidor web ejecutándose  
**Solución**:
```powershell
# Detener IIS
Stop-Service -Name "W3SVC" -Force

# O cambiar puerto en XAMPP manualmente
# Editar: C:\xampp\apache\conf\httpd.conf
# Cambiar: Listen 80 → Listen 8080
```

#### "Registro no se actualiza"
**Causa**: Permisos insuficientes o servicio bloqueado  
**Solución**:
```powershell
# Verificar permisos de administrador
[Security.Principal.WindowsIdentity]::GetCurrent().Groups -contains [Security.Principal.SecurityIdentifier]"S-1-5-32-544"

# Reiniciar servicio NLA
Restart-Service -Name "NlaSvc" -Force
```

### 🔍 Comandos de Diagnóstico

```powershell
# Verificar estado completo
.\NCSI-LocalServer-Automation.ps1 -Action Status

# Ejecutar diagnósticos avanzados
.\NCSI-Advanced-Tools.ps1 -Action Diagnostics

# Test de conectividad
.\NCSI-Advanced-Tools.ps1 -Action NetworkTest

# Health check completo
.\NCSI-Advanced-Tools.ps1 -Action HealthCheck
```

## 📈 Roadmap y Mejoras Futuras

### 🎯 Versión 1.1 (Próximamente)
- [ ] **Instalador GUI** - Interfaz gráfica para usuarios no técnicos
- [ ] **Docker Support** - Contenedores para implementación cloud
- [ ] **Multi-plataforma** - Soporte para Linux y macOS
- [ ] **Dashboard Web** - Panel web para monitoreo

### 🎯 Versión 1.2 (Planificado)
- [ ] **Alta Disponibilidad** - Configuración de múltiples servidores
- [ ] **Load Balancing** - Distribución de carga automática
- [ ] **LDAP Integration** - Integración con directorios empresariales
- [ ] **API REST** - Interface programática para integración

## 📞 Soporte y Comunidad

### 🐛 Reporte de Issues
1. **Ejecutar diagnósticos**: `.\NCSI-Advanced-Tools.ps1 -Action Diagnostics`
2. **Revisar logs**: Archivos en `%TEMP%\NCSI-*.log`
3. **Incluir información del sistema**: SO, PowerShell version, etc.
4. **Describir pasos para reproducir el problema**

### 🤝 Contribuciones
Las contribuciones son bienvenidas:
- **Reportar bugs y issues**
- **Sugerir mejoras y nuevas características**
- **Contribuir con código y documentación**
- **Compartir casos de uso y experiencias**

### 📚 Recursos Adicionales
- [Documentación oficial NCSI - Microsoft](https://learn.microsoft.com/en-us/windows-server/networking/ncsi/)
- [XAMPP Documentation](https://www.apachefriends.org/docs/)
- [PowerShell Best Practices](https://docs.microsoft.com/en-us/powershell/)

## 📄 Licencia

Este proyecto está licenciado bajo **GNU General Public License v3.0 (GPL-3.0)**.

Ver archivo `LICENSE` para detalles completos.

---

## 🎉 Inicio Rápido - TL;DR

```powershell
# Para la mayoría de usuarios - Instalación en 5 minutos:
.\Quick-Install.ps1

# Para control total:
.\NCSI-LocalServer-Automation.ps1 -Action Install

# Para entornos empresariales:
.\NCSI-Advanced-Tools.ps1 -Action GPOConfig
```

**¡Elimina el molesto "Sin Internet" en tu red interna en menos de 5 minutos!**

---

*Desarrollado por **** - Automatización profesional para infraestructura de red*