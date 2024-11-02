proxy_cache_path /var/cache/nginx/photos/ levels=1:2
	             keys_zone=photos:10m max_size=1g inactive=60m;

server {
  listen 9000;
  server_name photos.exemple.com;
  return 301 https://$host:9443$request_uri;
}

server {
  listen 9443 ssl;
  server_name photos.exemple.com;

  modsecurity on;
  modsecurity_rules_file /etc/nginx/modsecurity/modsecurity.conf;

  ssl_certificate /etc/nginx/ssl/public.pem;
  ssl_certificate_key /etc/nginx/ssl/private.key;

  client_max_body_size 5m;

  access_log syslog:server=unix:/dev/log vhost;

  location / {
    proxy_pass http://127.0.0.1:3000;
    proxy_http_version 1.1;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_cache photos;
    proxy_cache_valid 60m;
    add_header X-Cache-Status $upstream_cache_status;
  }
  
  location ~* (\.(js|css|jpe?g|png|gif)) {
    root /var/www/photos.exemple.com;
  }     
}
