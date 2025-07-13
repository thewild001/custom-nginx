# Base PHP-FPM
FROM php:7.1-fpm-buster

# Variables de entorno
ENV APP_HOME /var/www/html

# Instalar dependencias del sistema
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-client \
    gettext \
    nano \
    gnupg \
    libc-client-dev \
    rsync \
    git \
    unzip \
    libpq-dev \
    libldap2-dev \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libxml2-dev \
    libzip-dev \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Instalar extensiones PHP
COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/
RUN install-php-extensions \
    pdo_pgsql \
    pgsql \
    exif \
    pcntl \
    bcmath \
    ldap \
    gd \
    intl \
    zip \
    xsl \
    opcache

# Configuración de opcache
RUN echo "[opcache]" > /usr/local/etc/php/conf.d/opcache.ini \
    && echo "zend_extension=opcache.so" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.enable=1" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.memory_consumption=128" >> /usr/local/etc/php/conf.d/opcache.ini

# Directorio de trabajo
WORKDIR ${APP_HOME}

# Exponer puerto de PHP-FPM
EXPOSE 9000

# Comando para iniciar PHP-FPM
CMD ["php-fpm"]
