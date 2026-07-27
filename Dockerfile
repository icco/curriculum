# syntax=docker/dockerfile:1
#
# Serves the Godot web export as a static site. The export is built outside the
# image (needs the editor plus ~1GB of templates) and is platform independent:
#
#   ./tools/export-web.sh && docker build -t curriculum .
#   docker run --rm -p 8080:8080 curriculum

FROM nginx:1.27-alpine

LABEL org.opencontainers.image.title="Curriculum"
LABEL org.opencontainers.image.description="2.5D isometric turn-based tactical roguelike, playable in a browser"
LABEL org.opencontainers.image.source="https://github.com/icco/curriculum"
LABEL org.opencontainers.image.licenses="MIT"

COPY docker/nginx.conf /etc/nginx/nginx.conf
COPY build/web/ /usr/share/nginx/html/

# Unprivileged and listening high, so it runs anywhere without extra caps.
RUN chown -R nginx:nginx /usr/share/nginx/html /var/cache/nginx \
	&& touch /tmp/nginx.pid && chown nginx:nginx /tmp/nginx.pid
USER nginx
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s \
	CMD wget -q -O /dev/null http://127.0.0.1:8080/index.html || exit 1

CMD ["nginx", "-g", "daemon off;"]
