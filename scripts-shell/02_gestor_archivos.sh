#!/bin/bash
# ============================================================
#  SCRIPT 2 - gestor_archivos.sh
#  Proyecto : Automatización de Administración Linux
#  Materia  : Shell Scripting
#  Alumno   : Mathias Caycho Tarazona / Roberto Escobar Sotelo
#  Fecha    : Junio 2026
#
#  QUE HACE:
#    Crea una estructura de directorios, genera archivos de
#    prueba (.tmp, .log), los copia al respaldo, cambia los
#    permisos y luego limpia los que son más antiguos que
#    los días indicados. Incluye reintentos automáticos si
#    una operación falla.
#
#  COMO EJECUTAR:
#    chmod +x 02_gestor_archivos.sh
#    ./02_gestor_archivos.sh              # pide confirmación
#    ./02_gestor_archivos.sh --dias 5     # eliminar archivos +5 días
#    ./02_gestor_archivos.sh --auto       # sin confirmaciones
# ============================================================

# ---- Configuración general ----
DIR_BASE=$(dirname "$(realpath "$0")")
DIR_TRABAJO="$DIR_BASE/../archivos_trabajo"
DIR_TEMPORALES="$DIR_TRABAJO/temporales"
DIR_RESPALDO="$DIR_TRABAJO/respaldo"
DIR_LOGS="$DIR_BASE/../logs"
ARCHIVO_LOG="$DIR_LOGS/gestor_$(date '+%Y%m%d').log"

DIAS_LIMITE=7         # por defecto eliminar archivos con más de 7 días
MAX_REINTENTOS=3      # máximo de intentos si falla una operación
MODO_AUTO=false       # en false, pide confirmación al usuario

# Extensiones de archivos temporales que se limpian
EXTENSIONES=("*.tmp" "*.log" "*.bak" "*.temp")

# =============================================================
#  FUNCIONES DE UTILIDAD
# =============================================================

# Registra cada acción en el archivo de log con timestamp
registrar() {
    local nivel="$1"
    local mensaje="$2"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$ts] [$nivel] $mensaje" | tee -a "$ARCHIVO_LOG"
}

linea() {
    printf '%0.s-' {1..54}
    echo
}

# Pide confirmación al usuario (si estamos en modo manual)
confirmar() {
    if [ "$MODO_AUTO" = true ]; then
        return 0   # en modo automático siempre acepta
    fi
    local pregunta="$1"
    local respuesta
    read -rp "    $pregunta (s/n): " respuesta
    [[ "$respuesta" =~ ^[sS]$ ]]
}

# Lee y valida los parámetros que se pasan al script
procesar_argumentos() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dias)
                # Validar que el valor sea un número entero positivo
                if [[ "$2" =~ ^[0-9]+$ ]] && [ "$2" -gt 0 ]; then
                    DIAS_LIMITE="$2"
                    shift 2
                else
                    echo "[ERROR] El valor de --dias debe ser un número entero positivo."
                    exit 1
                fi
                ;;
            --auto)
                MODO_AUTO=true
                shift
                ;;
            *)
                echo "[AVISO] Argumento no reconocido: '$1' (se omite)"
                shift
                ;;
        esac
    done
}

# =============================================================
#  MÓDULO 1 — CREAR ESTRUCTURA DE DIRECTORIOS
# =============================================================
crear_estructura() {
    echo ""
    echo "======================================================"
    echo "  PASO 1: Preparando directorios de trabajo"
    echo "======================================================"

    # IMPORTANTE: $DIR_LOGS va primero, porque registrar() necesita
    # que la carpeta de logs ya exista para poder escribir ahí.
    local dirs=("$DIR_LOGS" "$DIR_TRABAJO" "$DIR_TEMPORALES" "$DIR_RESPALDO")

    for dir in "${dirs[@]}"; do
        if [ -d "$dir" ]; then
            registrar "INFO" "El directorio ya existe: $dir"
        else
            if mkdir -p "$dir"; then
                registrar "OK" "Directorio creado: $dir"
            else
                registrar "ERROR" "No se pudo crear: $dir"
                echo "[ERROR] Fallo al crear: $dir — Verifica permisos."
                exit 1
            fi
        fi
    done

    echo "  Estructura de directorios lista."
}

# =============================================================
#  MÓDULO 2 — CREAR ARCHIVOS DE PRUEBA
# =============================================================
crear_archivos_prueba() {
    echo ""
    echo "======================================================"
    echo "  PASO 2: Creando archivos de prueba"
    echo "======================================================"

    # Archivos .tmp recientes (simulan procesos activos)
    for i in {1..3}; do
        local arch="$DIR_TEMPORALES/proceso_activo_$i.tmp"
        echo "Proceso $i — $(date)" > "$arch"
        registrar "OK" "Creado (reciente): proceso_activo_$i.tmp"
    done

    # Archivos .tmp y .log "viejos" backdateados (simulan archivos a limpiar)
    for i in {1..3}; do
        local arch_tmp="$DIR_TEMPORALES/basura_$i.tmp"
        local arch_log="$DIR_TEMPORALES/app_$i.log"
        echo "Archivo temporal antiguo $i" > "$arch_tmp"
        echo "Log de sistema antiguo $i"   > "$arch_log"
        # Backdatear 10 días atrás para que la limpieza pueda eliminarlos
        touch -d "10 days ago" "$arch_tmp" "$arch_log" 2>/dev/null || \
            touch -t $(date -d "10 days ago" '+%Y%m%d%H%M' 2>/dev/null || date '+%Y%m%d%H%M') \
            "$arch_tmp" "$arch_log" 2>/dev/null
        registrar "OK" "Creado (10 días atrás): basura_$i.tmp y app_$i.log"
    done

    echo "  Archivos de prueba listos en: $DIR_TEMPORALES"
    echo "  (3 recientes + 3 .tmp y 3 .log con 10 días de antigüedad)"
}

# =============================================================
#  MÓDULO 3 — COPIAR ARCHIVOS AL RESPALDO
# =============================================================
copiar_respaldo() {
    echo ""
    echo "======================================================"
    echo "  PASO 3: Copiando archivos al directorio de respaldo"
    echo "======================================================"

    # Verificar que hay archivos que copiar
    if [ -z "$(ls -A "$DIR_TEMPORALES" 2>/dev/null)" ]; then
        registrar "AVISO" "No hay archivos en temporales para respaldar."
        echo "  [AVISO] No se encontraron archivos para copiar."
        return 0
    fi

    local intentos=0
    local exito=false

    while [ $intentos -lt $MAX_REINTENTOS ] && [ "$exito" = false ]; do
        intentos=$((intentos + 1))

        if cp -r "$DIR_TEMPORALES"/. "$DIR_RESPALDO/" 2>/dev/null; then
            exito=true
            registrar "OK" "Archivos copiados a respaldo (intento $intentos/$MAX_REINTENTOS)"
            echo "  [OK] Copia completada en el intento $intentos de $MAX_REINTENTOS."
        else
            registrar "ERROR" "Falló la copia — intento $intentos/$MAX_REINTENTOS"
            echo "  [REINTENTO] Intento $intentos/$MAX_REINTENTOS falló. Reintentando..."
            sleep 1
        fi
    done

    if [ "$exito" = false ]; then
        registrar "ERROR" "Copia fallida tras $MAX_REINTENTOS intentos."
        echo "  [ERROR] No se pudo completar la copia después de $MAX_REINTENTOS intentos."
    fi
}

# =============================================================
#  MÓDULO 4 — CAMBIAR PERMISOS
# =============================================================
gestionar_permisos() {
    echo ""
    echo "======================================================"
    echo "  PASO 4: Configurando permisos de archivos"
    echo "======================================================"

    # Verificar que el directorio de respaldo existe y tiene archivos
    if [ ! -d "$DIR_RESPALDO" ]; then
        echo "  [ERROR] No existe el directorio de respaldo."
        registrar "ERROR" "Respaldo no encontrado al intentar cambiar permisos."
        return 1
    fi

    # 444 en respaldo = solo lectura (nadie puede borrar accidentalmente el backup)
    # OJO: usamos find para aplicar 444 solo a los ARCHIVOS, no a la carpeta.
    # Si se hace "chmod -R 444" directo sobre la carpeta, se quita su propio
    # permiso de ejecución a mitad de camino y ya no puede entrar a cambiar
    # los archivos que están adentro (queda todo en "Permission denied").
    if find "$DIR_RESPALDO" -type f -exec chmod 444 {} \; 2>/dev/null; then
        registrar "OK" "Permisos 444 (solo lectura) aplicados en respaldo"
        echo "  [OK] Respaldo protegido con permisos 444 (solo lectura)"
    else
        registrar "AVISO" "Sin archivos en respaldo para aplicar permisos."
        echo "  [AVISO] No hay archivos en respaldo."
    fi

    # 644 en temporales = dueño lee/escribe, resto solo lee
    if chmod 644 "$DIR_TEMPORALES"/* 2>/dev/null; then
        registrar "OK" "Permisos 644 aplicados a archivos temporales"
        echo "  [OK] Permisos 644 aplicados a archivos temporales"
    fi

    # Los directorios necesitan permiso de ejecución para poder entrar (755)
    chmod 755 "$DIR_TRABAJO" "$DIR_TEMPORALES" "$DIR_RESPALDO" 2>/dev/null
    registrar "OK" "Permisos 755 aplicados a directorios de trabajo"
    echo "  [OK] Directorios configurados con permisos 755"
    echo ""
    echo "  Lista de archivos en temporales:"
    ls -lh "$DIR_TEMPORALES"/ 2>/dev/null | head -12
}

# =============================================================
#  MÓDULO 5 — LIMPIAR ARCHIVOS TEMPORALES POR ANTIGÜEDAD
# =============================================================
limpiar_temporales() {
    echo ""
    echo "======================================================"
    echo "  PASO 5: Limpieza de archivos temporales"
    echo "======================================================"
    echo "  Criterio   : archivos con más de $DIAS_LIMITE día(s) de antigüedad"
    echo "  Extensiones: ${EXTENSIONES[*]}"
    echo "  Directorio : $DIR_TEMPORALES"
    linea

    # Validar que el directorio existe antes de actuar
    if [ ! -d "$DIR_TEMPORALES" ]; then
        echo "  [ERROR] No existe el directorio: $DIR_TEMPORALES"
        registrar "ERROR" "Directorio temporal no encontrado."
        return 1
    fi

    local total_encontrados=0
    local total_eliminados=0
    local total_conservados=0

    for ext in "${EXTENSIONES[@]}"; do
        while IFS= read -r -d '' archivo; do
            total_encontrados=$((total_encontrados + 1))
            local nombre
            nombre=$(basename "$archivo")

            echo ""
            echo "  Archivo: $nombre"
            echo "  Ruta   : $archivo"

            if confirmar "  ¿Eliminar este archivo?"; then
                local intentos=0
                local borrado=false

                while [ $intentos -lt $MAX_REINTENTOS ] && [ "$borrado" = false ]; do
                    intentos=$((intentos + 1))

                    if rm -f "$archivo" 2>/dev/null; then
                        borrado=true
                        total_eliminados=$((total_eliminados + 1))
                        registrar "ELIMINADO" "$archivo"
                        echo "    --> [OK] Eliminado (intento $intentos)"
                    else
                        registrar "ERROR" "No se pudo eliminar: $archivo (intento $intentos)"
                        echo "    --> [REINTENTO] Intento $intentos/$MAX_REINTENTOS..."
                        sleep 0.5
                    fi
                done

                if [ "$borrado" = false ]; then
                    total_conservados=$((total_conservados + 1))
                    echo "    --> [ERROR] No se pudo eliminar tras $MAX_REINTENTOS intentos."
                fi
            else
                total_conservados=$((total_conservados + 1))
                registrar "CONSERVADO" "$archivo"
                echo "    --> [CONSERVADO] Mantenido por decisión del usuario."
            fi

        done < <(find "$DIR_TEMPORALES" -name "$ext" -mtime +"$DIAS_LIMITE" -type f -print0 2>/dev/null)
    done

    echo ""
    linea
    echo "  RESUMEN DE LIMPIEZA:"
    printf "  %-30s %d\n" "Archivos encontrados:"   "$total_encontrados"
    printf "  %-30s %d\n" "Archivos eliminados:"    "$total_eliminados"
    printf "  %-30s %d\n" "Archivos conservados:"   "$total_conservados"
    linea
    registrar "RESUMEN" "Encontrados=$total_encontrados | Eliminados=$total_eliminados | Conservados=$total_conservados"
}

# =============================================================
#  EJECUCIÓN PRINCIPAL
# =============================================================
procesar_argumentos "$@"

echo "======================================================"
echo "        GESTOR DE ARCHIVOS Y PERMISOS"
echo "======================================================"
printf "  %-22s %s\n" "Días límite:"       "$DIAS_LIMITE"
printf "  %-22s %s\n" "Modo automático:"   "$MODO_AUTO"
printf "  %-22s %s\n" "Log:"               "$ARCHIVO_LOG"
echo "======================================================"

crear_estructura
crear_archivos_prueba
copiar_respaldo
gestionar_permisos
limpiar_temporales

echo ""
echo "======================================================"
echo "  [FIN] Gestión completada."
echo "  Revisa el log en: $ARCHIVO_LOG"
echo "======================================================"

exit 0
