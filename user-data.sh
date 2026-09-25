#!/bin/bash
apt-get update -y
apt-get install -y nginx
systemctl start nginx
systemctl enable nginx
echo "OK" > /var/www/html/health
echo "<h1>Welcome to AWS Web Infrastructure Mission!</h1><p>Status: 200 OK</p>" > /var/www/html/index.html
