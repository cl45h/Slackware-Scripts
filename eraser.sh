#!/bin/bash

# Verificar si se está ejecutando como root
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: Este script debe ejecutarse como root."
    exit 1
fi

listar_kernels_instalados_boot() {
    echo "Versiones de kernel instaladas en /boot:"
    local found=0
    for file in /boot/vmlinuz-generic-*; do
        [ -e "$file" ] || continue
        version=$(echo "$file" | cut -d'-' -f3-)
        echo "  $version"
        found=1
    done
    [ "$found" -eq 0 ] && echo "  No se encontraron kernels en /boot."
}

listar_kernels_lib() {
    if [ -d "/lib/modules" ]; then
        echo "Versiones de kernel instaladas en /lib/modules:"
        local found=0
        for dir in /lib/modules/*/; do
            [ -d "$dir" ] || continue
            echo "  $(basename "$dir")"
            found=1
        done
        [ "$found" -eq 0 ] && echo "  No se encontraron módulos en /lib/modules."
    else
        echo "El directorio /lib/modules no existe."
    fi
}

listar_kernels_usr_src() {
    if [ -d "/usr/src" ]; then
        echo "Versiones de kernel instaladas en /usr/src:"
        local found=0
        for dir in /usr/src/linux-*/; do
            [ -d "$dir" ] || continue
            echo "  $(basename "$dir")"
            found=1
        done
        [ "$found" -eq 0 ] && echo "  No se encontraron fuentes en /usr/src."
    else
        echo "El directorio /usr/src no existe."
    fi
}

eliminar_kernel() {
    read -rp "¿Qué kernel desea borrar? " kernel_to_remove

    # Validación básica
    if [ -z "$kernel_to_remove" ]; then
        echo "No se ingresó ninguna versión."
        return
    fi

    # Verificar que al menos existe en un lugar antes de preguntar
    local existe=0
    [ -e "/boot/vmlinuz-generic-$kernel_to_remove" ] && existe=1
    [ -e "/lib/modules/$kernel_to_remove" ]          && existe=1
    [ -e "/usr/src/linux-$kernel_to_remove" ]        && existe=1

    if [ "$existe" -eq 0 ]; then
        echo "No se encontró el kernel $kernel_to_remove en ninguna ubicación."
        return
    fi

    # Confirmación antes de borrar
    echo ""
    echo "Se eliminarán los siguientes archivos/directorios (si existen):"
    [ -e "/boot/vmlinuz-generic-$kernel_to_remove" ] && echo "  /boot/vmlinuz-generic-$kernel_to_remove"
    [ -e "/boot/System.map-generic-$kernel_to_remove" ] && echo "  /boot/System.map-generic-$kernel_to_remove"
    [ -e "/boot/config-generic-$kernel_to_remove" ]  && echo "  /boot/config-generic-$kernel_to_remove"
    [ -e "/lib/modules/$kernel_to_remove" ]           && echo "  /lib/modules/$kernel_to_remove"
    [ -e "/usr/src/linux-$kernel_to_remove" ]         && echo "  /usr/src/linux-$kernel_to_remove"
    echo ""
    read -rp "¿Confirmar eliminación? [s/N]: " confirm
    case "$confirm" in
        s|S) ;;
        *) echo "Cancelado."; return ;;
    esac

    # Eliminar /boot
    if [ -e "/boot/vmlinuz-generic-$kernel_to_remove" ]; then
        rm -f "/boot/vmlinuz-generic-$kernel_to_remove" \
              "/boot/System.map-generic-$kernel_to_remove" \
              "/boot/config-generic-$kernel_to_remove"
        echo "Kernel $kernel_to_remove eliminado de /boot."
    else
        echo "No encontrado en /boot."
    fi

    # Eliminar /lib/modules
    if [ -e "/lib/modules/$kernel_to_remove" ]; then
        rm -rf "/lib/modules/$kernel_to_remove"
        echo "Kernel $kernel_to_remove eliminado de /lib/modules."
    else
        echo "No encontrado en /lib/modules."
    fi

    # Eliminar /usr/src
    if [ -e "/usr/src/linux-$kernel_to_remove" ]; then
        rm -rf "/usr/src/linux-$kernel_to_remove"
        echo "Kernel $kernel_to_remove eliminado de /usr/src."
    else
        echo "No encontrado en /usr/src."
    fi
}

# Menú principal
while true; do
    echo ""
    echo "Menú:"
    echo "1. Listar kernels en /boot"
    echo "2. Listar kernels en /lib/modules"
    echo "3. Listar kernels en /usr/src"
    echo "4. Eliminar kernel"
    echo "5. Salir"
    read -rp "Seleccione una opción: " opcion
    case $opcion in
        1) listar_kernels_instalados_boot ;;
        2) listar_kernels_lib ;;
        3) listar_kernels_usr_src ;;
        4) eliminar_kernel ;;
        5) echo "Salir."; exit 0 ;;
        *) echo "Opción inválida." ;;
    esac
done
