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

  location / {
    proxy_pass http://127.0.0.1:3000;
    proxy_http_version 1.1;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
  }
  
  location ~* (\.(js|css|jpe?g|png|gif)) {
    root /var/www/photos.exemple.com;
  }     
}
