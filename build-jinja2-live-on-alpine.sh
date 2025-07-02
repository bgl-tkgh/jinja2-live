# ----------------------
#
# build-jinja2-live-on-alpine.sh
#
# A setup script to install and configure the Jinja2-Live application
# on an Alpine Linux VM. This script installs required packages, clones the
# application from GitHub, configures Flask and Nginx, and sets up an OpenRC
# service to run the app automatically at startup.
#
# VM requirements: 1Gb RAM, 8Gb Hard Disk and 1 CPU, Tested on Aline 3.21
#
# Author: Ph. Jounin
# ----------------------
set -e

echo " Updating and installing packages..."
apk update && apk upgrade
apk add git curl python3 py3-pip 
apk add py3-flask py3-jinja2 py3-netaddr py3-jmespath py3-yaml

echo "... Cloning the Jinja2 Live Parser..."
git clone https://github.com/PJO2/jinja2-live /opt/jinja2-live

# ----------------------
# configure nginx as reverse proxy 
# ----------------------
apk add nginx

# Create Self Signed Certificate for NginX
mkdir -p /etc/ssl/jinja2-live
openssl req -x509 -nodes -days 3650 \
  -newkey rsa:2048 \
  -keyout /etc/ssl/jinja2-live/jinja2-live.key \
  -out /etc/ssl/jinja2-live/jinja2-live.crt \
  -subj "/C=FR/ST=France/L=Lyon/O=Jinja2-live/OU=Live/CN=jinja2-live.local"


echo "... Configuring Nginx reverse proxy..."
cat > /etc/nginx/http.d/jinja2-live.conf <<EOF
# Jinja2-live server 
server {
    listen 443 ssl;
    server_name jinja2-live.local;

    ssl_certificate     /etc/ssl/jinja2-live/jinja2-live.crt;
    ssl_certificate_key /etc/ssl/jinja2-live/jinja2-live.key;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}

server {
    listen 80;
    server_name localhost;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF
echo "... And disable default server..."
mv /etc/nginx/http.d/default.conf /etc/nginx/http.d/default.conf.unused

echo "Now Enabling and starting Nginx..."
rc-update add nginx
rc-service nginx start

# ----------------------
# register jinja2-live as a service
# ----------------------

echo "... Setting up OpenRC service for Jinja2-live app..."
cat > /etc/init.d/jinja2-live <<EOF
#!/sbin/openrc-run

command="/usr/bin/python3"
command_args="/opt/jinja2-live/parser.py"
directory="/opt/jinja2-live"
command_background=true
pidfile="/var/run/jinja2-live.pid"
name="jinja2-live"
description="Flask app for Jinja2 parser"
# Restrict flask to localhost
export HOST=127.0.0.1
export PORT=8080
EOF

echo "... Starting jinja2-live ..."

chmod +x /etc/init.d/jinja2-live
rc-update add jinja2-live
rc-service jinja2-live start

# ----------------------
# Display happy ending report
# ----------------------

# ... Show the real IP address
IP=$(ip -4 addr show eth0 | awk '/inet / {print $2}' | cut -d/ -f1)

if [ -z "$IP" ]; then
  # Try default route interface as fallback
  IFACE=$(ip route | awk '/default/ {print $5}' | head -n1)
  IP=$(ip -4 addr show "$IFACE" | awk '/inet / {print $2}' | cut -d/ -f1)
fi

echo "... Setup complete! App is running at http://$IP:80 and https://$IP:443"
