#!/bin/bash

echo "=================================="
echo " Pterodactyl Auto Installer (FIXED)"
echo "=================================="

read -p "Panel URL: " APP_URL
read -p "Admin Username: " ADMIN_USER
read -p "Admin Email: " ADMIN_EMAIL
read -s -p "Admin Password: " ADMIN_PASS
echo
read -s -p "Database Password: " DB_PASS
echo

mkdir -p ~/pterodactyl/panel
cd ~/pterodactyl/panel || exit

cat > docker-compose.yml <<EOF
services:
  database:
    image: mariadb:10.11
    restart: always
    command: --default-authentication-plugin=mysql_native_password
    environment:
      MYSQL_DATABASE: panel
      MYSQL_USER: pterodactyl
      MYSQL_PASSWORD: $DB_PASS
      MYSQL_ROOT_PASSWORD: $DB_PASS
    volumes:
      - "./database:/var/lib/mysql"

  cache:
    image: redis:alpine
    restart: always

  panel:
    image: ghcr.io/pterodactyl/panel:latest
    restart: always
    ports:
      - "80:80"
      - "443:443"
    environment:
      APP_URL: "$APP_URL"
      APP_ENV: production
      APP_ENVIRONMENT_ONLY: "false"
      APP_TIMEZONE: UTC
      APP_SERVICE_AUTHOR: "$ADMIN_EMAIL"

      DB_HOST: database
      DB_PORT: 3306
      DB_DATABASE: panel
      DB_USERNAME: pterodactyl
      DB_PASSWORD: $DB_PASS

      # 🔥 FIX SSL ERROR
      DB_SSL_MODE: disable
      MYSQL_ATTR_SSL_CA: ""

      CACHE_DRIVER: redis
      SESSION_DRIVER: redis
      QUEUE_DRIVER: redis
      REDIS_HOST: cache

    volumes:
      - "./var:/app/var"
      - "./logs:/app/storage/logs"

networks:
  default:
    ipam:
      config:
        - subnet: 172.20.0.0/16
EOF

echo "Starting containers..."
docker-compose up -d

echo "Waiting for database (real check)..."
until docker-compose exec database mysqladmin ping -h"localhost" --silent; do
  sleep 2
done

echo "Database ready!"

echo "Running migrations..."
docker-compose exec panel php artisan migrate --seed --force

echo "Creating admin user..."
docker-compose exec panel php artisan p:user:make \
  --email="$ADMIN_EMAIL" \
  --username="$ADMIN_USER" \
  --name-first="Admin" \
  --name-last="User" \
  --password="$ADMIN_PASS" \
  --admin=1

echo "=================================="
echo " INSTALL COMPLETE"
echo "=================================="
echo "URL: $APP_URL"
echo "User: $ADMIN_USER"
