FROM debian:buster-slim

# https://github.com/moby/moby/issues/27988#issuecomment-462809153
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

RUN set -eux; \
	{ \
		echo 'Package: php*'; \
		echo 'Pin: release *'; \
		echo 'Pin-Priority: -1'; \
	} > /etc/apt/preferences.d/no-debian-php

ENV PHP_INI_DIR /usr/local/etc/php
RUN mkdir -p "$PHP_INI_DIR/conf.d"

RUN apt-get update && apt-get install -q -y --no-install-recommends \
    apache2                  \
    apache2-dev              \
    autoconf                 \
    ca-certificates          \
    curl                     \
    dirmngr                  \
    dpkg-dev                 \
    file                     \
    g++                      \
    gcc                      \
    git                      \
    gnupg                    \
    groff                    \
    jq                       \
    less                     \
    libargon2-dev            \
    libc-dev                 \
    libcurl4-openssl-dev     \
    libedit-dev              \
    libsodium-dev            \
    libsqlite3-dev           \
    libssl-dev               \
    libxml2-dev              \
    make                     \
    mariadb-client-10.3      \
    mariadb-client-core-10.3 \
    nano                     \
    ntp                      \
    pkg-config               \
    re2c                     \
    tree                     \
    tzdata                   \
    unzip                    \
    vim                      \
    wget                     \
    xz-utils                 \
    zip                      \
    zlib1g-dev               \
    && rm -rf /var/lib/apt/lists/*


RUN a2dismod mpm_event && a2enmod mpm_prefork

ENV APACHE_CONFDIR /etc/apache2
ENV APACHE_ENVVARS $APACHE_CONFDIR/envvars

# PHP files should be handled by PHP, and should be preferred over any other file type
RUN { \
		echo '<FilesMatch \.php$>'; \
		echo '\tSetHandler application/x-httpd-php'; \
		echo '</FilesMatch>'; \
		echo; \
		echo 'DirectoryIndex disabled'; \
		echo 'DirectoryIndex index.php index.html'; \
		echo; \
		echo '<Directory /var/www/>'; \
		echo '\tOptions -Indexes'; \
		echo '\tAllowOverride All'; \
		echo '</Directory>'; \
	} | tee "$APACHE_CONFDIR/conf-available/php.conf" \
	&& a2enconf php

ENV PHP_EXTRA_BUILD_DEPS apache2-dev
ENV PHP_EXTRA_CONFIGURE_ARGS --with-apxs2 --disable-cgi

RUN mkdir -p /usr/src; \
    cd /usr/src; \
    curl -fsSL -o php.tar.xz "https://www.php.net/distributions/php-7.3.25.tar.xz"; \
    mkdir -p /usr/src/php; \
    tar -Jxf /usr/src/php.tar.xz -C "/usr/src/php" --strip-components=1; \
    cd /usr/src/php; \
    gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"; \
	debMultiarch="$(dpkg-architecture --query DEB_BUILD_MULTIARCH)"; \
    if [ ! -d /usr/include/curl ]; then \
		ln -sT "/usr/include/$debMultiarch/curl" /usr/local/include/curl; \
	fi; \
	./configure \
		--build="$gnuArch" \
		--with-config-file-path="$PHP_INI_DIR" \
		--with-config-file-scan-dir="$PHP_INI_DIR/conf.d" \
		--enable-option-checking=fatal \
		--with-mhash \
		--with-pic \
		--enable-ftp \
		--enable-mbstring \
		--enable-mysqlnd \
		--with-password-argon2 \
		--with-sodium=shared \
		--with-pdo-sqlite=/usr \
		--with-sqlite3=/usr \
		--with-curl \
		--with-libedit \
		--with-openssl \
		--with-zlib \
		$(test "$gnuArch" = 's390x-linux-gnu' && echo '--without-pcre-jit') \
		--with-libdir="lib/$debMultiarch" \
		${PHP_EXTRA_CONFIGURE_ARGS:-} \
	; \
	make -j "$(nproc)"; \
	find -type f -name '*.a' -delete; \
	make install; \
	find /usr/local/bin /usr/local/sbin -type f -executable -exec strip --strip-all '{}' + || true; \
	make clean; \    
    pecl update-channels; \
    rm -rf /tmp/pear ~/.pearrc;

COPY apache2-foreground /usr/local/bin/
WORKDIR /var/www/html

EXPOSE 80
CMD ["apache2-foreground"]
