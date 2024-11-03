#proxy_cache_path /var/cache/nginx/whoami/ levels=1:2
#	             keys_zone=who:10m max_size=1g inactive=60m;

server {
  listen 9000;
  server_name whoami.exemple.com;
  return 301 https://$host:9443$request_uri;
}

upstream whoami {
  server whoami.ddnsking.com:8000 weight=2;
  server whoami.ddnsking.com:8001 max_fails=3 fail_timeout=20s;
  server whoami.ddnsking.com:8002 max_fails=3 fail_timeout=20s;
}

server {
  listen 9443 ssl;
  server_name whoami.exemple.com;

  modsecurity on;
  modsecurity_rules_file /etc/nginx/modsecurity/modsecurity_includes.conf;

  ssl_certificate /etc/nginx/ssl/public.pem;
  ssl_certificate_key /etc/nginx/ssl/private.key;
  ssl_session_timeout 1d;
  ssl_session_cache shared:SSL:50m;
  ssl_session_tickets off;

  ssl_protocols TLSv1.3;
  ssl_ciphers ECDHE-ECDSA-AES256-GCM-SHA384;
  ssl_conf_command Ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256;
  ssl_prefer_server_ciphers on;
  ssl_stapling on;

  add_header Strict-Transport-Security max-age=16768000;

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
