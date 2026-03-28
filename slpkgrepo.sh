#!/bin/bash

# Verificar si se está ejecutando como root
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: Este script debe ejecutarse como root."
    exit 1
fi

FILE="/etc/slpkg/repositories.toml"

# Verificar que el archivo existe
if [[ ! -f "$FILE" ]]; then
    echo "El archivo $FILE no existe."
    exit 1
fi

# Mostrar repositorio actual
current=$(grep -oP 'REPOSITORY\s*=\s*"\K[^"]+' "$FILE" | head -1)
echo "Repositorio actual: ${current:-desconocido}"
echo ""
echo "Selecciona el repositorio que deseas:"
echo "1) alien"
echo "2) slackel"
echo "3) ponce"

read -rp "Introduce el número correspondiente a tu selección: " choice

case $choice in
    1) new_repo="alien"  ;;
    2) new_repo="slackel" ;;
    3) new_repo="ponce"  ;;
    *)
        echo "Selección no válida."
        exit 1
        ;;
esac

# Backup antes de modificar
cp "$FILE" "${FILE}.bak"
echo "Backup creado en ${FILE}.bak"

# Modificar por patrón, no por número de línea
sed -i "s/REPOSITORY = \"[^\"]*\"/REPOSITORY = \"$new_repo\"/" "$FILE"

# Verificar que el cambio se aplicó
if grep -q "REPOSITORY = \"$new_repo\"" "$FILE"; then
    echo "Repositorio cambiado exitosamente a: $new_repo"
else
    echo "Error: No se pudo aplicar el cambio. Restaurando backup..."
    cp "${FILE}.bak" "$FILE"
    exit 1
fi
