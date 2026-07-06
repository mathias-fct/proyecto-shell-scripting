#!/bin/bash
# 02_gestor_archivos.sh — Gestión de archivos y permisos
# Alumno : Mathias Caycho Tarazona / Roberto Escobar Sotelo
# Grupo  : GRUPO 4 | IDAT 2026

DIR_BASE=$(dirname "$(realpath "$0")")
DIR_TRABAJO="$DIR_BASE/../archivos_trabajo"
DIR_TEMPORALES="$DIR_TRABAJO/temporales"
DIR_RESPALDO="$DIR_TRABAJO/respaldo"
DIR_LOGS="$DIR_BASE/../logs"
ARCHIVO_LOG="$DIR_LOGS/gestor_$(date '+%Y%m%d').log"

DIAS_LIMITE=7
MAX_REINTENTOS=3
MODO_AUTO=false
EXTENSIONES=("*.tmp" "*.log" "*.bak")

linea() { printf '%0.s-' {1..54}; echo; }

registrar() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$1] $2" | tee -a "$ARCHIVO_LOG"
}

confirmar() {
    [ "$MODO_AUTO" = true ] && return 0
    local r
    read -rp "    $1 (s/n): " r
    [[ "$r" =~ ^[sS]$ ]]
}

procesar_argumentos() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dias)
                if [[ "$2" =~ ^[0-9]+$ ]] && [ "$2" -gt 0 ]; then
                    DIAS_LIMITE="$2"; shift 2
                else
                    echo "[ERROR] --dias necesita un número entero positivo."; exit 1
                fi ;;
            --auto) MODO_AUTO=true; shift ;;
            *) echo "[AVISO] Argumento no reconocido: $1"; shift ;;
        esac
    done
}

crear_estructura() {
    echo "======================================================"
    echo "  PASO 1: Preparando directorios de trabajo"
    echo "======================================================"
    for dir in "$DIR_LOGS" "$DIR_TRABAJO" "$DIR_TEMPORALES" "$DIR_RESPALDO"; do
        if [ -d "$dir" ]; then
            registrar "INFO" "Ya existe: $dir"
        else
            mkdir -p "$dir" && registrar "OK" "Creado: $dir"
        fi
    done
}

crear_archivos_prueba() {
    echo "======================================================"
    echo "  PASO 2: Creando archivos de prueba"
    echo "======================================================"
    for i in {1..3}; do
        echo "Proceso $i — $(date)" > "$DIR_TEMPORALES/proceso_activo_$i.tmp"
        registrar "OK" "Creado (reciente): proceso_activo_$i.tmp"
    done
    for i in {1..3}; do
        echo "Archivo antiguo $i" > "$DIR_TEMPORALES/basura_$i.tmp"
        echo "Log antiguo $i"     > "$DIR_TEMPORALES/app_$i.log"
        touch -d "10 days ago" "$DIR_TEMPORALES/basura_$i.tmp" "$DIR_TEMPORALES/app_$i.log" 2>/dev/null
        registrar "OK" "Creado (10 días atrás): basura_$i.tmp y app_$i.log"
    done
}

copiar_respaldo() {
    echo "======================================================"
    echo "  PASO 3: Copiando al directorio de respaldo"
    echo "======================================================"
    # SOLUCIÓN: Si ya existían archivos 444 previos, les devolvemos permiso temporal para que se dejen sobrescribir
    [ -d "$DIR_RESPALDO" ] && chmod -R 755 "$DIR_RESPALDO" 2>/dev/null

    local intentos=0 exito=false
    while [ $intentos -lt $MAX_REINTENTOS ] && [ "$exito" = false ]; do
        intentos=$((intentos + 1))
        if cp -r "$DIR_TEMPORALES"/. "$DIR_RESPALDO/" 2>/dev/null; then
            exito=true
            registrar "OK" "Copia exitosa (intento $intentos/$MAX_REINTENTOS)"
            echo "  [OK] Copia completada."
        else
            echo "  [REINTENTO] Intento $intentos/$MAX_REINTENTOS..."
            sleep 1
        fi
    done
    [ "$exito" = false ] && registrar "ERROR" "Copia fallida."
}

gestionar_permisos() {
    echo "======================================================"
    echo "  PASO 4: Configurando permisos de archivos"
    echo "======================================================"
    chmod 755 "$DIR_TRABAJO" "$DIR_TEMPORALES" "$DIR_RESPALDO" 2>/dev/null
    chmod 644 "$DIR_TEMPORALES"/* 2>/dev/null
    find "$DIR_RESPALDO" -type f -exec chmod 444 {} \; 2>/dev/null
    registrar "OK" "Permisos aplicados correctamente estructurados."
    echo "  [OK] Permisos asignados (Respaldo protegido en modo lectura 444)."
}

limpiar_temporales() {
    echo "======================================================"
    echo "  PASO 5: Limpieza de archivos temporales"
    echo "======================================================"
    local encontrados=0 eliminados=0 conservados=0

    # SOLUCIÓN: Guardamos la lista en un array para no romper el 'read' interactivo posterior
    local lista_archivos=()
    for ext in "${EXTENSIONES[@]}"; do
        while IFS= read -r -d '' arch; do
            lista_archivos+=("$arch")
        done < <(find "$DIR_TEMPORALES" -name "$ext" -mtime +"$DIAS_LIMITE" -type f -print0 2>/dev/null)
    done

    encontrados=${#lista_archivos[@]}

    for archivo in "${lista_archivos[@]}"; do
        linea
        echo "  Archivo: $(basename "$archivo")"
        echo "  Ruta   : $archivo"

        if confirmar "¿Eliminar este archivo?"; then
            if rm -f "$archivo" 2>/dev/null; then
                eliminados=$((eliminados + 1))
                registrar "ELIMINADO" "$archivo"
                echo "    --> [OK] Eliminado exitosamente."
            else
                echo "    --> [ERROR] No se pudo eliminar."
                conservados=$((conservados + 1))
            fi
        else
            conservados=$((conservados + 1))
            registrar "CONSERVADO" "$archivo"
            echo "    --> [CONSERVADO] Mantenido por el usuario."
        fi
    done

    echo ""
    linea
    echo "  RESUMEN DE LIMPIEZA:"
    printf "  %-30s %d\n" "Archivos encontrados:" "$encontrados"
    printf "  %-30s %d\n" "Archivos eliminados:"  "$eliminados"
    printf "  %-30s %d\n" "Archivos conservados:" "$conservados"
    linea
    registrar "RESUMEN" "Encontrados=$encontrados | Eliminados=$eliminados | Conservados=$conservados"
}

procesar_argumentos "$@"

echo "======================================================"
echo "        GESTOR DE ARCHIVOS Y PERMISOS"
echo "======================================================"
printf "  %-22s %s\n" "Días límite:"     "$DIAS_LIMITE"
printf "  %-22s %s\n" "Modo automático:" "$MODO_AUTO"
printf "  %-22s %s\n" "Log:"             "$ARCHIVO_LOG"
echo "======================================================"

crear_estructura
crear_archivos_prueba
copiar_respaldo
gestionar_permisos
limpiar_temporales

DIR_REPORTES="$DIR_BASE/../reportes"
mkdir -p "$DIR_REPORTES"

while true; do
    echo ""
    echo "======================================================"
    echo "           REPORTE DE ACCIONES DEL GESTOR"
    echo "======================================================"
    echo "1) Mostrar solo archivos ELIMINADOS (Con fecha y hora)"
    echo "2) Mostrar solo archivos CONSERVADOS"
    echo "3) Ver Bitácora Completa (Log)"
    echo "4) Salir del Gestor"
    echo "------------------------------------------------------"
    read -rp "Ingrese su opción (1-4): " opcion_menu

    TIMESTAMP=$(date '+%H%M%S')
    echo ""
    case "$opcion_menu" in
        1)
            ARCHIVO_REPORTE="$DIR_REPORTES/reporte_eliminados_${TIMESTAMP}.txt"
            echo "=== REPORTE DE ARCHIVOS ELIMINADOS ===" > "$ARCHIVO_REPORTE"
            echo "Generado el: $(date '+%Y-%m-%d %H:%M:%S')" >> "$ARCHIVO_REPORTE"
            printf "%-12s %-10s %-30s\n" "FECHA" "HORA" "RUTA DEL ARCHIVO" >> "$ARCHIVO_REPORTE"
            echo "------------------------------------------------------" >> "$ARCHIVO_REPORTE"

            # SOLUCIÓN: Usamos grep -F para buscar la cadena exacta sin problemas de caracteres
            grep -F "[ELIMINADO]" "$ARCHIVO_LOG" | awk '{printf "%-12s %-10s %-30s\n", substr($1,2), substr($2,1,8), $4}' >> "$ARCHIVO_REPORTE"

            cat "$ARCHIVO_REPORTE"
            echo -e "\n[INFO] Reporte guardado en: $ARCHIVO_REPORTE"
            read -rp "Presione ENTER para volver..."
            ;;
        2)
            ARCHIVO_REPORTE="$DIR_REPORTES/reporte_conservados_${TIMESTAMP}.txt"
            echo "=== REPORTE DE ARCHIVOS CONSERVADOS ===" > "$ARCHIVO_REPORTE"
            echo "Generado el: $(date '+%Y-%m-%d %H:%M:%S')" >> "$ARCHIVO_REPORTE"
            printf "%-12s %-10s %-30s\n" "FECHA" "HORA" "RUTA DEL ARCHIVO" >> "$ARCHIVO_REPORTE"
            echo "------------------------------------------------------" >> "$ARCHIVO_REPORTE"

            # SOLUCIÓN: grep -F evita fallos con corchetes
            grep -F "[CONSERVADO]" "$ARCHIVO_LOG" | awk '{printf "%-12s %-10s %-30s\n", substr($1,2), substr($2,1,8), $4}' >> "$ARCHIVO_REPORTE"

            cat "$ARCHIVO_REPORTE"
            echo -e "\n[INFO] Reporte guardado en: $ARCHIVO_REPORTE"
            read -rp "Presione ENTER para volver..."
            ;;
        3)
            ARCHIVO_REPORTE="$DIR_REPORTES/copia_bitacora_${TIMESTAMP}.txt"
            echo "=== COPIA DE BITÁCORA COMPLETA ===" > "$ARCHIVO_REPORTE"
            cat "$ARCHIVO_LOG" >> "$ARCHIVO_REPORTE"
            cat "$ARCHIVO_REPORTE"
            echo -e "\n[INFO] Log completo guardado en: $ARCHIVO_REPORTE"
            read -rp "Presione ENTER para volver..."
            ;;
        4)
            echo "Saliendo del gestor de reportes..."
            break
            ;;
        *)
            echo "[AVISO] Opción inválida."
            sleep 1
            ;;
    esac
done

exit 0
