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

RUN set -eux; \
	mkdir -p "$PHP_INI_DIR/conf.d"; \
# allow running as an arbitrary user (https://github.com/docker-library/php/issues/743)
	[ ! -d /var/www/html ]; \
	mkdir -p /var/www/html; \
	chown www-data:www-data /var/www/html; \
	chmod 777 /var/www/html

ENV APACHE_CONFDIR /etc/apache2
ENV APACHE_ENVVARS $APACHE_CONFDIR/envvars

RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends apache2 apache2-dev; \
	rm -rf /var/lib/apt/lists/*; \
	\
# generically convert lines like
#   export APACHE_RUN_USER=www-data
# into
#   : ${APACHE_RUN_USER:=www-data}
#   export APACHE_RUN_USER
# so that they can be overridden at runtime ("-e APACHE_RUN_USER=...")
	sed -ri 's/^export ([^=]+)=(.*)$/: ${\1:=\2}\nexport \1/' "$APACHE_ENVVARS"; \
	\
# setup directories and permissions
	. "$APACHE_ENVVARS"; \
	for dir in \
		"$APACHE_LOCK_DIR" \
		"$APACHE_RUN_DIR" \
		"$APACHE_LOG_DIR" \
	; do \
		rm -rvf "$dir"; \
		mkdir -p "$dir"; \
		chown "$APACHE_RUN_USER:$APACHE_RUN_GROUP" "$dir"; \
# allow running as an arbitrary user (https://github.com/docker-library/php/issues/743)
		chmod 777 "$dir"; \
	done; \
	\
# logs should go to stdout / stderr
	ln -sfT /dev/stderr "$APACHE_LOG_DIR/error.log"; \
	ln -sfT /dev/stdout "$APACHE_LOG_DIR/access.log"; \
	ln -sfT /dev/stdout "$APACHE_LOG_DIR/other_vhosts_access.log"; \
	chown -R --no-dereference "$APACHE_RUN_USER:$APACHE_RUN_GROUP" "$APACHE_LOG_DIR"

# Apache + PHP requires preforking Apache for best results
RUN a2dismod mpm_event && a2enmod mpm_prefork

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
    cp -v php.ini-* "$PHP_INI_DIR/"; \
    cp php.ini-development "$PHP_INI_DIR/conf.d/php.ini"; \
	make clean; \    
    pecl update-channels; \
    rm -rf /tmp/pear ~/.pearrc;

# https://roots.io/docs/bedrock/master/server-configuration/#apache-configuration-for-bedrock
RUN { \
    echo '<VirtualHost *:80>'; \
    echo '\tDocumentRoot /var/www/html/bedrock/web'; \
    echo '\tDirectoryIndex index.php index.html index.htm'; \
    echo '\t<Directory /var/www/html/bedrock/web>'; \
    echo '\t\tOptions -Indexes'; \
    echo; \
    echo '\t\t# .htaccess is not required if you include this'; \
    echo '\t\t<IfModule mod_rewrite.c>'; \
    echo '\t\t\tRewriteEngine On'; \
    echo '\t\t\tRewriteBase /'; \
    echo '\t\t\tRewriteRule ^index.php$ - [L]'; \
    echo '\t\t\tRewriteCond %{REQUEST_FILENAME} !-f'; \
    echo '\t\t\tRewriteCond %{REQUEST_FILENAME} !-d'; \
    echo '\t\t\tRewriteRule . /index.php [L]'; \
    echo '\t\t</IfModule>'; \
    echo '\t</Directory>'; \
    echo '</VirtualHost>'; \
  } | tee "$APACHE_CONFDIR/sites-available/wordpress.conf" \
  && a2ensite wordpress

# remove default site
RUN rm -rvf /var/www/html/* && a2dissite 000-default

# composer
RUN curl -sS https://getcomposer.org/installer -o /tmp/composer-setup.php
RUN php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=compose
RUN rm /tmp/composer-setup.php
RUN ln -s /usr/local/bin/compose /usr/local/bin/composer

COPY apache2-foreground /usr/local/bin/
WORKDIR /var/www/html

EXPOSE 80
CMD ["apache2-foreground"]
