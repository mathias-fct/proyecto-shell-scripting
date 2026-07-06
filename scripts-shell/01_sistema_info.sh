#!/bin/bash
# 01_sistema_info.sh — Información del servidor
# Alumno : Mathias Caycho Tarazona / Roberto Escobar Sotelo
# Grupo  : GRUPO 4 | IDAT 2026

UMBRAL_AVISO=75
UMBRAL_CRITICO=90

DIR_BASE=$(dirname "$(realpath "$0")")
DIR_REPORTES="$DIR_BASE/../reportes"
ARCHIVO_REPORTE="$DIR_REPORTES/sistema_$(date '+%Y%m%d_%H%M%S').txt"

FECHA=$(date '+%d/%m/%Y')
HORA=$(date '+%H:%M:%S')
USUARIO=$(whoami)
HOSTNAME_MAQUINA=$(hostname)

if command -v lsb_release &>/dev/null; then
    VERSION_SO=$(lsb_release -d | cut -f2)
else
    VERSION_SO=$(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)
fi

KERNEL=$(uname -r)
ARQUITECTURA=$(uname -m)

DISCO_TOTAL=$(df -h /  | awk 'NR==2 {print $2}')
DISCO_USADO=$(df -h /  | awk 'NR==2 {print $3}')
DISCO_LIBRE=$(df -h /  | awk 'NR==2 {print $4}')
DISCO_PCT=$(df -h /    | awk 'NR==2 {print $5}')
DISCO_PCT_NUM=$(df /   | awk 'NR==2 {gsub(/%/,""); print $5}')

MEM_TOTAL=$(free -h | awk '/^Mem:/ {print $2}')
MEM_USADA=$(free -h | awk '/^Mem:/ {print $3}')
MEM_LIBRE=$(free -h | awk '/^Mem:/ {print $4}')

ESTADO_DISCO="DESCONOCIDO"

linea() { printf '%0.s-' {1..54}; echo; }

mostrar_info() {
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
    printf "  %-22s %s\n" "Kernel:"            "$KERNEL"
    printf "  %-22s %s\n" "Arquitectura:"      "$ARQUITECTURA"
    linea
    printf "  %-22s %s\n" "Disco total:"       "$DISCO_TOTAL"
    printf "  %-22s %s\n" "Disco usado:"       "$DISCO_USADO ($DISCO_PCT)"
    printf "  %-22s %s\n" "Disco libre:"       "$DISCO_LIBRE"
    linea
    printf "  %-22s %s\n" "RAM total:"         "$MEM_TOTAL"
    printf "  %-22s %s\n" "RAM usada:"         "$MEM_USADA"
    printf "  %-22s %s\n" "RAM libre:"         "$MEM_LIBRE"
    echo "======================================================"
}

evaluar_disco() {
    echo ""
    echo "  ANÁLISIS DE ESPACIO EN DISCO"
    linea
    if [ "$DISCO_PCT_NUM" -ge "$UMBRAL_CRITICO" ]; then
        ESTADO_DISCO="CRITICO"
        echo "  [!! CRITICO !!] Disco al ${DISCO_PCT_NUM}% — Intervención inmediata."
    elif [ "$DISCO_PCT_NUM" -ge "$UMBRAL_AVISO" ]; then
        ESTADO_DISCO="AVISO"
        echo "  [AVISO] Disco al ${DISCO_PCT_NUM}% — Liberar espacio pronto."
    else
        ESTADO_DISCO="NORMAL"
        echo "  [OK] Disco al ${DISCO_PCT_NUM}% — Operando con normalidad."
    fi
    echo "  (Umbral aviso: ${UMBRAL_AVISO}% | Umbral crítico: ${UMBRAL_CRITICO}%)"
    linea
}

guardar_reporte() {
    mkdir -p "$DIR_REPORTES"
    {
        echo "REPORTE DEL SERVIDOR — $FECHA $HORA"
        echo "Generado por : $USUARIO en $HOSTNAME_MAQUINA"
        echo ""
        echo "[SISTEMA]"
        echo "  SO     : $VERSION_SO"
        echo "  Kernel : $KERNEL"
        echo "  Arq.   : $ARQUITECTURA"
        echo ""
        echo "[DISCO /]"
        echo "  Total  : $DISCO_TOTAL"
        echo "  Usado  : $DISCO_USADO ($DISCO_PCT)"
        echo "  Libre  : $DISCO_LIBRE"
        echo "  Estado : $ESTADO_DISCO"
        echo "  Umbral : Aviso=${UMBRAL_AVISO}% | Critico=${UMBRAL_CRITICO}%"
        echo ""
        echo "[MEMORIA RAM]"
        echo "  Total  : $MEM_TOTAL"
        echo "  Usada  : $MEM_USADA"
        echo "  Libre  : $MEM_LIBRE"
    } > "$ARCHIVO_REPORTE"
    echo ""
    echo "  [OK] Reporte guardado en: $ARCHIVO_REPORTE"
    echo ""
}

mostrar_info
evaluar_disco
guardar_reporte

exit 0
