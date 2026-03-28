# Kernel Compiler y Kernel Eraser

**Kernel Compiler**
Script para descargar, compilar e instalar cualquier versión del kernel directamente desde kernel.org. Soporta arquitecturas x86_64, arm64, arm y riscv64. Incluye configuración automática desde `/proc/config.gz`, compilación con múltiples núcleos, instalación de módulos, generación de initrd y soporte para bootloaders GRUB y LILO. También permite instalar kernels pre-compilados de Ubuntu. Cada quien es libre de probar en su distro.

**Kernel Eraser**
Elimina kernels instalados de `/boot`, `/lib/modules` y `/usr/src` en una sola operación. Muestra exactamente qué archivos se van a borrar antes de confirmar.

**SLPKG Repo Switcher**
Cambia el repositorio activo de SLPKG sin editar el `repositories.toml` a mano. Hace backup automático antes de modificar.

---

Aguante RemoteExecution — contacto: cl45h@protonmail.com
