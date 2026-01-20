FROM nginx:alpine
COPY . /usr/share/nginx/html
# Remove default index.html to allow autoindex to show file list
RUN rm /usr/share/nginx/html/index.html
# Fix permissions so nginx user can read files
RUN chmod -R a+rX /usr/share/nginx/html
# Enable directory listing
RUN sed -i 's/index  index.html index.htm;/index  index.html index.htm;\n        autoindex on;/' /etc/nginx/conf.d/default.conf
