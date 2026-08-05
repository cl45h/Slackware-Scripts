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

#By cl45h, aguante remote vieja
# Verificar si se está ejecutando como root
if [ "$(id -u)" -ne 0 ]; then
    echo "Warning: Este script debe ejecutarse como root para realizar algunas operaciones."
    echo "Por favor, vuelva a ejecutar el script con privilegios de superusuario (sudo)."
    exit 1
fi

# Asegurar que /sbin y /usr/sbin estén en PATH (mkinitrd, depmod, lilo, grub viven ahí)
export PATH="/usr/sbin:/sbin:$PATH"

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

    cd "/usr/src/linux-$kernel_version" || {
        echo "Error: No se pudo cambiar al directorio /usr/src/linux-$kernel_version."
        return
    }

    # Verificar si el archivo .config ya existe
    if [ ! -e ".config" ]; then
        # Si no existe, intentar copiar la configuración desde /proc/config.gz
        if zcat /proc/config.gz > .config; then
            echo "Archivo de configuración (.config) creado exitosamente desde /proc/config.gz."
        else
            echo "Error: No se pudo crear el archivo de configuración (.config) desde /proc/config.gz."
            return
        fi
    else
        echo "El archivo de configuración (.config) ya existe."
    fi

    # Ejecutar make olddefconfig (toma los defaults de los símbolos nuevos del salto de versión)
    if make olddefconfig; then
        echo "Configuración del kernel actualizada con éxito usando make olddefconfig."
    else
        echo "Error: No se pudo actualizar la configuración del kernel con make olddefconfig."
        return
    fi

    # Preguntar al usuario el número de núcleos
    read -p "Ingrese el número de núcleos para compilar (por ejemplo, 32): " nucleos
    [ -z "$nucleos" ] && nucleos=$(nproc)

    # Compilar el kernel con el número de núcleos especificado
    if make -j"$nucleos" bzImage; then
        echo "Compilación del kernel (bzImage) completada exitosamente con $nucleos núcleos."

        # Compilar los módulos e instalarlos (esto también corre depmod para la versión nueva)
        if make -j"$nucleos" modules && make modules_install; then
            echo "Compilación de módulos e instalación completadas exitosamente."
            echo "Módulos instalados en /lib/modules/$kernel_version"
        else
            echo "Error: No se pudieron compilar los módulos e instalar."
        fi
    else
        echo "Error: No se pudo compilar el kernel (bzImage) con $nucleos núcleos."
    fi
}

# Función para realizar ajustes finales (copiar imagen + CONSTRUIR el initrd de verdad)
ajustes_finales() {
    if [ -z "$kernel_version" ]; then
        echo "Error: Debes ingresar la versión del kernel primero."
        return
    fi
    VER="$kernel_version"

    if [ ! -d "/boot" ]; then
        echo "Error: El directorio /boot no existe."
        return
    fi

    # Ubicarse en el árbol del kernel para tomar bzImage/System.map/.config
    cd "/usr/src/linux-$VER" || {
        echo "Error: No encuentro /usr/src/linux-$VER. Compilá el kernel primero (opción 2)."
        return
    }

    if [ ! -d "/lib/modules/$VER" ]; then
        echo "Aviso: no existe /lib/modules/$VER. Corré 'make modules_install' (opción 2) antes de armar el initrd."
    fi

    # 1) Imagen del kernel + System.map + config, versionados.
    #    Ojo: NO se pisan los symlinks /boot/System.map ni /boot/config del kernel en uso.
    cp "arch/x86/boot/bzImage" "/boot/vmlinuz-generic-$VER"
    cp "System.map"            "/boot/System.map-generic-$VER"
    cp ".config"               "/boot/config-generic-$VER"
    echo "Kernel copiado a /boot/vmlinuz-generic-$VER"

    # Apuntar los symlinks genéricos /boot/System.map y /boot/config al kernel nuevo.
    # Es la convención estándar de Slackware (lo de siempre). No interviene en el boot,
    # pero deja el mapa de símbolos correcto para decodificar un panic/oops.
    # Uso 'ln -sf' en vez de 'rm + ln' para que sea atómico y no borre nada a ciegas.
    ln -sf "System.map-generic-$VER" /boot/System.map
    ln -sf "config-generic-$VER"     /boot/config
    echo "Symlinks /boot/System.map y /boot/config -> versión $VER"

    # 2) INITRD REAL. Este era el paso que faltaba: antes solo se IMPRIMÍA el comando.
    #    El nombre initrd-$VER.img es EXACTAMENTE el que /etc/grub.d/10_linux busca
    #    para un kernel llamado vmlinuz-generic-$VER, así que GRUB lo va a enganchar.
    IMG="/boot/initrd-$VER.img"
    GEN="/usr/share/mkinitrd/mkinitrd_command_generator.sh"
    MKCMD=""

    if [ -r "$GEN" ]; then
        # El generador detecta solo el fs de root, el controlador de disco y los módulos
        # necesarios. Le sacamos la línea 'mkinitrd ...' que recomienda para este kernel.
        MKCMD=$(sh "$GEN" -k "$VER" 2>/dev/null | grep -E '^[[:space:]]*mkinitrd ' | head -1 | sed -e 's/^[[:space:]]*//')
    fi

    if [ -n "$MKCMD" ]; then
        # Forzar el nombre de salida al que GRUB espera (el default del generador es /boot/initrd.gz,
        # que GRUB NO empareja con vmlinuz-generic-$VER; ahí estaba el bug de "no bootea").
        if echo "$MKCMD" | grep -q ' -o '; then
            MKCMD=$(echo "$MKCMD" | sed -E "s#-o[[:space:]]+[^[:space:]]+#-o $IMG#")
        else
            MKCMD="$MKCMD -o $IMG"
        fi
        echo "Generando initrd:"
        echo "  $MKCMD"
        eval "$MKCMD"
    else
        # Fallback si el generador no está: initrd directo con el fs y device de root reales.
        ROOTDEV=$(findmnt -no SOURCE /)
        ROOTFS=$(findmnt -no FSTYPE /)
        echo "Generando initrd (fallback):"
        echo "  mkinitrd -c -k $VER -f $ROOTFS -r $ROOTDEV -m $ROOTFS -o $IMG"
        mkinitrd -c -k "$VER" -f "$ROOTFS" -r "$ROOTDEV" -m "$ROOTFS" -o "$IMG"
    fi

    # 3) Verificación: sin este archivo, GRUB bootea sin initrd y podés comerte un
    #    "VFS: Unable to mount root fs" si algún driver del root quedó como módulo.
    if [ -s "$IMG" ]; then
        echo "OK: initrd creado -> $IMG ($(du -h "$IMG" | cut -f1))"
    else
        echo "ERROR: no se creó el initrd ($IMG). Revisá el comando de arriba antes de seguir."
    fi
    cd /usr/src || return
}

# Función para la instalación en el bootloader
instalacion_bootloader() {
    if [ -z "$kernel_version" ]; then
        echo "Error: Debes ingresar la versión del kernel primero."
        return
    fi
    VER="$kernel_version"

    if [ ! -s "/boot/initrd-$VER.img" ]; then
        echo "Aviso: no encuentro /boot/initrd-$VER.img. Corré primero 'Ajustes Finales' (opción 3)"
        echo "o el kernel va a quedar sin initrd en el menú."
    fi

    # Preguntar al usuario en qué bootloader desea instalar
    read -p "Seleccione el bootloader para la instalación (grub, lilo): " bootloader

    case $bootloader in
        grub)
            echo "Regenerando la configuración de GRUB para vmlinuz-generic-$VER..."
            grub-mkconfig -o /boot/grub/grub.cfg
            echo
            echo ">>> En el menú de GRUB elegí la entrada 'with Linux $VER'."
            echo ">>> NO elijas 'with Linux generic': ese symlink sigue apuntando al kernel viejo, a propósito, como rescate."
            ;;
        lilo)
            echo "Instalando en LILO para vmlinuz-generic-$VER..."
            echo "Recordá que la entrada de LILO tiene que apuntar a:"
            echo "  image  = /boot/vmlinuz-generic-$VER"
            echo "  initrd = /boot/initrd-$VER.img"
            echo "  root   = $(findmnt -no SOURCE /)"
            echo "Editá /etc/lilo.conf si hace falta y después:"
            lilo -v
            ;;
        *)
            echo "Error: Bootloader no reconocido. Selecciona un bootloader válido (grub o lilo)."
            return
            ;;
    esac

    echo "Instalación en el bootloader completada. Dejá SIEMPRE el kernel anterior en el menú como rescate."
}

rebuild_modulos_externos() {
    if [ -z "$kernel_version" ]; then
        echo "Error: Debes ingresar la versión del kernel primero."
        return
    fi
    VER="$kernel_version"

    if [ ! -d "/lib/modules/$VER" ]; then
        echo "No existe /lib/modules/$VER. Compilá e instalá el kernel primero (opciones 2 y 3)."
        return
    fi

    if command -v dkms >/dev/null 2>&1; then
        NVVER=$(dkms status 2>/dev/null | grep -oE 'nvidia/[0-9][0-9.]+' | head -1 | cut -d/ -f2)
        if [ -n "$NVVER" ]; then
            echo "Compilando nvidia/$NVVER para el kernel $VER via dkms..."
            echo "OJO: si el driver es más viejo que el kernel puede no compilar. Si falla, booteás el kernel anterior y no pasa nada."
            if dkms install "nvidia/$NVVER" -k "$VER"; then
                echo "Módulo NVIDIA ($NVVER) instalado para $VER."
                depmod -a "$VER"
            else
                echo "El build de NVIDIA ($NVVER) falló para $VER."
                echo "Probá un driver más nuevo (mismo día que el kernel es lo ideal), instalalo con su .run"
                echo "respondiendo SÍ al registro en dkms, y volvé a correr esta opción."
            fi
        else
            echo "dkms está pero no encuentro un módulo nvidia registrado (revisá 'dkms status')."
        fi
    else
        echo "No hay dkms. Si usás el driver propietario, recompilalo a mano después de bootear $VER."
    fi
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
    if [ -d "/usr/src/linux-$version" ]; then
        echo "Ya existe /usr/src/linux-$version, salteo la descarga."
        return 0
    fi
    if wget -q --show-progress "$url"; then
        echo "Kernel versión $version descargado exitosamente."
        tar -xpf "linux-$version.tar.xz"
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
    echo "3. Ajustes Finales (copiar imagen + generar initrd)"
    echo "4. Instalación en el Bootloader"
    echo "5. Rebuild módulos externos (nvidia)"
    echo "6. Instalación en Ubuntu"
    echo "7. Salir"

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
        5)
            rebuild_modulos_externos
            ;;
        6)  kernel_ubuntu
            ;;
        7)
            echo "Saliendo del script. ¡Nos vimos!"
            exit 0
            ;;
        *)
            echo "Opción no válida. Por favor, elija una opción válida."
            ;;
    esac
    read -n 1 -s -r -p "Presione una tecla para continuar..."
done
