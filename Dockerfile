# Serves the Godot Web export produced by tools/export-web.sh. The build is made
# outside the image (docker.yml exports it once and shares the artifact), so this image
# only serves.
FROM nginx:1.27-alpine

COPY docker/nginx.conf /etc/nginx/nginx.conf
COPY docker/entrypoint.sh /entrypoint.sh
COPY build/web /srv/web

RUN chmod +x /entrypoint.sh

EXPOSE 8080
ENTRYPOINT ["/entrypoint.sh"]
