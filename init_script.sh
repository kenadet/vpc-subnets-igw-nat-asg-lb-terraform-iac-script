#!/bin/sh
sudo apt-get update -y

sudo apt-get install -y busybox

sudo mkdir -p /var/www

sudo chown -R ubuntu  /var/www

# Create a basic HTML page
sudo echo "<html><body><h1>Hello, World!</h1></body></html>" > /var/www/index.html

sudo ufw allow 80/tcp

sudo ufw enable

# Start BusyBox HTTP server
busybox httpd -f -p 80 -h /var/www &