server {
  listen 9000;
  server_name example.com www.example.com;
  root /var/www/example.com/html;
}
