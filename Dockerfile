FROM php:7.3-apache-buster

# install needed php extensions
RUN docker-php-ext-install mysqli pdo_mysql

# disable default site
RUN a2dissite 000-default

# configured bedrock vhost
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

# composer
RUN curl -sS https://getcomposer.org/installer -o /tmp/composer-setup.php
RUN php /tmp/composer-setup.php --install-dir=/usr/local/bin
RUN rm /tmp/composer-setup.php

COPY apache2-foreground /usr/local/bin/
WORKDIR /var/www/html

EXPOSE 80
CMD ["apache2-foreground"]
