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
#Greetings Grax vampii por ayudarme con lilo
EOF
}

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

# Arquitectura seleccionada (por defecto x86_64)
ARCH_SELECTED="x86_64"

# Devuelve el target de imagen y el path del binario según la arquitectura
get_arch_config() {
    case "$ARCH_SELECTED" in
        x86_64)
            ARCH_MAKE="x86_64"
            KERNEL_IMAGE_TARGET="bzImage"
            KERNEL_IMAGE_PATH="arch/x86/boot/bzImage"
            ;;
        arm64)
            ARCH_MAKE="arm64"
            KERNEL_IMAGE_TARGET="Image"
            KERNEL_IMAGE_PATH="arch/arm64/boot/Image"
            ;;
        arm)
            ARCH_MAKE="arm"
            KERNEL_IMAGE_TARGET="zImage"
            KERNEL_IMAGE_PATH="arch/arm/boot/zImage"
            ;;
        riscv64)
            ARCH_MAKE="riscv"
            KERNEL_IMAGE_TARGET="Image"
            KERNEL_IMAGE_PATH="arch/riscv/boot/Image"
            ;;
    esac
}

# Seleccionar arquitectura
seleccionar_arquitectura() {
    echo ""
    echo "Seleccione la arquitectura:"
    echo "1. x86_64  (actual: por defecto)"
    echo "2. arm64"
    echo "3. arm"
    echo "4. riscv64"
    read -rp "Opción: " arch_opcion
    case "$arch_opcion" in
        1) ARCH_SELECTED="x86_64" ;;
        2) ARCH_SELECTED="arm64"  ;;
        3) ARCH_SELECTED="arm"    ;;
        4) ARCH_SELECTED="riscv64" ;;
        *) echo "Opción inválida, se mantiene: $ARCH_SELECTED" ;;
    esac
    get_arch_config
    echo "Arquitectura seleccionada: $ARCH_SELECTED"
}

# Función para compilar el kernel
build_kernel() {
    if [ -z "$kernel_version" ]; then
        echo "Error: Debes ingresar la versión del kernel primero."
        return
    fi

    get_arch_config

    cd "linux-$kernel_version" || {
        echo "Error: No se pudo cambiar al directorio linux-$kernel_version."
        return
    }

    # Verificar si el archivo .config ya existe
    if [ ! -e ".config" ]; then
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
    if make ARCH="$ARCH_MAKE" olddefconfig; then
        echo "Configuración del kernel actualizada con éxito usando make olddefconfig."
    else
        echo "Error: No se pudo actualizar la configuración del kernel con make olddefconfig."
        return
    fi

    # Preguntar al usuario el número de núcleos
    read -rp "Ingrese el número de núcleos para compilar (por ejemplo, 2): " nucleos

    # Compilar el kernel
    if make ARCH="$ARCH_MAKE" -j"$nucleos" "$KERNEL_IMAGE_TARGET"; then
        echo "Compilación del kernel ($KERNEL_IMAGE_TARGET) completada exitosamente con $nucleos núcleos."

        read -n 1 -s -r -p "Presione una tecla para continuar..."

        # Compilar los módulos e instalarlos
        if make ARCH="$ARCH_MAKE" -j"$nucleos" modules && make ARCH="$ARCH_MAKE" modules_install; then
            echo "Compilación de módulos e instalación completadas exitosamente."
        else
            echo "Error: No se pudieron compilar los módulos e instalar."
        fi
    else
        echo "Error: No se pudo compilar el kernel ($KERNEL_IMAGE_TARGET) con $nucleos núcleos."
    fi
}

# Función para realizar ajustes finales
ajustes_finales() {
    if [ -z "$kernel_version" ]; then
        echo "Error: Debes ingresar la versión del kernel primero."
        return
    fi

    get_arch_config

    if [ -d "/boot" ]; then
        cp "$KERNEL_IMAGE_PATH" "/boot/vmlinuz-generic-$kernel_version" || {
            echo "Error: No se pudo copiar la imagen del kernel. Verificá que compilaste correctamente."
            return
        }
        cp System.map "/boot/System.map-generic-$kernel_version"
        cp .config "/boot/config-generic-$kernel_version"

        echo "Creando enlaces simbólicos en el directorio de boot. Presione enter para continuar."
        read -s -p ""

        cd /boot || {
            echo "Error: No se pudo cambiar al directorio /boot."
            return
        }
        rm -f System.map config
        ln -s "System.map-generic-$kernel_version" System.map
        ln -s "config-generic-$kernel_version" config
        cd - || return

        echo "Creando imágenes ramdisk usando los módulos precargados. Presione enter para continuar."
        read -s -p ""

        /usr/share/mkinitrd/mkinitrd_command_generator.sh -k "$kernel_version"
    else
        echo "Error: El directorio /boot no existe."
    fi
}

# Función para la instalación en el bootloader
instalacion_bootloader() {
    if [ -z "$kernel_version" ]; then
        echo "Error: Debes ingresar la versión del kernel primero."
        return
    fi

    read -rp "Seleccione el bootloader para la instalación (grub, lilo): " bootloader

    case $bootloader in
        grub)
            echo "Realizando la instalación en GRUB para vmlinuz-generic-$kernel_version..."
            grub-mkconfig -o /boot/grub/grub.cfg
            ;;
        lilo)
            echo "Realizando la instalación en LILO para vmlinuz-generic-$kernel_version..."
            /usr/share/mkinitrd/mkinitrd_command_generator.sh -l "/boot/vmlinuz-generic-$kernel_version"
            lilo -v
            ;;
        *)
            echo "Error: Bootloader no reconocido. Selecciona grub o lilo."
            return
            ;;
    esac

    echo "Instalación en el bootloader completada."
}

# Validación del formato de versión
es_version_valida() {
    local entrada=$1
    if [[ $entrada =~ ^[0-9]+(\.[0-9]+)*$ ]]; then
        return 0
    else
        return 1
    fi
}

# Descargar el kernel desde kernel.org y extraerlo
descargar_y_extraer_kernel() {
    local version=$1
    local url="https://cdn.kernel.org/pub/linux/kernel/v${version%%.*}.x/linux-$version.tar.xz"
    if wget -q --show-progress "$url"; then
        echo "Kernel versión $version descargado exitosamente."
        tar -xpf "linux-$version.tar.xz"
        return 0
    else
        echo "Error: Kernel versión $version no encontrado en kernel.org."
        return 1
    fi
}

# Función para instalar el kernel de Ubuntu
kernel_ubuntu() {
    echo "Seleccione la versión del kernel de Ubuntu que desea instalar:"

    base_url="https://kernel.ubuntu.com/mainline/v"
    read -rp "Versión del kernel (por ejemplo, 5.15): " kernel_version

    url="${base_url}${kernel_version}/amd64/"
    destino="./paquetes_deb"
    mkdir -p "$destino"

    wget -q -O- "$url" | grep -oP '(?<=href=")[^"]*\.deb' | while read -r link; do
        package_url="${url}${link}"
        package_name="$(basename "$link")"
        wget -P "$destino" "$package_url" && echo "Descargado: $package_name"
    done

    echo "Descarga completada en: $destino"
    read -rp "Presione enter para instalar el kernel"

    cd "$destino" || exit
    dpkg -i *.deb

    echo "Instalación del kernel completada."
    update-grub
}

# Inicializar config de arquitectura por defecto
get_arch_config

# Mostrar el banner al inicio
mostrar_banner

# Menú principal
while true; do
    clear
    mostrar_banner
    echo "Arquitectura activa: $ARCH_SELECTED"
    echo ""
    echo "Menú:"
    echo "1. Ingresar versión de kernel a compilar"
    echo "2. Build kernel"
    echo "3. Ajustes Finales"
    echo "4. Instalación en el Bootloader"
    echo "5. Instalación en Ubuntu"
    echo "6. Seleccionar arquitectura"
    echo "7. Salir"

    read -rp "Ingrese su opción: " opcion

    case $opcion in
        1)
            read -rp "Ingrese la versión del kernel a compilar: " kernel_version
            if es_version_valida "$kernel_version"; then
                if descargar_y_extraer_kernel "$kernel_version"; then
                    echo "Versión del kernel guardada: $kernel_version"
                else
                    echo "Error: La versión del kernel no existe en kernel.org."
                fi
            else
                echo "Error: Versión inválida. Debe ser formato numérico (ej: 6.6.1)."
            fi
            ;;
        2) build_kernel ;;
        3) ajustes_finales ;;
        4) instalacion_bootloader ;;
        5) kernel_ubuntu ;;
        6) seleccionar_arquitectura ;;
        7) echo "Saliendo. ¡Nos vimos!"; exit 0 ;;
        *) echo "Opción no válida." ;;
    esac
    read -n 1 -s -r -p "Presione una tecla para continuar..."
done
