#!/bin/bash
# ============================================================
#  SCRIPT 1 - sistema_info.sh
#  Proyecto : Automatización de Administración Linux
#  Materia  : Shell Scripting
#  Alumno   : Mathias Caycho Tarazona / Roberto Escobar Sotelo
#  Fecha    : Junio 2026
#
#  QUE HACE:
#    Muestra información básica del servidor: usuario actual,
#    versión del SO, kernel, espacio en disco y memoria libre.
#    Si el disco supera un límite, lanza una alerta.
#    Guarda un reporte en texto con todo lo que encontró.
#
#  COMO EJECUTAR:
#    chmod +x 01_sistema_info.sh
#    ./01_sistema_info.sh
# ============================================================

# ---- Configuración de umbrales de disco (en %) ----
UMBRAL_AVISO=75
UMBRAL_CRITICO=90

# ---- Rutas de salida ----
DIR_BASE=$(dirname "$(realpath "$0")")
DIR_REPORTES="$DIR_BASE/../reportes"
ARCHIVO_REPORTE="$DIR_REPORTES/sistema_$(date '+%Y%m%d_%H%M%S').txt"

# ---- Recolección de datos del sistema ----
FECHA=$(date '+%d/%m/%Y')
HORA=$(date '+%H:%M:%S')
USUARIO=$(whoami)
HOSTNAME_MAQUINA=$(hostname)

# Sistema operativo: intenta lsb_release, si no existe usa /etc/os-release
if command -v lsb_release &>/dev/null; then
    VERSION_SO=$(lsb_release -d | cut -f2)
else
    VERSION_SO=$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d'"' -f2 || echo "No disponible")
fi

KERNEL=$(uname -r)
ARQUITECTURA=$(uname -m)

# Datos del disco en la partición raíz
DISCO_TOTAL=$(df -h /   | awk 'NR==2 {print $2}')
DISCO_USADO=$(df -h /   | awk 'NR==2 {print $3}')
DISCO_LIBRE=$(df -h /   | awk 'NR==2 {print $4}')
DISCO_PCT=$(df -h /     | awk 'NR==2 {print $5}')
DISCO_PCT_NUM=$(df /    | awk 'NR==2 {gsub(/%/,""); print $5}')

# Datos de memoria RAM
MEM_TOTAL=$(free -h | awk '/^Mem:/ {print $2}')
MEM_USADA=$(free -h | awk '/^Mem:/ {print $3}')
MEM_LIBRE=$(free -h | awk '/^Mem:/ {print $4}')

# Variable de estado que se llena más adelante
ESTADO_DISCO="DESCONOCIDO"

# =============================================================
#  FUNCIONES
# =============================================================

# Verifica que los comandos necesarios existan en el sistema
verificar_herramientas() {
    local herramientas=("df" "free" "hostname" "date" "uname" "awk")
    for herramienta in "${herramientas[@]}"; do
        if ! command -v "$herramienta" &>/dev/null; then
            echo "[ERROR] No se encontró el comando: '$herramienta'"
            echo "        Instálalo con: sudo apt install -y coreutils"
            exit 1
        fi
    done
}

# Crea el directorio de reportes si no existe
preparar_entorno() {
    if [ ! -d "$DIR_REPORTES" ]; then
        mkdir -p "$DIR_REPORTES"
        echo "[INFO] Directorio de reportes creado: $DIR_REPORTES"
    fi
}

# Dibuja una línea decorativa
linea() {
    printf '%0.s-' {1..54}
    echo
}

# Muestra toda la información en pantalla con formato ordenado
mostrar_informacion() {
    clear
    echo "======================================================"
    echo "         REPORTE DEL ESTADO DEL SERVIDOR"
    echo "======================================================"
    printf "  %-22s %s\n" "Fecha:"             "$FECHA"
    printf "  %-22s %s\n" "Hora:"              "$HORA"
    printf "  %-22s %s\n" "Usuario actual:"    "$USUARIO"
    printf "  %-22s %s\n" "Nombre del server:" "$HOSTNAME_MAQUINA"
    linea
    printf "  %-22s %s\n" "Sistema operativo:" "$VERSION_SO"
    printf "  %-22s %s\n" "Versión del kernel:" "$KERNEL"
    printf "  %-22s %s\n" "Arquitectura:"      "$ARQUITECTURA"
    linea
    printf "  %-22s %s\n" "Disco total:"       "$DISCO_TOTAL"
    printf "  %-22s %s\n" "Disco usado:"       "$DISCO_USADO  ($DISCO_PCT)"
    printf "  %-22s %s\n" "Disco libre:"       "$DISCO_LIBRE"
    linea
    printf "  %-22s %s\n" "RAM total:"         "$MEM_TOTAL"
    printf "  %-22s %s\n" "RAM usada:"         "$MEM_USADA"
    printf "  %-22s %s\n" "RAM libre:"         "$MEM_LIBRE"
    echo "======================================================"
}

# Evalúa el estado del disco y avisa si está en zona de peligro
evaluar_disco() {
    echo ""
    echo "  ANÁLISIS DE ESPACIO EN DISCO"
    linea

    # Verificar que el valor sea numérico antes de comparar
    if ! [[ "$DISCO_PCT_NUM" =~ ^[0-9]+$ ]]; then
        echo "  [ERROR] No se pudo leer el porcentaje de uso del disco."
        ESTADO_DISCO="ERROR_LECTURA"
        return 1
    fi

    if [ "$DISCO_PCT_NUM" -ge "$UMBRAL_CRITICO" ]; then
        ESTADO_DISCO="CRITICO"
        echo "  [!! CRITICO !!] Disco al ${DISCO_PCT_NUM}%  — Requiere intervención inmediata."
    elif [ "$DISCO_PCT_NUM" -ge "$UMBRAL_AVISO" ]; then
        ESTADO_DISCO="AVISO"
        echo "  [AVISO] Disco al ${DISCO_PCT_NUM}% — Se recomienda liberar espacio pronto."
    else
        ESTADO_DISCO="NORMAL"
        echo "  [OK] Disco al ${DISCO_PCT_NUM}% — Operando con normalidad."
    fi

    echo "  (Umbral de aviso: ${UMBRAL_AVISO}% | Umbral crítico: ${UMBRAL_CRITICO}%)"
    linea
}

# Guarda el resumen en un archivo de texto plano
guardar_reporte() {
    {
        echo "REPORTE DEL SERVIDOR — $FECHA $HORA"
        echo "Generado por : $USUARIO"
        echo "Servidor     : $HOSTNAME_MAQUINA"
        echo ""
        echo "[SISTEMA]"
        echo "  Sistema   : $VERSION_SO"
        echo "  Kernel    : $KERNEL"
        echo "  Arq.      : $ARQUITECTURA"
        echo ""
        echo "[DISCO /]"
        echo "  Total     : $DISCO_TOTAL"
        echo "  Usado     : $DISCO_USADO  ($DISCO_PCT)"
        echo "  Libre     : $DISCO_LIBRE"
        echo "  Estado    : $ESTADO_DISCO"
        echo "  Umbral    : Aviso=${UMBRAL_AVISO}% | Critico=${UMBRAL_CRITICO}%"
        echo ""
        echo "[MEMORIA RAM]"
        echo "  Total     : $MEM_TOTAL"
        echo "  Usada     : $MEM_USADA"
        echo "  Libre     : $MEM_LIBRE"
    } > "$ARCHIVO_REPORTE"

    echo ""
    echo "  [OK] Reporte guardado en: $ARCHIVO_REPORTE"
    echo ""
}

# =============================================================
#  EJECUCIÓN PRINCIPAL
# =============================================================
verificar_herramientas
preparar_entorno
mostrar_informacion
evaluar_disco
guardar_reporte

exit 0
