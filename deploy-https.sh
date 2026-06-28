#!/usr/bin/env bash
set -u

SITE=/var/www/rh1998-pdd-playbook
CONF=/etc/nginx/sites-available/rh1998-pdd-playbook.conf
ENABLED=/etc/nginx/sites-enabled/rh1998-pdd-playbook.conf
CERT=/etc/letsencrypt/live/rh1998.com/fullchain.pem
KEY=/etc/letsencrypt/live/rh1998.com/privkey.pem

echo RH_HTTPS_START

cat > "$CONF" <<'NGINX_HTTP'
server {
    listen 80;
    listen [::]:80;
    server_name rh1998.com www.rh1998.com;

    root /var/www/rh1998-pdd-playbook;
    index index.html;

    access_log /var/log/nginx/rh1998-pdd-playbook.access.log;
    error_log /var/log/nginx/rh1998-pdd-playbook.error.log;

    location ^~ /.well-known/acme-challenge/ {
        root /var/www/rh1998-pdd-playbook;
        default_type "text/plain";
        allow all;
    }

    location / {
        try_files $uri $uri/ /index.html;
    }

    location ~ /\.(?!well-known) {
        deny all;
    }
}
NGINX_HTTP

ln -sfn "$CONF" "$ENABLED"
nginx -t && systemctl reload nginx

if ! command -v certbot >/dev/null 2>&1; then
    echo CERTBOT_MISSING
    echo HTTPS_INSTALLED=0
    exit 0
fi

certbot --version || true
timeout 300 certbot certonly --webroot -w "$SITE" --cert-name rh1998.com \
    -d rh1998.com -d www.rh1998.com \
    --non-interactive --agree-tos --register-unsafely-without-email \
    --preferred-challenges http --keep-until-expiring
CB=$?
echo CERTBOT_EXIT=$CB

if [ "$CB" = "0" ] && [ -f "$CERT" ] && [ -f "$KEY" ]; then
    cat > "$CONF" <<'NGINX_SSL'
server {
    listen 80;
    listen [::]:80;
    server_name rh1998.com www.rh1998.com;

    root /var/www/rh1998-pdd-playbook;

    location ^~ /.well-known/acme-challenge/ {
        root /var/www/rh1998-pdd-playbook;
        default_type "text/plain";
        allow all;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name rh1998.com www.rh1998.com;

    root /var/www/rh1998-pdd-playbook;
    index index.html;

    access_log /var/log/nginx/rh1998-pdd-playbook.access.log;
    error_log /var/log/nginx/rh1998-pdd-playbook.error.log;

    ssl_certificate /etc/letsencrypt/live/rh1998.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/rh1998.com/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location ~* \.(?:css|js|png|jpg|jpeg|gif|svg|webp|ico)$ {
        expires 7d;
        add_header Cache-Control "public";
        try_files $uri =404;
    }

    location ~ /\. {
        deny all;
    }
}
NGINX_SSL
    nginx -t && systemctl reload nginx
    echo HTTPS_INSTALLED=1
    curl -m 8 -sSI --resolve www.rh1998.com:443:127.0.0.1 https://www.rh1998.com/ | sed -n '1,8p'
else
    echo HTTPS_INSTALLED=0
fi

echo HN_CHECK
grep -R "server_name hnkjtk.com www.hnkjtk.com" -n /etc/nginx/sites-enabled /etc/nginx/sites-available 2>/dev/null | sed -n '1,10p'
echo RH_HTTPS_END
