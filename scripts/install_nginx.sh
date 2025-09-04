#!/bin/bash

# Update package list
sudo apt-get update

# Install Nginx
sudo apt-get install -y nginx

# Start Nginx service
sudo systemctl start nginx

# Enable Nginx to start on boot
sudo systemctl enable nginx

# Adjust firewall to allow HTTP traffic
sudo ufw allow 'Nginx HTTP'
