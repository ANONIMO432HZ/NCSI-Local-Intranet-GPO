# 🌐 NCSI Local Intranet: Evasión Profesional de Indicador de Conectividad (GPO)

**Solución oficial para eliminar el "Sin Internet" en entornos de Intranet Aislada o con Proxy mediante la configuración de un Servidor de Prueba Local (NCSI)**.

> ⚠️ **ESTADO BETA**: Estos scripts están en fase beta y pueden contener errores. Se recomienda probar en un entorno controlado antes de usar en producción. Reporte cualquier problema encontrado a través de los issues del repositorio.
> 
> ✅ **CONFIGURACIÓN MANUAL ESTABLE**: Los pasos de configuración manual descritos en este documento han sido probados y funcionan correctamente. Si experimenta problemas con los scripts automatizados, puede seguir el proceso manual paso a paso.

---

## 📝 Descripción del Proyecto

Este repositorio ofrece una guía detallada y la documentación necesaria para implementar un **Indicador de Estado de Conectividad de Red (NCSI)** local mediante la **Política de Grupo (GPO)** de Windows.

El objetivo es resolver el problema común donde los equipos con Windows 10/11 en redes aisladas (Intranets) o con acceso a Internet restringido (por un firewall o proxy) muestran erróneamente el estado de **"Sin Internet"** en la barra de tareas.



Al configurar un servidor de prueba interno y redirigir el NCSI a este recurso a través de GPO, garantizamos que el icono de red refleje la correcta funcionalidad de la red interna, mejorando la experiencia del usuario y la gestión del sistema.

---

## ⭐ Beneficios de Implementar NCSI Local en Entornos Empresariales

| 🎯 Beneficio | 📋 Descripción |
|:---------------------------|:----------------|
| **🎨 Experiencia de Usuario** | Elimina el confuso mensaje de "Sin Internet", reduciendo llamadas al soporte técnico.<br>El estado será **"Conectado"** o **"Acceso a Internet"**. |
| **⚙️ Integridad de Aplicaciones** | Evita que aplicaciones que dependen del estado NCSI (como OneDrive, Teams, etc.)<br>asuman que no hay conexión, permitiendo su correcto funcionamiento en la red local. |
| **🔒 Alineación con Seguridad** | Permite mantener el bloqueo de las pruebas de conectividad salientes a servidores<br>de Microsoft, cumpliendo con estrictas políticas de privacidad y seguridad perimetral. |
| **🏢 Gestión Centralizada (GPO)** | La configuración se aplica de forma uniforme y centralizada a todos los equipos<br>del dominio, garantizando consistencia y fácil mantenimiento. |

---

## 🛠️ 2. Guía de Configuración

La solución requiere dos pasos: la preparación del servidor de prueba y la configuración de las políticas de grupo en el Directorio Activo (Active Directory).

### A. Preparación del Servidor de Prueba (Web Probe)

Configure un servidor web (IIS, Apache, Nginx, XAMPP, etc.) accesible por la Intranet que cumpla estos criterios:

1.  **URL de Sondeo:** Debe ser accesible por HTTP o HTTPS. Ejemplo: `http://servidor-ncsi.dominio.local/connecttest.txt`
2.  **Archivo de Prueba:** Cree un archivo llamado **`connecttest.txt`** en la raíz web.
3.  **Contenido Exacto:** El contenido de este archivo debe ser estrictamente:
    ```
    Microsoft Connect Test
    ```
    *(Referencia: https://learn.microsoft.com/en-us/windows-server/networking/ncsi/ncsi-frequently-asked-questions)*

---
#### 🟫 Configuración del Servidor de Pruebas con XAMPP ✅ PROBADO Y ESTABLE

XAMPP es un paquete de software que incluye el servidor web Apache, ideal para implementar la sonda NCSI local y es totalmente compatible con Windows 10 y 11.

##### 1. Requisitos e Instalación de XAMPP ✅ VERIFICADO

- **Descarga e Instalación:**
  - Descarga la versión más reciente de XAMPP para Windows desde [Apache Friends](https://www.apachefriends.org/es/index.html).
  - Ejecuta el instalador y acepta las opciones predeterminadas para una configuración sencilla.
- **Inicia XAMPP:**
  - Abre el Panel de Control de XAMPP.
  - Haz clic en **Start** (Iniciar) junto a Apache. El estado debe ponerse en verde y mostrar los números de puerto (generalmente 80).

##### 2. Creación del Archivo de Prueba NCSI ✅ VERIFICADO

El NCSI de Windows realiza una petición HTTP esperando el contenido exacto en una URL pública. Replicaremos esto localmente:

- **Navega a la Carpeta Raíz de Documentos de Apache:**
  - Ubicación habitual: `C:\xampp\htdocs\`
- **Crea el archivo**:
  - Crea un nuevo archivo de texto dentro de esa carpeta.
  - Nómbralo exactamente: `connecttest.txt`
  - **Contenido exacto**:
    ```
    Microsoft Connect Test
    ```
  - (Sin líneas extra, sin espacios ni saltos adicionales)
  - Guarda el archivo.

##### 3. Verificación (Prueba Local) ✅ VERIFICADO

- Abre tu navegador favorito e ingresa:
  - `http://localhost/connecttest.txt`
- Si ves el texto **Microsoft NCSI**, el servidor de prueba está listo.

##### 4. Configuración de Windows (Clientes) ✅ VERIFICADO

Después de levantar el servidor Apache, debes indicarle a Windows que utilice tu prueba local. El método más rápido es modificar temporalmente el archivo HOSTS de Windows para redireccionar los dominios de prueba al propio equipo.

###### Método A: Redirección con Archivo HOSTS

- **Abre el Bloc de Notas como Administrador:**
  - Busca "Bloc de Notas" en el menú de Inicio, haz clic derecho y selecciona "Ejecutar como administrador".
- **Abre el archivo HOSTS:**
  - Archivo: `C:\Windows\System32\drivers\etc\hosts`
  - Selecciona y abre con el Bloc de Notas.
- **Añade las Líneas de Redirección al final del archivo:**
    ```
    # Redireccionar prueba de conectividad de Microsoft al servidor local (XAMPP)
    127.0.0.1 msftncsi.com
    127.0.0.1 www.msftncsi.com
    127.0.0.1 msftconnecttest.com
    127.0.0.1 www.msftconnecttest.com
    ```
- **Guarda y cierra el archivo HOSTS.**

**Opción B: Política de Grupo (GPO) o Registro (Recomendada para Servidor Interno Dedicado)**
Si quieres que este servidor XAMPP funcione como un servidor de prueba para toda una red (debes darle una dirección IP estática a tu pc con xamp y configurarlo para que sea accesible), la configuración oficial es mejor.



| 🔧 Configuración | 🏢 Ubicación GPO (Equipo) | 📝 Ruta de Registro | ⚙️ Valor a Establecer |
|:------------------|:--------------------------|:-------------------|:---------------------|
| **🌐 URL del Sondeo Web** | `Red` → `Indicador de estado de conectividad de red`<br>→ `"Especificar el servidor web de sondeo de intranet"` | `HKLM\...\NlaSvc\Parameters\Internet\`<br>`ActiveWebProbeHost` | `http://[IP_o_Nombre_del_Servidor]/connecttest.txt` |
| **📄 Contenido Esperado** | *(Esta GPO no lo gestiona directamente)* | `HKLM\...\NlaSvc\Parameters\Internet\`<br>`ActiveWebProbeContent` | `Microsoft Connect Test` |
| **🔍 Sondeo Activo** | `Configuración de comunicación de Internet`<br>→ `"Desactivar las pruebas activas..."` | `HKLM\...\NlaSvc\Parameters\Internet\`<br>`EnableActiveProbing` | `1`<br>*(Habilitado según Microsoft)* |

Nota sobre la IP/Nombre: Si usas el método GPO/Registro, debes reemplazar [IP_o_Nombre_del_Servidor] con la dirección IP o el nombre de red de tu PC con XAMPP (por ejemplo, http://192.168.1.50/connecttest.txt).

**Resultado:**
Cuando Windows intente contactar a esos dominios, será redirigido al Apache de XAMPP y servirá el archivo `connecttest.txt` local, validando el estado de red como "Conectado" o "Acceso a Internet".

> 💡 Si tienes dudas sobre la instalación, busca videos en Youtube como: _Descargar, Instalar y Configurar XAMPP (Apache + MySQL + PHP) | Windows 10_11.

---

## 🚀 Suite de Automatización Completa

Se ha desarrollado una **suite completa de scripts** que automatiza desde la instalación básica hasta la gestión empresarial avanzada:

> ⚠️ **IMPORTANTE**: Los scripts de automatización están en desarrollo activo y pueden presentar errores. Úselos bajo su propio riesgo y siempre haga respaldos antes de aplicar cambios en sistemas de producción.

### 📦 Scripts Disponibles

| Script | Nivel | Tiempo | Propósito |
|:-------|:------|:-------|:----------|
| **`NCSI-Control-Menu.bat`** | 🎮 **Principal** | - | **Menú de control principal** - Orquestador de toda la suite |
| **`Quick-Install.ps1`** | 🟢 Básico | 5 min | Instalación express para usuarios domésticos |
| **`NCSI-LocalServer-Automation.ps1`** | 🟡 Intermedio | 10 min | Automatización completa con backup/restore |
| **`NCSI-Advanced-Tools.ps1`** | 🔴 Avanzado | Variable | Herramientas empresariales y monitoreo |

### 🎮 Inicio Rápido - Menú Principal

```batch
:: Ejecutar el menú principal (elevación automática de privilegios)
NCSI-Control-Menu.bat
```

El **script principal** `NCSI-Control-Menu.bat` actúa como orquestador y ofrece:

- ✅ **Elevación automática de privilegios**
- ✅ **Menú interactivo con opciones claras**
- ✅ **Confirmaciones antes de cada acción**
- ✅ **Bypass automático de execution policy**
- ✅ **Gestión completa de errores**
- ✅ **Logging centralizado**

### 🎯 Casos de Uso por Script

#### 🟢 **Para Usuarios Domésticos** - `Quick-Install.ps1`
```batch
:: Desde el menú principal, opción 1: Instalación Express
:: O directamente:
powershell -ExecutionPolicy Bypass -NoProfile -File "Quick-Install.ps1"
```
- **Tiempo**: 5 minutos
- **Configuración**: Automática
- **Ideal para**: Redes domésticas, SOHO

#### 🟡 **Para Administradores** - `NCSI-LocalServer-Automation.ps1`
```batch
:: Desde el menú principal, opciones 2-6
:: Instalación completa, backup, restore, verificación
```
- **Tiempo**: 10-15 minutos
- **Características**: Backup/restore, verificación completa
- **Ideal para**: Oficinas pequeñas y medianas

#### 🔴 **Para Entornos Empresariales** - `NCSI-Advanced-Tools.ps1`
```batch
:: Desde el menú principal, opciones 7-11
:: Monitoreo, GPO, diagnósticos, SSL
```
- **Tiempo**: Variable según configuración
- **Características**: GPO automático, monitoreo continuo, SSL
- **Ideal para**: Infraestructuras empresariales con Active Directory

### 🛠️ Características de la Suite

| Característica | Quick-Install | Automation | Advanced-Tools |
|:---------------|:-------------:|:----------:|:--------------:|
| **Instalación XAMPP** | ✅ Automática | ✅ Completa | ✅ Con SSL |
| **Backup/Restore** | ❌ | ✅ Completo | ✅ Avanzado |
| **Configuración GPO** | ❌ | ❌ | ✅ Automática |
| **Monitoreo** | ❌ | ⚠️ Básico | ✅ Continuo |
| **Alertas Email** | ❌ | ❌ | ✅ Configurables |
| **Diagnósticos** | ⚠️ Básicos | ✅ Completos | ✅ Avanzados |
| **SSL/HTTPS** | ❌ | ❌ | ✅ Automático |

### 📋 Documentación Completa

Para información detallada sobre configuración, uso avanzado y solución de problemas, consulte:

- **`NCSI-Script-Documentation.md`** - Guía detallada de uso
- **`NCSI-Scripts-README.md`** - Documentación completa de la suite
- **Archivos de log** en `%TEMP%\NCSI-*.log` para diagnósticos

**Opcional si solo quieres deshabilitar NCSI sin muchas complicaciones con un simple paso (es posible que este metodo no desbloquee todas las funcionalidades que emular un servidor local ncsi)**

* [Video tutorial de referencia](https://youtu.be/sUNa-fzk9F0)

Antes de modificar el registro en recomendable hacer un backup.reg del editor de registro

Paso 1.

Abrir Regedit: 
Tecla windows + R = regedit

Ruta: Equipo\HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\NlaSvc\Parameters\Internet

Paso 2.
Ubicar el archivo "EnableActiveProbing" y con doble clic cambiar el información de valor "1" por "0" sin comillas, aceptar y cerrar.

Paso 3.
Para revertir simplemente cambiar el información de valor "0" a "1".

### B. Configuración de GPO (Política de Grupo) ✅ MÉTODO OFICIAL PROBADO

Utilice la Consola de Administración de Directivas de Grupo (`gpmc.msc`) y aplique la GPO a los equipos cliente (unidades organizativas).

**Ruta Común:** `Configuración del equipo` > `Políticas` > `Plantillas administrativas`

#### 1. Redirigir el Sondeo Web

Esta política indica a Windows dónde realizar la prueba de conectividad HTTP.

| 🔧 Configuración | 📝 Valor | 📍 Ruta |
|:------------------|:------|:-------|
| **⚡ Estado** | `Habilitada` | `Red` → `Indicador de estado de conectividad de red` |
| **📋 Política** | `Especificar el servidor web de sondeo de intranet` | |
| **🌐 URL** | `http://servidor-ncsi.dominio.local/connecttest.txt`<br>*(URL completa del archivo de prueba)* | |

#### 2. Establecer el Contenido Esperado

Esta política asegura que Windows sepa qué texto esperar de la URL anterior.

| 🔧 Configuración | 📝 Valor | 📍 Ruta |
|:------------------|:------|:-------|
| **⚡ Estado** | `Habilitada` | `Red` → `Indicador de estado de conectividad de red` |
| **📋 Política** | `Especificar el contenido del sondeo web de intranet` | |
| **📄 Contenido** | `Microsoft Connect Test`<br>*(Texto exacto requerido)* | |

#### 3. Configuración Adicional (Opcional: DNS)

Si su red no resuelve dominios de prueba externos, puede usar esta política:

| 🔧 Configuración | 📝 Valor | 📍 Ruta |
|:------------------|:------|:-------|
| **📋 Política** | `Especificar el host del sondeo DNS de intranet` | `Red` → `Indicador de estado de conectividad de red` |
| **🖥️ Host** | `dns.intranet.local`<br>*(Host local que su red resuelva correctamente)* | |
| **🌐 IP Esperada** | `192.168.1.1`<br>*(IP que debe devolver el host anterior)* | |


---

## 📜 Licencia

Este proyecto está bajo la Licencia **GNU General Public License v3.0 (GPL-3.0)**.

Consulte el archivo **`LICENSE`** para obtener más detalles.

---

## 🔗 Referencias Oficiales

* [NCSI Overview (Descripción general del NCSI) - Microsoft Learn](https://learn.microsoft.com/en-us/windows-server/networking/ncsi/ncsi-overview)
* [NCSI Frequently Asked Questions (Preguntas frecuentes sobre NCSI) - Microsoft Learn](https://learn.microsoft.com/en-us/windows-server/networking/ncsi/ncsi-frequently-asked-questions)
* [Cómo recopilar datos para diagnosticar problemas de NCSI](https://learn.microsoft.com/en-us/windows-server/networking/ncsi/ncsi-troubleshooting-guide)
* [How to Fix ‘Msftconnecttest Redirect’ Error on Windows 10 [Tutorial]](https://youtu.be/sUNa-fzk9F0)
