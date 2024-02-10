#!/bin/bash

function listar_kernels_instalados_boot() {
    echo "Versiones de kernel instaladas en /boot:"
    # Listamos las versiones de kernel instaladas en /boot
    for file in /boot/vmlinuz-generic*; do
        version=$(echo "$file" | cut -d'-' -f3)
        echo "$version"
    done
}

function listar_kernels_lib() {
    if [ -d "/lib/modules" ]; then
        echo "Versiones de kernel instaladas en /lib/modules:"
        # Listamos las versiones de kernel instaladas en /lib/modules
        for dir in /lib/modules/*/; do
            version=$(basename "$dir")
            echo "$version"
        done
    else
        echo "El directorio /lib/modules no existe."
    fi
}

function listar_kernels_usr_src() {
    if [ -d "/usr/src" ]; then
        echo "Versiones de kernel instaladas en /usr/src:"
        # Listamos las versiones de kernel instaladas en /usr/src
        for dir in /usr/src/linux*/; do
            version=$(basename "$dir")
            echo "$version"
        done
    else
        echo "El directorio /usr/src no existe."
    fi
}

function eliminar_kernel() {
    read -rp "¿Qué kernel desea borrar? " kernel_to_remove
    # Verificamos si el kernel ingresado está instalado
    if [ -e "/boot/vmlinuz-generic-$kernel_to_remove" ]; then
        # Eliminamos los archivos correspondientes al kernel seleccionado en /boot
        rm -f "/boot/vmlinuz-generic-$kernel_to_remove" "/boot/System.map-generic-$kernel_to_remove" "/boot/config-generic-$kernel_to_remove"
        echo "El kernel $kernel_to_remove ha sido eliminado de /boot."
    else
        echo "La versión de kernel ingresada no está instalada en /boot."
    fi

    if [ -e "/lib/modules/$kernel_to_remove" ]; then
        # Eliminamos el directorio correspondiente al kernel seleccionado en /lib/modules
        rm -rf "/lib/modules/$kernel_to_remove"
        echo "El kernel $kernel_to_remove ha sido eliminado de /lib/modules."
    else
        echo "La versión de kernel ingresada no está instalada en /lib/modules."
    fi

    if [ -e "/usr/src/linux-$kernel_to_remove" ]; then
        # Eliminamos el directorio correspondiente al kernel seleccionado en /usr/src
        rm -rf "/usr/src/linux-$kernel_to_remove"
        echo "El kernel $kernel_to_remove ha sido eliminado de /usr/src."
    else
        echo "La versión de kernel ingresada no está instalada en /usr/src."
    fi
}

# Mostramos el menú
while true; do
    echo "Menú:"
    echo "1. Comprobar si /boot existe y listar versiones de kernel instaladas"
    echo "2. Listar versiones de kernel instaladas en /lib/modules"
    echo "3. Listar versiones de kernel instaladas en /usr/src que empiecen con 'linux'"
    echo "4. Eliminar kernel (elimina el kernel de /boot, /lib/modules y /usr/src)"
    echo "5. Salir"
    read -rp "Seleccione una opción: " opcion
    case $opcion in
        1)
            if [ -d "/boot" ]; then
                echo "El directorio /boot existe."
                listar_kernels_instalados_boot
            else
                echo "El directorio /boot no existe."
            fi
            ;;
        2)
            listar_kernels_lib
            ;;
        3)
            listar_kernels_usr_src
            ;;
        4)
            eliminar_kernel
            ;;
        5)
            echo "Salir."
            exit 0
            ;;
        *)
            echo "Opción inválida. Por favor, seleccione una opción válida."
            ;;
    esac
done
