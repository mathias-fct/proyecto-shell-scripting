#!/bin/bash
# ============================================================
#  ejecutar_proyecto.sh
#  Proyecto : Automatización de Administración Linux
#  Alumno   : Mathias Caycho Tarazona / Roberto Escobar Sotelo
#  Fecha    : Junio 2026
#
#  QUE HACE:
#    Ejecuta los tres scripts del proyecto en orden y al
#    final genera un reporte consolidado de toda la sesión,
#    indicando cuáles tuvieron éxito y cuáles fallaron.
#
#  COMO EJECUTAR:
#    chmod +x ejecutar_proyecto.sh
#    ./ejecutar_proyecto.sh
# ============================================================

DIR_BASE=$(dirname "$(realpath "$0")")
DIR_REPORTES="$DIR_BASE/../reportes"
mkdir -p "$DIR_REPORTES"

INICIO=$(date '+%d/%m/%Y %H:%M:%S')
REPORTE_SESION="$DIR_REPORTES/sesion_$(date '+%Y%m%d_%H%M%S').txt"
ERRORES=0

linea() {
    printf '%0.s*' {1..54}
    echo
}

# Ejecuta un script, reporta el resultado y suma errores si falla
ejecutar_script() {
    local nombre="$1"
    local ruta="$2"

    echo ""
    linea
    echo "  >> $nombre"
    linea

    if [ ! -f "$ruta" ]; then
        echo "  [ERROR] No se encontró el script: $ruta"
        ERRORES=$((ERRORES + 1))
        echo "FALLO: $nombre — archivo no encontrado" >> "$REPORTE_SESION"
        return 1
    fi

    bash "$ruta"
    local codigo=$?

    if [ $codigo -eq 0 ]; then
        echo ""
        echo "  [OK] $nombre finalizado sin errores."
        echo "EXITO: $nombre" >> "$REPORTE_SESION"
    else
        echo ""
        echo "  [ERROR] $nombre terminó con código de error: $codigo"
        ERRORES=$((ERRORES + 1))
        echo "FALLO: $nombre — código $codigo" >> "$REPORTE_SESION"
    fi
}

# ---- Cabecera del reporte de sesión ----
{
    echo "======================================================"
    echo "  REPORTE DE SESIÓN — PROYECTO SHELL SCRIPTING"
    echo "======================================================"
    echo "  Inicio   : $INICIO"
    echo "  Usuario  : $(whoami)"
    echo "  Servidor : $(hostname)"
    echo ""
    echo "  RESULTADOS POR SCRIPT:"
    echo "------------------------------------------------------"
} > "$REPORTE_SESION"

# ---- Ejecutar los tres scripts en orden ----
ejecutar_script "Script 1: Información del sistema"     "$DIR_BASE/01_sistema_info.sh"
ejecutar_script "Script 2: Gestor de archivos"          "$DIR_BASE/02_gestor_archivos.sh"
ejecutar_script "Script 3: Automatización cron/awk/sed" "$DIR_BASE/03_automatizacion.sh"

# ---- Cerrar el reporte de sesión ----
FIN=$(date '+%d/%m/%Y %H:%M:%S')
{
    echo "------------------------------------------------------"
    echo "  Fin      : $FIN"
    echo "  Errores  : $ERRORES de 3 scripts"
    if [ $ERRORES -eq 0 ]; then
        echo "  Estado   : TODOS EXITOSOS"
    else
        echo "  Estado   : COMPLETADO CON ERRORES"
    fi
    echo "======================================================"
} >> "$REPORTE_SESION"

# ---- Resumen en pantalla ----
echo ""
linea
echo "  SESIÓN COMPLETADA"
printf "  %-20s %d\n" "Scripts ejecutados:" 3
printf "  %-20s %d\n" "Errores:"            "$ERRORES"
echo "  Reporte de sesión: $REPORTE_SESION"
linea

exit $ERRORES
