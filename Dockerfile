FROM php:7.4-fpm-alpine

LABEL maintainer="Hamed dhib <hamed.dhib@leadwire.io>"

# entrypoint.sh and installto.sh dependencies
RUN set -ex; \
	\
	apk add --no-cache \
		bash \
		coreutils \
		rsync \
		tzdata

RUN set -ex; \
	\
	apk add --no-cache --virtual .build-deps \
		$PHPIZE_DEPS \
		icu-dev \
		imagemagick-dev \
		libjpeg-turbo-dev \
		libpng-dev \
		libzip-dev \
		libtool \
		openldap-dev \
		postgresql-dev \
		sqlite-dev \
	; \
	\
	docker-php-ext-configure gd; \
	docker-php-ext-configure ldap; \
	docker-php-ext-install \
		exif \
		gd \
		intl \
		ldap \
		pdo_mysql \
		pdo_pgsql \
		pdo_sqlite \
		zip \
	; \
	pecl install imagick redis; \
	docker-php-ext-enable imagick opcache redis; \
	\
	runDeps="$( \
		scanelf --needed --nobanner --format '%n#p' --recursive /usr/local/lib/php/extensions \
		| tr ',' '\n' \
		| sort -u \
		| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
		)"; \
	apk add --virtual .roundcubemail-phpext-rundeps imagemagick $runDeps; \
	apk del .build-deps
 

RUN apk update \
    && apk add --no-cache \
        php-pear \
	ca-certificates
 
RUN pear install Net_SMTP
# add composer.phar
ADD https://getcomposer.org/installer /tmp/composer-installer.php

RUN php /tmp/composer-installer.php --install-dir=/usr/local/bin/; \
	rm /tmp/composer-installer.php


# Install dependencies
RUN apk add --no-cache \
    zlib-dev \
    libmemcached-dev \
    cyrus-sasl-dev \
    wget \
    gcc \
    libc-dev \
    autoconf \
    make \
    openssl-dev \
    git

# Download and extract memcache source
RUN wget http://pecl.php.net/get/memcache-4.0.5.1.tgz \
    && tar -zxvf memcache-4.0.5.1.tgz \
    && cd memcache-4.0.5.1 \
    && phpize \
    && ./configure \
    && make \
    && make install \
    && docker-php-ext-enable memcache
    
# Install MongoDB PHP client library from Git source 
RUN  git clone -b v1.8  https://github.com/mongodb/mongo-php-driver.git
RUN mkdir -p mongo-php-driver \
   &&  cd mongo-php-driver  \
   &&  git submodule update --init \
   &&  phpize \
   &&  ./configure  \
   &&  make all \
   &&  make install \
   && docker-php-ext-enable mongodb

RUN apk --no-cache add imap-dev openssl-dev
RUN docker-php-ext-configure imap --with-imap --with-imap-ssl \
    && docker-php-ext-install imap

# Clean up
RUN rm -rf /tmp/* /var/cache/apk/*
