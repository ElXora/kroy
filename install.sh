#!/bin/bash

echo "=================================="
echo " Pterodactyl Auto Installer"
echo "=================================="

read -p "Enter Panel URL (Codespace URL): " APP_URL
read -p "Enter Admin Username: " ADMIN_USER
read -p "Enter Admin Email: " ADMIN_EMAIL
read -s -p "Enter Admin Password: " ADMIN_PASS
echo
read -s -p "Enter Database Password: " DB_PASS
echo

mkdir -p ~/pterodactyl/panel
cd ~/pterodactyl/panel || exit

cat > docker-compose.yml <<EOF
version: '3.8'

x-common:
  database:
    &db-environment
    MYSQL_PASSWORD: &db-password "$DB_PASS"
    MYSQL_ROOT_PASSWORD: "$DB_PASS"

  panel:
    &panel-environment
    APP_URL: "$APP_URL"
    APP_TIMEZONE: "UTC"
    APP_SERVICE_AUTHOR: "$ADMIN_EMAIL"
    TRUSTED_PROXIES: "*"

  mail:
    &mail-environment
    MAIL_FROM: "$ADMIN_EMAIL"
    MAIL_DRIVER: "smtp"
    MAIL_HOST: "mail"
    MAIL_PORT: "1025"
    MAIL_USERNAME: ""
    MAIL_PASSWORD: ""
    MAIL_ENCRYPTION: "true"

services:
  database:
    image: mariadb:10.5
    restart: always
    command: --default-authentication-plugin=mysql_native_password
    volumes:
      - "./database:/var/lib/mysql"
    environment:
      <<: *db-environment
      MYSQL_DATABASE: "panel"
      MYSQL_USER: "pterodactyl"

  cache:
    image: redis:alpine
    restart: always

  panel:
    image: ghcr.io/pterodactyl/panel:latest
    restart: always
    ports:
      - "80:80"
      - "443:443"
    links:
      - database
      - cache
    volumes:
      - "./var/:/app/var/"
      - "./logs/:/app/storage/logs"
    environment:
      <<: [*panel-environment, *mail-environment]
      DB_PASSWORD: *db-password
      APP_ENV: "production"
      APP_ENVIRONMENT_ONLY: "false"
      CACHE_DRIVER: "redis"
      SESSION_DRIVER: "redis"
      QUEUE_DRIVER: "redis"
      REDIS_HOST: "cache"
      DB_HOST: "database"
      DB_PORT: "3306"

networks:
  default:
    ipam:
      config:
        - subnet: 172.20.0.0/16
EOF

echo "Starting Docker containers..."
docker-compose up -d

echo "Waiting for database..."
sleep 60

echo "Running migrations..."
docker-compose run --rm panel php artisan migrate --seed --force

echo "Creating admin account..."

docker-compose run --rm panel php artisan p:user:make \
  --email="$ADMIN_EMAIL" \
  --username="$ADMIN_USER" \
  --name-first="Admin" \
  --name-last="User" \
  --password="$ADMIN_PASS" \
  --admin=1

echo "=================================="
echo " Installation Complete!"
echo "=================================="
echo "Panel URL: $APP_URL"
echo "Username: $ADMIN_USER"
