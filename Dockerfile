FROM alpine
RUN apk add --update --no-cache docker-cli inotify-tools openssl jq curl ca-certificates busybox-extras
COPY scripts /scripts
COPY firewall-letsencrypt.json /firewall-files/

ENTRYPOINT ["/scripts/scheduler.sh"]
