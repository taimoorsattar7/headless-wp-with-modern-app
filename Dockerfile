# https://websiteforstudents.com/wordpress-supports-php-7-2-heres-how-to-install-with-nginx-and-mariadb-support/

FROM ubuntu:16.04
#MAINTAINER Taimoor Sattar <taimoorsattar7@gmail.com>

# Keep upstart from complaining
# RUN dpkg-divert --local --rename --add /sbin/initctl
# RUN ln -sf /bin/true /sbin/initctl

# Let the conatiner know that there is no tty
ENV DEBIAN_FRONTEND noninteractive

# apt stuff
RUN apt-get -qq update
RUN apt-get -qq upgrade

RUN apt-get -y install software-properties-common language-pack-en-base
RUN apt-get -y install wget build-essential


# RUN add-apt-repository ppa:nginx/stable && \
#    apt-get -y install nginx curl unzip

ARG VERSION=1.17.8

# Retrieve, verify and unpack Nginx source - key server pgp.mit.edu
RUN echo ${VERSION}
RUN set -x
WORKDIR /tmp
RUN gpg --keyserver pool.sks-keyservers.net --recv-keys \
        B0F4253373F8F6F510D42178520A9993A1C052F8

RUN wget -q http://nginx.org/download/nginx-${VERSION}.tar.gz
RUN wget -q http://nginx.org/download/nginx-${VERSION}.tar.gz.asc
RUN gpg --verify nginx-${VERSION}.tar.gz.asc
RUN tar -xf nginx-${VERSION}.tar.gz

ENV LANG C.UTF-8

RUN add-apt-repository ppa:ondrej/php

RUN apt-get -qq update

# https://www.colinodell.com/blog/201812/how-install-php-73
RUN apt-get -y install php7.2-fpm php7.2-common php7.2-mbstring php7.2-xmlrpc php7.2-gd php7.2-xml php7.2-mysql php7.2-cli php7.2-zip php7.2-curl

RUN apt-get -y install libpcre3 libpcre3-dev zlib1g zlib1g-dev libssl-dev

WORKDIR /tmp/nginx-${VERSION}

RUN ls -l /usr/local

# Build and install nginx
RUN ./configure \
    --sbin-path=/usr/bin/nginx \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --with-pcre \
    --pid-path=/usr/local/nginx/nginx.pid &&  \
    make install

# WordPress stuff 
RUN cd /tmp && wget https://wordpress.org/latest.tar.gz && \
	tar -zxvf latest.tar.gz && \
	mv wordpress /var/www/html/wordpress


ADD ./wp/wp-config.php /var/www/html/wordpress
RUN chown www-data:www-data /var/www/html/wordpress/wp-config.php
RUN chown -R www-data:www-data /var/www/html/wordpress
RUN chmod 755 /var/www/html/wordpress
RUN chmod 755 /var/www/html/wordpress/wp-config.php

# Set VOLUME
VOLUME /var/www/html/wordpress
VOLUME /etc/nginx

# PHP config
ADD ./php-config/php.ini /etc/php/7.2/fpm/php.ini
# ADD ./php-config/php-fpm.conf /etc/php/7.2/fpm/php-fpm.conf
# ADD ./php-config/www.conf /etc/php/7.2/fpm/www.conf

# php-fpm config
RUN sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" /etc/php/7.2/fpm/php-fpm.conf
RUN sed -i -e "s/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/g" /etc/php/7.2/fpm/php-fpm.conf
RUN find /etc/php/7.2/cli/conf.d/ -name "*.ini" -exec sed -i -re 's/^(\s*)#(.*)/\1;\2/g' {} \;


# Customise static content, and configuration
COPY nginx.conf /usr/local/nginx/conf/


WORKDIR /usr/local/bin/

STOPSIGNAL SIGQUIT

# Expose port
EXPOSE 80

ENTRYPOINT ["/usr/local/nginx/sbin/nginx"]
CMD ["-g", "daemon off;"]