# /bin/bash

echo "Updating dependencies..."
docker compose exec server composer update

echo "Copying updated composer files to host..."
docker compose cp server:/var/www/html/composer.lock ./composer.lock
