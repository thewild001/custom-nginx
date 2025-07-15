# Etapa de dependencias de sistema y Composer
FROM php:7.1-fpm-buster as base

# Variables de entorno
ENV DEBIAN_FRONTEND=noninteractive
ENV APP_HOME /var/www/html
ENV COMPOSER_DEPS_PATH /tmp/composer_deps

# Instalar dependencias del sistema
RUN apt-get clean && \
apt-get update --fix-missing && \
apt-get install -f && \
apt-get install -y --no-install-recommends --allow-remove-essential \
    openssh-client \
    gettext \
    nano \
    gnupg \
    libc-client-dev \
    rsync \
    git \
    unzip \
    wget \
    curl \
    libpq-dev \
    libldap2-dev \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    libzip-dev \
    libicu-dev \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Instalar Composer
COPY --from=composer:lts /usr/bin/composer /usr/local/bin/composer

# Crear directorios
RUN mkdir -p ${APP_HOME} ${COMPOSER_DEPS_PATH}

WORKDIR ${COMPOSER_DEPS_PATH}

# Copiar archivos de composición
COPY composer.json ./

# Instalar dependencias de Composer
RUN php -d memory_limit=-1 /usr/local/bin/composer config --no-plugins allow-plugins.raulfraile/ladybug-installer false && \
    /usr/local/bin/composer config --no-plugins allow-plugins.ocramius/package-versions false && \
    /usr/local/bin/composer install -vvv -q --no-ansi --no-interaction --no-scripts --no-progress --prefer-dist --ignore-platform-reqs --optimize-autoloader

# Copiar instalador de extensiones PHP
COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/

# Instalar extensiones PHP adicionales
RUN install-php-extensions \
    pdo_pgsql \
    pgsql \
    exif \
    pcntl \
    bcmath \
    ldap \
    imap \
    gd \
    intl \
    zip \
    xsl \
    opcache \
    dom \
    simplexml \
    xml \
    xmlreader \
    xmlwriter

# Instalación mcrypt (específico para PHP 7.1)
#RUN apt-get install -y --no-install-recommends --allow-remove-essential mcrypt \
#    && docker-php-ext-enable mcrypt

# Habilitar extensiones
RUN docker-php-ext-enable \
    pdo_pgsql \
    pgsql \
    exif \
    pcntl \
    bcmath \
    ldap \
    imap \
    gd \
    intl \
    zip \
    xsl 

# Configuración específica para extensiones
RUN echo "[opcache]" > /usr/local/etc/php/conf.d/opcache.ini \
    && echo "zend_extension=opcache.so" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.enable=1" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.enable_cli=1" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.memory_consumption=128" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.interned_strings_buffer=8" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.max_accelerated_files=4000" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.revalidate_freq=60" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.validate_timestamps=1" >> /usr/local/etc/php/conf.d/opcache.ini

# Verificación de instalación
RUN php -m | grep -E 'intl|opcache|xsl' \
    && php -i | grep 'ICU version' \
    && ldconfig

WORKDIR ${APP_HOME}

# Volúmenes
VOLUME [${APP_HOME}, ${COMPOSER_DEPS_PATH}]

# Exponer puerto de PHP-FPM
EXPOSE 9000

# Comando para iniciar PHP-FPM
CMD ["php-fpm"]
