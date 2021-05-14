FROM scheduler:latest

COPY scripts /scripts

ENTRYPOINT ["/scripts/scheduler.sh"]
