#!/bin/sh
set -eu
test -s /srv/web/index.html || { echo "no web build at /srv/web" >&2; exit 1; }
exec nginx -g 'daemon off;'
