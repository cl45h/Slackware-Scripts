#!/bin/bash

# Función para mostrar el banner
mostrar_banner() {
    cat << "EOF"
                ___________
            .-=d88888888888b=-.
        .:d8888pr"|\|/-\|'rq8888b.
      ,:d8888P^//\-\/_\ /_\/^q888/b.
    ,;d88888/~-/ .-~  _~-. |/-q88888b,
   //8888887-\ _/    (#)  \\-\/Y88888b\
   \8888888|// T      `    Y _/|888888 o
    \q88888|- \l           !\_/|88888p/
     'q8888l\-//\         / /\|!8888P'
       'q888\/-| "-,___.-^\/-\/888P'
         `=88\./-/|/ |-/!\/-!/88='
            ^^"-------------"^

By cl45h, aguante remote vieja
Los kernel de ubuntu, son dedicados para axelnoalex
EOF
}

#By cl45h, aguante remote vieja
# Verificar si se está ejecutando como root
if [ "$(id -u)" -ne 0 ]; then
    echo "Warning: Este script debe ejecutarse como root para realizar algunas operaciones."
    echo "Por favor, vuelva a ejecutar el script con privilegios de superusuario (sudo)."
    exit 1
fi

# Verificar si el directorio actual es /usr/src
if [ "$(pwd)" != "/usr/src" ]; then
    echo "Moviendo al directorio /usr/src..."
    cd /usr/src || {
        echo "Error: No se pudo cambiar al directorio /usr/src. Asegúrate de que exista."
        exit 1
    }
fi

# Función para compilar el kernel
build_kernel() {
    if [ -z "$kernel_version" ]; then
        echo "Error: Debes ingresar la versión del kernel primero."
        return
    fi

    cd "linux-$kernel_version" || {
        echo "Error: No se pudo cambiar al directorio linux-$kernel_version."
        return
    }

    # Verificar si el archivo .config ya existe
    if [ ! -e ".config" ]; then
        # Si no existe, intentar copiar la configuración desde /proc/config.gz
        if zcat /proc/config.gz > .config; then
            echo "Archivo de configuración (.config) creado exitosamente."
        else
            echo "Error: No se pudo crear el archivo de configuración (.config) desde /proc/config.gz."
            return
        fi
    else
        echo "El archivo de configuración (.config) ya existe."
    fi

    # Ejecutar make olddefconfig
    if make olddefconfig; then
        echo "Configuración del kernel actualizada con éxito usando make olddefconfig."
        # Puedes agregar más comandos de compilación aquí si es necesario
    else
        echo "Error: No se pudo actualizar la configuración del kernel con make olddefconfig."
        return
    fi

    # Preguntar al usuario el número de núcleos
    read -p "Ingrese el número de núcleos para compilar (por ejemplo, 2): " nucleos

    # Compilar el kernel con el número de núcleos especificado
    if make -j"$nucleos" bzImage; then
        echo "Compilación del kernel (bzImage) completada exitosamente con $nucleos núcleos."

        # Esperar a que el usuario presione una tecla antes de continuar
        read -n 1 -s -r -p "Presione una tecla para continuar..."

        # Compilar los módulos e instalarlos
        if make -j"$nucleos" modules && make modules_install; then
            echo "Compilación de módulos e instalación completadas exitosamente."
        else
            echo "Error: No se pudieron compilar los módulos e instalar."
        fi
    else
        echo "Error: No se pudo compilar el kernel (bzImage) con $nucleos núcleos."
    fi
}

# Función para realizar ajustes finales
ajustes_finales() {
    if [ -z "$kernel_version" ]; then
        echo "Error: Debes ingresar la versión del kernel primero."
        return
    fi

    # Copiar archivos al directorio /boot
    if [ -d "/boot" ]; then
        cp arch/x86/boot/bzImage "/boot/vmlinuz-generic-$kernel_version"
        cp System.map "/boot/System.map-generic-$kernel_version"
        cp .config "/boot/config-generic-$kernel_version"

        echo "Creando enlaces simbólicos en el directorio de boot. Presione enter para continuar."
        read -s -p ""

        # Crear enlaces simbólicos
        cd /boot || {
            echo "Error: No se pudo cambiar al directorio /boot."
            return
        }
        rm System.map
        rm config
        ln -s "System.map-generic-$kernel_version" System.map
        ln -s "config-generic-$kernel_version" config
        cd - || return

        echo "Creando imágenes ramdisk usando los módulos precargados. Presione enter para continuar."
        read -s -p ""

        # Crear imágenes ramdisk
        /usr/share/mkinitrd/mkinitrd_command_generator.sh -k "$kernel_version"
    else
        echo "Error: El directorio /boot no existe. Asegúrate de que /boot esté creado antes de ejecutar este script."
    fi
}

# Función para la instalación en el bootloader
instalacion_bootloader() {
    if [ -z "$kernel_version" ]; then
        echo "Error: Debes ingresar la versión del kernel primero."
        return
    fi

    # Preguntar al usuario en qué bootloader desea instalar
    read -p "Seleccione el bootloader para la instalación (grub, lilo, etc.): " bootloader

    case $bootloader in
        grub)
            echo "Realizando la instalación en GRUB para vmlinuz-generic-$kernel_version..."
            # Comandos específicos para la instalación en GRUB
            grub-mkconfig -o /boot/grub/grub.cfg
            ;;
        lilo)
            echo "Realizando la instalación en LILO para vmlinuz-generic-$kernel_version..."
            # Comandos específicos para la instalación en LILO
            ;;
        *)
            echo "Error: Bootloader no reconocido. Selecciona un bootloader válido."
            return
            ;;
    esac

    # Puedes agregar comandos específicos de instalación en el bootloader según tu configuración

    echo "Instalación en el bootloader completada."
}

# Validación para verificar si la cadena es un número o tiene formato de versión
es_version_valida() {
    local entrada=$1
    if [[ $entrada =~ ^[0-9]+(\.[0-9]+)*$ ]]; then
        return 0  # Es una versión válida
    else
        return 1  # No es una versión válida
    fi
}

# Descargar el kernel desde kernel.org y extraerlo
descargar_y_extraer_kernel() {
    local version=$1
    local url="https://cdn.kernel.org/pub/linux/kernel/v${version%%.*}.x/linux-$version.tar.xz"
    if wget -q "$url"; then
        echo "Kernel versión $version descargado exitosamente."
        tar -xvpf "linux-$version.tar.xz"
        return 0  # Descarga y extracción exitosas
    else
        echo "Error: Kernel versión $version no encontrado en kernel.org."
        return 1  # Error en la descarga
    fi
}
# Función para instalar el kernel de Ubuntu
kernel_ubuntu() {
    echo "Seleccione la versión del kernel de Ubuntu que desea instalar:"
    
    # URL base para los kernels de Ubuntu
    base_url="https://kernel.ubuntu.com/mainline/v"

    # Leer la versión del kernel desde el usuario
    read -p "Versión del kernel (por ejemplo, 5.15): " kernel_version

    # Construir la URL completa
    url="${base_url}${kernel_version}/amd64/"

    # Crear directorio de destino
    destino="./paquetes_deb"
    mkdir -p "$destino"

    # Descargar la página HTML que contiene los enlaces
    wget -q -O- "$url" | grep -oP '(?<=href=")[^"]*\.deb' | while read -r link; do
        # Construir la URL completa de cada paquete .deb
        package_url="${url}${link}"
        
        # Nombre del paquete .deb
        package_name="$(basename "$link")"

        # Descargar el paquete .deb en el directorio de destino
        wget -P "$destino" "$package_url" && echo "Descargado: $package_name"
    done

    echo "Descarga del kernel de Ubuntu versión $kernel_version completada en el directorio: $destino"
    read -p "Presione enter para instalar el kernel"
    
    # Instalar los paquetes .deb utilizando dpkg
    cd "$destino" || exit
    sudo dpkg -i *.deb

    echo "Instalación del kernel completada."
    update-grub
    
}


# Mostrar el banner al inicio
mostrar_banner

# Menú principal
while true; do
    clear  # Limpiar la pantalla antes de mostrar el menú
    mostrar_banner
    echo "Menú:"
    echo "1. Ingresar versión de kernel a compilar"
    echo "2. Build kernel"
    echo "3. Ajustes Finales"
    echo "4. Instalación en el Bootloader"
    echo "5. Instalación en el Ubuntu"
    echo "6. Salir"

    read -p "Ingrese su opción: " opcion

    case $opcion in
        1)
            read -p "Ingrese la versión del kernel a compilar: " kernel_version
            if es_version_valida "$kernel_version"; then
                if descargar_y_extraer_kernel "$kernel_version"; then
                    echo "Versión del kernel guardada: $kernel_version"
                else
                    echo "Error: La versión del kernel no existe en kernel.org."
                fi
            else
                echo "Error: La versión del kernel no es válida. Debe ser una cadena de números y puntos."
            fi
            ;;
        2)
            build_kernel
            ;;
        3)
            ajustes_finales
            ;;
        4)
            instalacion_bootloader
            ;;
        5)  kernel_ubuntu
            ;;
        6)
            echo "Saliendo del script. ¡Nos vimos!"
            exit 0
            ;;
        *)
            echo "Opción no válida. Por favor, elija una opción válida."
            ;;
    esac
    read -n 1 -s -r -p "Presione una tecla para continuar..."
done
