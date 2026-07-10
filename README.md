# Sistema de Automatización para Administración de Servidores Linux
## Proyecto Parcial — Shell Scripting | Instituto Tecnológico IDAT (Ciberseguridad)

**Alumnos:** Mathias Fernando Caycho Tarazona / Roberto Carlos Escobar Sotelo
**Grupo:** Grupo 4
**Profesor:** Gonzales Guevara Rommel Andres
**Fecha de finalización:** 6 de julio de 2026
**Repositorio:** https://github.com/mathias-fct/proyecto-shell-scripting

---

## Descripción del Problema

En un servidor Linux administrado a mano, tareas rutinarias como revisar el uso de disco, depurar archivos temporales viejos y generar reportes de estado consumen tiempo del administrador y no dejan registro de qué se hizo ni cuándo.

Este proyecto automatiza esas tres tareas con scripts en Bash independientes, pensados para ejecutarse tanto de forma manual como programada (cron), dejando trazabilidad de cada acción en reportes (`.txt`) y bitácoras (`.log`).

---

## Estructura del Proyecto

```
proyecto-shell-scripting/
├── scripts-shell/
│   ├── 01_sistema_info.sh        # Información del sistema
│   ├── 02_gestor_archivos.sh     # Gestión de archivos y permisos
│   └── 03_automatizacion.sh      # Consola AWK + SED + CRON
├── archivos_trabajo/              # Se crea automáticamente (02)
│   ├── temporales/
│   └── respaldo/                  # protegido en modo lectura (444)
├── reportes/                      # Se crea automáticamente (01, 02, 03)
├── logs/                          # Se crea automáticamente (02, 03)
└── datos/                         # Se crea automáticamente (03, aún sin uso)
```

---

## Requisitos

- Ubuntu Server 24.04 LTS (entorno real de prueba) o cualquier distro con Bash ≥ 4.
- Utilidades estándar ya presentes en la mayoría de instalaciones: `bash`, `df`, `free`, `du`, `awk`, `sed`, `grep`, `find`, `touch`, `chmod`, `tee`, `cut`, `realpath`.
- `cron` activo — necesario para la Opción 5 de `03_automatizacion.sh`. Si tu instalación es mínima:
  ```bash
  sudo apt update && sudo apt install -y cron
  ```
- `lsb_release` es opcional: si no está, `01_sistema_info.sh` cae automáticamente a leer `/etc/os-release`.

---

## Cómo Ejecutar

```bash
git clone https://github.com/mathias-fct/proyecto-shell-scripting.git
cd proyecto-shell-scripting/scripts-shell
chmod +x *.sh
```

```bash
./01_sistema_info.sh                  # diagnóstico del servidor
./02_gestor_archivos.sh               # modo interactivo (7 días por defecto)
./02_gestor_archivos.sh --dias 15     # cambia el umbral de antigüedad
./02_gestor_archivos.sh --auto        # sin confirmaciones (pensado para cron)
./03_automatizacion.sh                # consola AWK + SED + CRON
```

---

## Descripción de Cada Script

### `01_sistema_info.sh` — Diagnóstico del servidor

**Problema que resuelve:** revisar a mano el estado del servidor (disco, RAM, versión de SO) cada vez que hay una incidencia toma tiempo y no queda registro de qué se encontró.

**Qué hace:**
- Muestra fecha, hora, usuario, hostname, SO (con *fallback* a `/etc/os-release`), kernel y arquitectura.
- Reporta espacio de disco (`df -h /`) y memoria (`free -h`).
- Evalúa el disco contra dos umbrales: `UMBRAL_AVISO=75` y `UMBRAL_CRITICO=90`.
- Guarda un reporte con timestamp en `reportes/sistema_<fecha>_<hora>.txt`.

**Ejemplo real de ejecución:**
```
======================================================
         REPORTE DEL ESTADO DEL SERVIDOR
======================================================
  Fecha:                 06/07/2026
  Hora:                  07:08:10
  Usuario actual:        root
  Nombre del server:     servidor-ti
------------------------------------------------------
  Sistema operativo:     Ubuntu 24.04.4 LTS
  Kernel:                6.8.0-124-generic
  Arquitectura:          x86_64
------------------------------------------------------
  Disco total:           9,8G
  Disco usado:           3,1G (33%)
  Disco libre:           6,3G
------------------------------------------------------
  RAM total:             7,7Gi
  RAM usada:             527Mi
  RAM libre:             6,6Gi
======================================================

  ANÁLISIS DE ESPACIO EN DISCO
------------------------------------------------------
  [OK] Disco al 33% — Operando con normalidad.
  (Umbral aviso: 75% | Umbral crítico: 90%)

  [OK] Reporte guardado en: .../reportes/sistema_20260706_070810.txt
```

---

### `02_gestor_archivos.sh` — Gestor de archivos y permisos

**Problema que resuelve:** los archivos temporales y logs viejos se acumulan sin control y pueden llenar el disco si nadie los depura.

**Qué hace:**
1. Crea la estructura de carpetas (`temporales/`, `respaldo/`) si no existe.
2. Genera archivos de prueba: 3 recientes y 3 con fecha forzada 10 días atrás (`touch -d "10 days ago"`).
3. Respalda `temporales/` en `respaldo/` (hasta 3 reintentos si falla la copia).
4. Aplica permisos: `755` en directorios, `644` en temporales, `444` (solo lectura) en el respaldo.
5. Busca archivos `*.tmp`, `*.log` o `*.bak` más viejos que `DIAS_LIMITE` y pregunta uno por uno si eliminarlos. Cada acción queda en `logs/gestor_<fecha>.log`.

**Parámetros:**

| Parámetro | Descripción |
|---|---|
| `--dias N` | Cambia el umbral de antigüedad (por defecto 7) |
| `--auto` | Modo desatendido, sin preguntas |

**Ejemplo real de ejecución:**
```
======================================================
        GESTOR DE ARCHIVOS Y PERMISOS
======================================================
  Días límite:           7
  Modo automático:       false
  Log:                   .../logs/gestor_20260706.log
======================================================
  PASO 1: Preparando directorios de trabajo
[...] [INFO] Ya existe: .../archivos_trabajo/temporales
[...] [INFO] Ya existe: .../archivos_trabajo/respaldo

  PASO 2: Creando archivos de prueba
[...] [OK] Creado (reciente): proceso_activo_1.tmp
[...] [OK] Creado (10 días atrás): basura_1.tmp y app_1.log

  PASO 3: Copiando al directorio de respaldo
[...] [OK] Copia exitosa (intento 1/3)

  PASO 4: Configurando permisos de archivos
[...] [OK] Permisos asignados (Respaldo protegido en modo lectura 444).

  PASO 5: Limpieza de archivos temporales
  Archivo: basura_2.tmp
  Ruta   : .../archivos_trabajo/temporales/basura_2.tmp
    ¿Eliminar este archivo? (s/n):
```

---

### `03_automatizacion.sh` — Consola AWK + SED + CRON

**Problema que resuelve:** revisar disco, dar formato a reportes y programar tareas repetitivas exige recordar varios comandos distintos cada vez; este script los reúne en un solo menú.

| Opción | Qué hace realmente |
|---|---|
| 1 | Espacio en disco en una línea (`df -h / \| tail -n 1 \| awk ...`) |
| 2 | Verifica si un archivo existe y muestra su tamaño (`du -h`) |
| 3 | Genera un reporte con `awk`, alineado en columnas fijas, excluyendo `tmpfs`/`devtmpfs`/`overlay` |
| 4 | Busca y reemplaza texto con `sed -i` sobre un archivo (el que tú indiques o el de la opción 3) y agrega un encabezado de auditoría con fecha |
| 5 | Programa `01_sistema_info.sh` en `crontab`, repitiéndolo cada N minutos o cada N horas (tú eliges el intervalo) |
| 0 | Salir |

**Ejemplo real de ejecución (Opción 1):**
```
--- ESPACIO EN DISCO ---
Total: 9,8G | Usado: 3,1G | Disp: 6,3G (33%)
```

> Nota: la Opción 3 no genera CSV ni resalta particiones automáticamente, y la Opción 5 no tiene un modo de "hora fija" (por ejemplo, todos los días a las 8 a. m.) — solo intervalos repetitivos. Ver "Posibles Mejoras" si quieres agregar eso.

---

## Lógica Aplicada

| Elemento | Uso en el proyecto |
|---|---|
| Variables | Rutas, umbrales, contadores de reintentos, datos del sistema |
| Condicionales (`if`/`elif`) | Evaluar uso del disco, verificar existencia de archivos, validar argumentos |
| Bucles (`for`, `while`) | Recorrer directorios y extensiones, reintentar la copia de respaldo, menú en bucle |
| Funciones | Modularizar cada tarea (mostrar, evaluar, respaldar, registrar) |
| `find` | Buscar archivos por extensión y antigüedad (`-mtime`) |
| `awk` | Formatear columnas y extraer campos de `df`/`free` |
| `sed` | Buscar/reemplazar e insertar encabezados en archivos |
| `crontab` | Programar la ejecución periódica de un script |
| Redirección (`>>`, `2>&1`, `tee -a`) | Guardar salida y errores en reportes y logs |

---

## Problemas Detectados y Soluciones

| Problema | Solución implementada |
|---|---|
| `lsb_release` no está en todas las distros | *Fallback* a `/etc/os-release` |
| La copia al respaldo puede fallar (permisos, disco ocupado) | Reintentos automáticos con contador (hasta 3 veces) |
| La tarea de cron se duplicaría si el script se ejecuta varias veces | Se filtra la crontab existente con `grep -v` antes de reinsertar la tarea |
| Un archivo puede ya no existir cuando el usuario confirma el borrado | `rm -f` evita que el script se detenga por un error de "no existe" |
| El usuario podría ingresar un valor no numérico en `--dias` | Validación con expresión regular `^[0-9]+$` antes de aceptarlo |

---

## Posibles Mejoras

- Resolver `DIR_BASE` en `03_automatizacion.sh` igual que en `01` y `02` (hoy usa rutas relativas sueltas y solo funciona si se ejecuta desde `scripts-shell/`).
- Enviar una alerta por correo cuando el disco supere el umbral crítico (90%).
- Comprimir el respaldo (`tar`/`gzip`) en vez de copiarlo sin comprimir.
- Externalizar `UMBRAL_AVISO`, `UMBRAL_CRITICO` y `DIAS_LIMITE` a un archivo `.conf`.
- Agregar al menú de cron un modo de "hora fija" (ej. todos los días a las 08:00), además de los intervalos actuales.
- Generar también un archivo de prueba `.bak`, ya que hoy esa extensión se filtra en la limpieza pero nunca se crea en la demo.

---

## Evidencias de Prueba

- Creación de estructura y permisos (`mkdir -p`, `chmod +x`, `ls -l`)
- Ejecución completa de `01_sistema_info.sh`
- Ejecución de `02_gestor_archivos.sh` (Pasos 1 a 5, incluyendo el prompt de confirmación)
- Ejecución de `03_automatizacion.sh` (menú y al menos una opción)
- Salida de `crontab -l` tras usar la Opción 5
- Contenido de un reporte `.txt` generado en `reportes/`
