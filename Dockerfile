FROM debian:buster-slim

ENV IN_DOCKER=true

ADD https://raw.githubusercontent.com/ordinaryexperts/aws-marketplace-oe-patterns-wordpress/develop/packer/setup.sh /tmp/setup.sh
RUN bash /tmp/setup.sh
RUN rm -f /tmp/setup.sh

# from UserData
RUN openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -keyout /etc/ssl/private/apache-selfsigned.key \
    -out /etc/ssl/certs/apache-selfsigned.crt \
    -subj '/CN=localhost'

# logs should go to stdout / stderr
RUN ln -sfT /dev/stderr "/var/log/apache2/error.log"; \
    ln -sfT /dev/stdout "/var/log/apache2/access.log"; \
    ln -sfT /dev/stdout "/var/log/apache2/other_vhosts_access.log"

# install composer
RUN curl -sS https://getcomposer.org/installer -o /tmp/composer-setup.php; \
    php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer

COPY docker-entrypoint /usr/local/bin/
CMD ["docker-entrypoint"]
