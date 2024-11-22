#!/bin/bash

# Definir el archivo
FILE="/etc/slpkg/repositories.toml"

# Verificar que el archivo existe
if [[ ! -f $FILE ]]; then
    echo "El archivo $FILE no existe."
    exit 1
fi

# Mostrar opciones al usuario
echo "Selecciona el repositorio que deseas:"
echo "1) alien"
echo "2) slackel"
echo "3) ponce"

# Leer la opción del usuario
read -p "Introduce el número correspondiente a tu selección: " choice

# Asignar el repositorio según la selección
case $choice in
    1)
        new_repo="alien"
        ;;
    2)
        new_repo="slackel"
        ;;
    3)
        new_repo="ponce"
        ;;
    *)
        echo "Selección no válida."
        exit 1
        ;;
esac

# Modificar la línea 35 del archivo
sed -i '35s/REPOSITORY = "[^"]*"/REPOSITORY = "'$new_repo'"/' $FILE

echo "El archivo ha sido modificado. Ahora el repositorio es $new_repo."
