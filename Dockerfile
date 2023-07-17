# Use a imagem do PHP 7.4 com o servidor Apache como base
FROM php:7.4-apache

ARG user
ARG uid

# Instalar dependências necessárias para o projeto
RUN apt-get update && apt-get install -y \
    cron \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    zip \
    unzip \
    vim \
    tzdata \
    supervisor

# Limpar cache
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# Instalar extensões PHP necessárias para o projeto
RUN docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd sockets

# Habilitar o módulo do Apache 'mod_rewrite' e 'proxy_wstunnel'
RUN a2enmod rewrite proxy_wstunnel

# Adicionar a última versão do Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Create system user to run Composer and Artisan Commands
RUN useradd -G www-data,root -u $uid -d /home/$user $user
RUN mkdir -p /home/$user/.composer && \
    chown -R $user:$user /home/$user

# Configurar o diretório de trabalho para o projeto
WORKDIR /var/www/html

# Copiar o código-fonte do projeto para o contêiner
COPY /app/. /var/www/html/

# Copiar o arquivo de configuração do Apache
COPY docker/apache/000-default.conf /etc/apache2/sites-available/000-default.conf

# Configurar permissões e otimizações para o projeto
#RUN composer install --prefer-dist --no-dev --optimize-autoloader --no-interaction
RUN composer install
RUN php artisan config:cache && \
    php artisan route:cache && \
    chmod 777 -R /var/www/html/storage/ && \
    chown -R www-data:www-data /var/www/html

RUN mkdir -p /var/log/supervisor && \
    chown -R $user:$user /var/log/supervisor

RUN mkdir -p /var/run/supervisor && \
    chown -R $user:$user /var/run/supervisor

# Definir o grupo do diretório /var/run como o mesmo grupo do usuário "expediente"
RUN chgrp -R $user /var/run

# Permitir que o grupo tenha permissão de escrita no diretório /var/run
RUN chmod g+w /var/run

# Copiar o arquivo de configuração do Supervisor
COPY docker/supervisor/websockets.conf /etc/supervisor/conf.d/websockets.conf

# Definir a variável de ambiente SUPERVISOR_LOGLEVEL para evitar erros de permissão de log
ENV SUPERVISOR_LOGLEVEL=info

# Expor a porta 80 e para permitir o acesso ao servidor Apache
EXPOSE 80
EXPOSE 6001

# Iniciar o servidor Apache e o Supervisor quando o contêiner for executado
#CMD ["supervisord", "-n"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/websockets.conf"]