#proxy_cache_path /var/cache/nginx/whoami/ levels=1:2
#	             keys_zone=who:10m max_size=1g inactive=60m;

server {
  listen 9000;
  server_name whoami.exemple.com;
  return 301 https://$host:9443$request_uri;
}

upstream whoami {
  server 127.0.0.1:8000 weight=2;
  server 127.0.0.1:8001 max_fails=3 fail_timeout=20s;
  server 127.0.0.1:8002 max_fails=3 fail_timeout=20s;
}

server {
  listen 9443 ssl;
  server_name whoami.exemple.com;

  modsecurity on;
  modsecurity_rules_file /etc/nginx/modsecurity/modsecurity.conf;

  ssl_certificate /etc/nginx/ssl/public.pem;
  ssl_certificate_key /etc/nginx/ssl/private.key;

  access_log syslog:server=unix:/dev/log vhost;

  location / {
    proxy_pass http://whoami;
    proxy_http_version 1.1;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    #   proxy_cache who;
    #proxy_cache_valid 60m;
    add_header X-Cache-Status $upstream_cache_status;
  }
  
  #location ~* (\.(js|css|jpe?g|png|gif)) {
  #  root /var/www/photos.exemple.com;
  #}     
}
