#!/bin/bash
# Alumno : Mathias Caycho Tarazona / Roberto Escobar Sotelo | GRUPO 4

# Rutas de archivos por defecto
REPORTE_AWK="../reportes/reporte_disco_awk.txt"
REPORTE_SED="../reportes/reporte_disco_final.txt"
SCRIPT_SISTEMA="./01_sistema_info.sh"
mkdir -p ../datos ../reportes ../logs

while true; do
    echo -e "\n======================================================"
    echo "      AUTOMATIZACIÓN INTERACTIVA: AWK + SED + CRON"
    echo "======================================================"
    echo "  1. Verificar espacio en disco"
    echo "  2. Comprobar existencia de un archivo"
    echo "  3. Generar reporte de disco con AWK"
    echo "  4. Aplicar SED de forma interactiva"
    echo "  5. Programar tarea con CRON (Interactivo)"
    echo "  0. Salir"
    echo "------------------------------------------------------"
    read -rp "  Elige una opción: " opcion

    case "$opcion" in
        1)
            echo -e "\n--- ESPACIO EN DISCO ---"
            df -h / | tail -n 1 | awk '{print "Total: " $2 " | Usado: " $3 " | Disp: " $4 " (" $5 ")"}'
            ;;
        2)
            echo -e "\n--- COMPROBAR ARCHIVO ---"
            read -rp "Ingresa la ruta del archivo: " ruta
            if [ -f "$ruta" ]; then
                echo "[OK] El archivo existe. Tamaño: $(du -h "$ruta" | cut -f1)"
            else
                echo "[!!] El archivo NO existe o es un directorio."
            fi
            ;;
        3)
            echo "======================================================" > "$REPORTE_AWK"
            echo "     REPORTE DE USO DE DISCO — Generado con AWK" >> "$REPORTE_AWK"
            echo "======================================================" >> "$REPORTE_AWK"
            echo -e "Particion\t\t\tUsado\tPorcentaje" >> "$REPORTE_AWK"

            # AWK formatea las columnas y las mete al archivo
            df -h -x tmpfs -x devtmpfs -x overlay 2>/dev/null | tail -n +2 | awk '{printf "%-35s %-8s %-6s\n", $1, $3, $5}' >> "$REPORTE_AWK"
            echo "======================================================" >> "$REPORTE_AWK"

            # Mostramos todo el contenido ordenado en pantalla
            cat "$REPORTE_AWK"
            echo "[OK] Reporte guardado en: $REPORTE_AWK"
            ;;
        4)
            echo -e "\n======================================================"
            echo "  OPCIÓN 4: Procesar reporte interactivo con SED"
            echo "======================================================"
            read -rp "  Ruta del archivo a editar [Enter para el de AWK]: " arch
            [ -z "$arch" ] && arch="$REPORTE_AWK"

            if [ ! -f "$arch" ]; then echo "  [ERROR] No existe el archivo"; continue; fi

            read -rp "  Texto a BUSCAR: " buscar
            read -rp "  Texto para REEMPLAZAR: " reemplazar

            # Modificamos el archivo original directamente en caliente
            sed -i "s/$buscar/$reemplazar/g" "$arch"
            sed -i "1s|^|[Auditoría SED realizada el: $(date '+%d/%m/%Y %H:%M:%S')]\n|" "$arch"

            echo -e "\n  Primeras líneas del resultado modificado:"
            echo "------------------------------------------------------"
            head -n 12 "$arch"
            echo "------------------------------------------------------"
            echo "  [OK] Archivo modificado directamente en: $arch"
            ;;
        5)
            echo -e "\n--- PROGRAMAR CRON (INTERACTIVO) ---"
            echo "1. Repetir cada cierta cantidad de MINUTOS"
            echo "2. Repetir cada cierta cantidad de HORAS"
            read -rp "Selecciona modo (1-2): " modo

            if [ "$modo" -eq 1 ]; then
                read -rp "¿Cada cuántos MINUTOS? (1-59): " mins
                expr_cron="*/$mins * * * *"
            elif [ "$modo" -eq 2 ]; then
                read -rp "¿Cada cuántas HORAS? (1-23): " horas
                expr_cron="0 */$horas * * *"
            else
                echo "Opción inválida"; continue
            fi

            TAREA="$expr_cron $(realpath "$SCRIPT_SISTEMA") >> ../logs/cron_sistema.log 2>&1"
            (crontab -l 2>/dev/null | grep -v "$(basename "$SCRIPT_SISTEMA")"; echo "$TAREA") | crontab -
            echo "[OK] Tarea registrada en Crontab:"
            crontab -l | grep "$(basename "$SCRIPT_SISTEMA")"
            ;;
        0)
            echo -e "\n[FIN] Saliendo del script. ¡Hasta luego!"
            exit 0
            ;;
        *)
            echo "Opción inválida."
            ;;
    esac
done
