# Use the maintained Synapse administration UI, served alongside a local API proxy.
FROM ghcr.io/etkecc/ketesa:latest AS ui
FROM nginx:stable-alpine
COPY --from=ui /home/sws/public/ /usr/share/nginx/html/
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s CMD wget -q -O /dev/null http://127.0.0.1:8080/health || exit 1
