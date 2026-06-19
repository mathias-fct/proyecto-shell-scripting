# Sistema de Automatización para Administración de Servidores Linux
## Proyecto Parcial — Shell Scripting | IDAT Escuela de Tecnología

**Alumno(s):** [MATHIAS CAYCHO TARAZONA / ROBERTO ESCOBAR SOTELO]  
**Grupo:** [GRUPO 4]  
**Fecha de entrega:** 19 de Junio 2026  
**Repositorio:** [pega aquí el link de GitHub o nube]

---

## Descripción del Problema

El área de TI de una empresa mediana realiza manualmente tareas básicas en sus servidores Linux: revisar el uso del disco, limpiar archivos temporales y generar reportes del estado del sistema. Esto genera errores humanos, demoras y falta de trazabilidad.

Este proyecto resuelve esas tres tareas con scripts en Bash que pueden ejecutarse de forma programada o manual.

---

## Estructura del Proyecto

```
proyecto-shell/
├── scripts/
│   ├── 01_sistema_info.sh        # Información del sistema
│   ├── 02_gestor_archivos.sh     # Gestión de archivos y permisos
│   ├── 03_automatizacion.sh      # Cron + AWK + SED
│   └── ejecutar_proyecto.sh      # Ejecuta todo en orden
├── reportes/                     # Se crea automáticamente
├── logs/                         # Se crea automáticamente
└── datos/                        # Se crea automáticamente
```

---

## Requisitos

- Ubuntu Server 22.04 o superior (o cualquier Linux con Bash)
- Paquetes: `bash`, `coreutils`, `gawk`, `sed`, `cron`
- Para instalar lo necesario:
  ```
  sudo apt update && sudo apt install -y gawk sed cron
  ```

---

## Cómo Ejecutar

### Opción A — Ejecutar todo el proyecto de una vez

```bash
cd proyecto-shell/scripts/
chmod +x *.sh
./ejecutar_proyecto.sh
```

### Opción B — Ejecutar cada script por separado

```bash
# Script 1: ver información del sistema
chmod +x 01_sistema_info.sh
./01_sistema_info.sh

# Script 2: gestión de archivos (opciones disponibles)
chmod +x 02_gestor_archivos.sh
./02_gestor_archivos.sh               # modo interactivo
./02_gestor_archivos.sh --dias 5      # eliminar archivos con +5 días
./02_gestor_archivos.sh --auto        # sin preguntas, todo automático

# Script 3: automatización
chmod +x 03_automatizacion.sh
./03_automatizacion.sh
```

---

## Descripción de Cada Script

### 01_sistema_info.sh — Script de entorno del sistema

**Problema que resuelve:** los administradores deben revisar manualmente el estado del servidor cada vez que hay una incidencia.

**Qué hace:**
- Muestra: usuario actual, hostname, sistema operativo, kernel, arquitectura
- Muestra: espacio total/usado/libre del disco y porcentaje de uso de la RAM
- Evalúa si el disco supera un umbral de aviso (75%) o crítico (90%)
- Guarda un reporte en `reportes/sistema_YYYYMMDD_HHMMSS.txt`

**Ejemplo de ejecución:**
```
======================================================
         REPORTE DEL ESTADO DEL SERVIDOR
======================================================
  Fecha:                 16/06/2026
  Hora:                  08:35:12
  Usuario actual:        adminTI
  Nombre del server:     servidor-ti
------------------------------------------------------
  Sistema operativo:     Ubuntu 22.04.3 LTS
  Versión del kernel:    5.15.0-88-generic
  Arquitectura:          x86_64
------------------------------------------------------
  Disco total:           50G
  Disco usado:           12G  (24%)
  Disco libre:           38G
------------------------------------------------------
  RAM total:             2.0Gi
  RAM usada:             512Mi
  RAM libre:             1.5Gi
======================================================

  ANÁLISIS DE ESPACIO EN DISCO
------------------------------------------------------
  [OK] Disco al 24% — Operando con normalidad.
```

---

### 02_gestor_archivos.sh — Gestor de archivos y permisos

**Problema que resuelve:** la acumulación de archivos .tmp y .log sin limpieza provoca que el disco se llene y los servicios fallen.

**Qué hace:**
1. Crea la estructura de directorios (`temporales/`, `respaldo/`)
2. Genera archivos de prueba (.tmp, .log) — incluyendo algunos backdateados para demostrar la limpieza
3. Copia los archivos al directorio de respaldo (con hasta 3 reintentos si falla)
4. Aplica permisos: 444 en respaldo (protección) y 644 en temporales
5. Elimina archivos con más de N días de antigüedad, con confirmación opcional

**Parámetros:**

| Parámetro | Descripción |
|-----------|-------------|
| `--dias N` | Elimina archivos más antiguos de N días (por defecto: 7) |
| `--auto` | Modo automático, sin preguntas |

**Ejemplo de ejecución:**
```
  PASO 5: Limpieza de archivos temporales
------------------------------------------------------
  Criterio   : archivos con más de 7 día(s) de antigüedad

  Archivo: basura_1.tmp
  Ruta   : /home/user/proyecto-shell/archivos_trabajo/temporales/basura_1.tmp
    ¿Eliminar este archivo? (s/n): s
    --> [OK] Eliminado (intento 1)
```

---

### 03_automatizacion.sh — Automatización con AWK, SED y CRON

**Problema que resuelve:** generar reportes y programar tareas requería conocimiento manual de varios comandos dispersos.

**Qué hace:**

**Módulo AWK:** lee la salida del comando `df -h`, la convierte a CSV y genera un reporte formateado en columnas, identificando automáticamente las particiones que superan el 80% de uso.

**Módulo SED:** edita el reporte generado por AWK para resaltar visualmente las alertas, reemplazando etiquetas y añadiendo la fecha de procesamiento al inicio del archivo.

**Módulo CRON:** programa la ejecución automática de `01_sistema_info.sh` todos los días a las 08:00 AM, guardando la salida en un archivo de log.

**Ejemplo de la tarea cron programada:**
```
0 8 * * * /home/user/proyecto-shell/scripts/01_sistema_info.sh >> /logs/cron_sistema.log 2>&1
```

**Interpretación:**
- `0 8` → minuto 0, hora 8 = las 08:00 AM
- `* * *` → todos los días, todos los meses, cualquier día de la semana

---

## Lógica Aplicada

| Elemento | Uso en el proyecto |
|----------|-------------------|
| Variables | Rutas, umbrales, contadores de errores, datos del sistema |
| Condicionales (`if`) | Evaluar uso del disco, verificar existencia de archivos, validar argumentos |
| Bucles (`for`, `while`) | Recorrer directorios, reintentar operaciones fallidas |
| Funciones | Modularizar cada tarea (crear, copiar, limpiar, registrar) |
| `find` | Buscar archivos por extensión y antigüedad |
| `awk` | Procesar y formatear datos del disco en columnas |
| `sed` | Reemplazar y editar texto en reportes |
| `crontab` | Programar ejecución automática diaria |
| Redirección (`>>`, `2>&1`) | Guardar salida y errores en archivos de log |

---

## Problemas Detectados y Soluciones

| Problema | Solución implementada |
|----------|-----------------------|
| `lsb_release` no existe en todos los sistemas | Se usa `/etc/os-release` como alternativa |
| Copia de archivos puede fallar por permisos | Reintentos automáticos con contador (hasta 3 veces) |
| Tarea cron se duplica si se ejecuta varias veces | Se verifica con `grep` antes de agregar la nueva entrada |
| Archivos ya eliminados al intentar borrarlos de nuevo | Se verifica existencia con `-f` antes de `rm` |
| Usuario puede ingresar un valor no numérico en `--dias` | Validación con expresión regular `^[0-9]+$` |

---

## Posibles Mejoras

- Enviar un correo automático cuando el disco supere el 90%.
- Comprimir los archivos antes de respaldarlos (usando `tar` o `gzip`).
- Leer los umbrales y configuraciones desde un archivo `.conf` externo.
- Migrar la tarea programada de cron a `systemd timers` para mayor control.
- Agregar colores en la salida de terminal para mejorar la legibilidad.

---

## Evidencias de Prueba

*(Aquí pega tus capturas de pantalla mostrando cada script ejecutándose en tu Ubuntu Server)*

- Captura 1: ejecución de `01_sistema_info.sh` mostrando información del sistema
- Captura 2: ejecución de `02_gestor_archivos.sh` con la limpieza de archivos
- Captura 3: ejecución de `03_automatizacion.sh` con el reporte AWK y SED
- Captura 4: salida de `crontab -l` mostrando la tarea programada
- Captura 5: contenido de alguno de los reportes generados en `reportes/`
