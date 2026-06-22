#!/bin/bash
# ============================================================
#  SCRIPT 3 - automatizacion.sh
#  Proyecto : Automatización de Administración Linux
#  Materia  : Shell Scripting
#  Alumno   : Mathias Caycho Tarazona / Roberto Escobar Sotelo
#  Fecha    : Junio 2026
#
#  QUE HACE:
#    Tres tareas de automatización con herramientas externas:
#    1. AWK  → captura uso real del disco y genera reporte
#    2. SED  → edita el reporte para resaltar alertas
#    3. CRON → programa ejecución diaria del script de sistema
#
#  COMO EJECUTAR:
#    chmod +x 03_automatizacion.sh
#    ./03_automatizacion.sh
# ============================================================

# ---- Rutas del proyecto ----
DIR_BASE=$(dirname "$(realpath "$0")")
DIR_DATOS="$DIR_BASE/../datos"
DIR_REPORTES="$DIR_BASE/../reportes"
DIR_LOGS="$DIR_BASE/../logs"

ARCHIVO_CSV="$DIR_DATOS/uso_disco.csv"
REPORTE_AWK="$DIR_REPORTES/reporte_disco_awk.txt"
REPORTE_SED="$DIR_REPORTES/reporte_disco_final.txt"
SCRIPT_SISTEMA="$DIR_BASE/01_sistema_info.sh"
LOG_CRON="$DIR_LOGS/cron_sistema.log"

# Umbral para que AWK marque particiones como críticas
UMBRAL_CRITICO_AWK=80

# =============================================================
#  FUNCIONES DE UTILIDAD
# =============================================================

linea_doble() {
    printf '%0.s=' {1..54}
    echo
}

linea_simple() {
    printf '%0.s-' {1..54}
    echo
}

# Verifica herramientas externas antes de empezar
verificar_herramientas() {
    local herramientas=("awk" "sed" "df" "crontab")
    # Mapeo comando -> paquete real de apt (el nombre del comando no
    # siempre coincide con el nombre del paquete que hay que instalar)
    declare -A paquete=( ["awk"]="gawk" ["sed"]="sed" ["df"]="coreutils" ["crontab"]="cron" )
    for h in "${herramientas[@]}"; do
        if ! command -v "$h" &>/dev/null; then
            echo "[ERROR] No se encontró: '$h'"
            echo "        Instala con: sudo apt install -y ${paquete[$h]}"
            exit 1
        fi
    done
}

# Crea los directorios si no existen
preparar_entorno() {
    for dir in "$DIR_DATOS" "$DIR_REPORTES" "$DIR_LOGS"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            echo "[INFO] Directorio creado: $dir"
        fi
    done
}

# =============================================================
#  MÓDULO 1 — CAPTURA DE DATOS DEL DISCO
# =============================================================
capturar_datos_disco() {
    echo ""
    linea_doble
    echo "  MÓDULO 1: Capturando datos del disco (fuente para AWK)"
    linea_doble

    # Encabezado del CSV
    echo "particion,total,usado,disponible,porcentaje,punto_montaje" > "$ARCHIVO_CSV"

    # Leer df -h y convertir a formato CSV (filtrando tmpfs y udev)
    # LC_ALL=C fuerza que los números usen punto decimal (9.8G) en vez de
    # coma (9,8G). Sin esto, en servidores configurados en español la coma
    # del número se confunde con la coma que separa columnas del CSV.
    LC_ALL=C df -h --output=source,size,used,avail,pcent,target 2>/dev/null | \
        tail -n +2 | \
        grep -v "^tmpfs\|^udev\|^none\|^overlay" | \
        while read -r source size used avail pcent target; do
            echo "${source},${size},${used},${avail},${pcent},${target}"
        done >> "$ARCHIVO_CSV"

    local total_particiones
    total_particiones=$(wc -l < "$ARCHIVO_CSV")
    total_particiones=$((total_particiones - 1))   # descontar encabezado

    echo "  [OK] Datos guardados en: $ARCHIVO_CSV"
    echo "  Particiones detectadas : $total_particiones"
    echo ""
    echo "  Vista previa del CSV:"
    linea_simple
    head -6 "$ARCHIVO_CSV" | while IFS= read -r linea_csv; do
        echo "  $linea_csv"
    done
    linea_simple
}

# =============================================================
#  MÓDULO 2 — REPORTE CON AWK
# =============================================================
generar_reporte_awk() {
    echo ""
    linea_doble
    echo "  MÓDULO 2: Generando reporte con AWK"
    linea_doble

    # Verificar que el CSV existe y no está vacío
    if [ ! -f "$ARCHIVO_CSV" ] || [ ! -s "$ARCHIVO_CSV" ]; then
        echo "  [ERROR] No se encontró el archivo de datos: $ARCHIVO_CSV"
        return 1
    fi

    # AWK procesa el CSV y genera un reporte formateado
    awk -F',' -v umbral="$UMBRAL_CRITICO_AWK" '
    BEGIN {
        print "======================================================"
        print "     REPORTE DE USO DE DISCO — Generado con AWK"
        print "======================================================"
        printf "%-22s %-8s %-8s %-8s %-6s\n",
               "Particion", "Total", "Usado", "Libre", "Uso"
        print "------------------------------------------------------"
        count = 0
        alertas = ""
    }

    NR == 1 { next }    # saltar la línea de encabezado del CSV

    NF >= 5 {
        # Limpiar el símbolo % del porcentaje
        pct_num = $5
        gsub(/%/, "", pct_num)

        printf "%-22s %-8s %-8s %-8s %-6s\n", $1, $2, $3, $4, $5
        count++

        # Guardar las particiones que superan el umbral
        if (pct_num + 0 >= umbral) {
            alertas = alertas "    [!!] " $1 " — " $5 " utilizado\n"
        }
    }

    END {
        print "======================================================"
        print "  Particiones analizadas : " count
        print ""
        if (length(alertas) > 0) {
            print "  ALERTA — Particiones que superan el " umbral "%:"
            printf "%s", alertas
        } else {
            print "  ESTADO NORMAL — Ninguna particion supera el " umbral "%"
        }
        print "======================================================"
    }
    ' "$ARCHIVO_CSV" | tee "$REPORTE_AWK"

    echo ""
    echo "  [OK] Reporte AWK guardado en: $REPORTE_AWK"
}

# =============================================================
#  MÓDULO 3 — EDICIÓN CON SED
# =============================================================
aplicar_sed() {
    echo ""
    linea_doble
    echo "  MÓDULO 3: Procesando reporte con SED"
    linea_doble

    # Verificar que existe el reporte que vamos a editar
    if [ ! -f "$REPORTE_AWK" ]; then
        echo "  [ERROR] No existe el reporte de AWK para editar."
        return 1
    fi

    # Copiar el original para no perderlo
    cp "$REPORTE_AWK" "$REPORTE_SED"

    local fecha_proceso
    fecha_proceso=$(date '+%d/%m/%Y %H:%M:%S')

    # Reemplazo 1: resaltar "ALERTA" con delimitadores visibles
    sed -i 's/ALERTA/>>> ALERTA CRÍTICA >>>/g' "$REPORTE_SED"

    # Reemplazo 2: cambiar "[!!]" por texto más descriptivo
    sed -i 's/\[!!\]/[DISCO LLENO]/g' "$REPORTE_SED"

    # Reemplazo 3: expandir "ESTADO NORMAL" con más detalle
    sed -i 's/ESTADO NORMAL/ESTADO NORMAL — Sin intervención requerida/g' "$REPORTE_SED"

    # Reemplazo 4: agregar cabecera con fecha al inicio del archivo
    # (usamos | como delimitador porque la fecha trae '/' y rompería el comando)
    sed -i "1s|^|[Revisado con SED el: $fecha_proceso]\n|" "$REPORTE_SED"

    echo "  Reemplazos aplicados:"
    echo "    1. 'ALERTA'        → '>>> ALERTA CRÍTICA >>>'"
    echo "    2. '[!!]'          → '[DISCO LLENO]'"
    echo "    3. 'ESTADO NORMAL' → texto extendido"
    echo "    4. Cabecera con fecha agregada al inicio"
    echo ""
    echo "  Primeras líneas del reporte editado:"
    linea_simple
    head -8 "$REPORTE_SED" | while IFS= read -r l; do
        echo "  $l"
    done
    linea_simple
    echo ""
    echo "  [OK] Reporte final guardado en: $REPORTE_SED"
}

# =============================================================
#  MÓDULO 4 — PROGRAMAR TAREA CON CRON
# =============================================================
programar_cron() {
    echo ""
    linea_doble
    echo "  MÓDULO 4: Programando tarea con CRON"
    linea_doble

    # Obtener ruta absoluta del script de sistema
    local ruta_script
    if [ -f "$SCRIPT_SISTEMA" ]; then
        ruta_script=$(realpath "$SCRIPT_SISTEMA")
    else
        ruta_script="$SCRIPT_SISTEMA"
        echo "  [AVISO] Script $SCRIPT_SISTEMA no encontrado."
        echo "          La tarea se mostrará igualmente."
    fi

    # Tarea: ejecutar sistema_info.sh todos los días a las 8:00 AM
    local TAREA_CRON="0 8 * * * $ruta_script >> $LOG_CRON 2>&1"

    echo "  Tarea que se programará:"
    echo "  $TAREA_CRON"
    echo ""
    echo "  Significado de '0 8 * * *':"
    echo "    0  → en el minuto 0"
    echo "    8  → a las 8 de la mañana"
    echo "    *  → cualquier día del mes"
    echo "    *  → cualquier mes"
    echo "    *  → cualquier día de la semana"
    echo "    → En resumen: todos los días a las 08:00 AM"
    echo ""
    read -rp "  ¿Agregar esta tarea al cron? (s/n): " respuesta

    if [[ "$respuesta" =~ ^[sS]$ ]]; then

        # Evitar duplicados: si ya existe la tarea, no agregarla de nuevo
        if crontab -l 2>/dev/null | grep -qF "$(basename "$ruta_script")"; then
            echo ""
            echo "  [INFO] La tarea ya estaba en cron — no se duplica."
        else
            # Agregar al crontab sin borrar lo que ya existe
            (crontab -l 2>/dev/null; echo "$TAREA_CRON") | crontab -
            if [ $? -eq 0 ]; then
                echo ""
                echo "  [OK] Tarea registrada exitosamente."
                echo "  Para verla: crontab -l"
                echo "  Para editarla: crontab -e"
                echo "  Para eliminarla: crontab -r"
            else
                echo "  [ERROR] No se pudo agregar la tarea."
            fi
        fi

        echo ""
        echo "  Crontab actual:"
        linea_simple
        crontab -l 2>/dev/null || echo "  (El crontab está vacío)"
        linea_simple

    else
        echo ""
        echo "  [INFO] Tarea no agregada (elegiste no)."
        echo "  Para hacerlo manualmente:"
        echo "    1. Ejecuta: crontab -e"
        echo "    2. Agrega esta línea al final:"
        echo "       $TAREA_CRON"
    fi
}

# =============================================================
#  EJECUCIÓN PRINCIPAL
# =============================================================
verificar_herramientas
preparar_entorno

linea_doble
echo "      AUTOMATIZACIÓN: AWK + SED + CRON"
linea_doble

capturar_datos_disco
generar_reporte_awk
aplicar_sed
programar_cron

echo ""
linea_doble
echo "  [FIN] Automatización completada."
echo "  Reportes en: $DIR_REPORTES"
linea_doble

exit 0
