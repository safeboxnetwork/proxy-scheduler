FROM proxy-scheduler:latest
COPY scripts /scripts
COPY firewall-letsencrypt.json /firewall-files

ENTRYPOINT ["/scripts/scheduler.sh"]
