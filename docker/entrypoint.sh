#!/bin/sh
set -e

# Si existe un directorio vendor montado, lo ignoramos y enlazamos el de la imagen
[ -d "${APP_HOME}/vendor" ] && rm -rf "${APP_HOME}/vendor"
ln -snf "${COMPOSER_VENDOR_DIR}" "${APP_HOME}/vendor"

exec "$@"