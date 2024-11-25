#!/bin/sh

# Initial parameters
DATE=$(date +%F-%H-%M-%S)

DOMAIN=$1

# Set env variables
DOMAIN_DIR=$DOMAIN_DIR
PROXY_CONFIG_DIR=$PROXY_CONFIG_DIR

cd $DOMAIN_DIR
file="$PROXY_CONFIG_DIR/haproxy.cfg"

global_http="/scripts/global_http"
global_https="/scripts/global_https"

cp -a /scripts/haproxy_template.cfg $PROXY_CONFIG_DIR/haproxy.cfg

{

    echo "frontend http
"

    cat "$global_http"
    echo

    #echo "acl letsencrypt path_beg /.well-known/acme-challenge/";

    echo

    for i in $(ls $DOMAIN_DIR | cut -d / -f2); do

        DOMAIN_NAME=$(jq -r .DOMAIN $i)
        if [[ "$(jq -r .REDIRECT_HTTPS $i)" != "" && "$(jq -r .HTTP_PORT $i)" != "" && "$DOMAIN_NAME" != "letsencrypt" ]]; then
            echo "redirect prefix https://$(jq -r .REDIRECT_HTTPS $i) code 301 if { hdr(host) -i $DOMAIN_NAME }"
        fi
    done
    echo

    for i in $(ls $DOMAIN_DIR | cut -d / -f2); do

        DOMAIN_NAME=$(jq -r .DOMAIN $i)
        if [[ "$DOMAIN_NAME" != "" && "$(jq -r .HTTP_PORT $i)" != "" && "$DOMAIN_NAME" != "letsencrypt" ]]; then

            TLD="$(echo $DOMAIN_NAME | rev | cut -d '.' -f1 | rev)"
            WILDCARD=$(echo $DOMAIN_NAME | grep '*')

            if [ "$WILDCARD" != "" ]; then
                HOST=$(echo $DOMAIN_NAME | rev | cut -d '.' -f2- | rev | cut -d '.' -f2-)
                echo "acl $HOST."$TLD"_http hdr(host) -m reg -i ^[^\.]+\."$HOST"\."$TLD"$"
            else
                echo "acl "$DOMAIN_NAME"_http hdr(host) -i $DOMAIN_NAME"
            fi
        fi

        if [[ "$DOMAIN_NAME" != "letsencrypt" && "$(jq -r .HTTP_PORT $i)" != "" && "$(jq -r .ALIASES_HTTP[] $i)" != "" ]]; then
            ALIASES_LIST=$(jq -r .ALIASES_HTTP[] $i)
            for ALIAS in $ALIASES_LIST; do
                echo "acl "$DOMAIN_NAME"_http hdr(host) -i $ALIAS"
            done
        fi

    done

    echo

    #echo "use_backend letsencrypt_http if letsencrypt"

    for i in $(ls $DOMAIN_DIR | cut -d / -f2); do

        DOMAIN_NAME=$(jq -r .DOMAIN $i)
        TLD="$(echo $DOMAIN_NAME | rev | cut -d '.' -f1 | rev)"

        if [[ "$DOMAIN_NAME" != "" && "$(jq -r .HTTP_PORT $i)" != "" && "$DOMAIN_NAME" != "letsencrypt" ]]; then
            if [ "$WILDCARD" != "" ]; then
                HOST=$(echo $DOMAIN_NAME | rev | cut -d '.' -f2- | rev | cut -d '.' -f2-)
                echo "use_backend host_"$HOST".$TLD if $HOST."$TLD"_http"
            else
                echo "use_backend host_"$DOMAIN_NAME" if "$DOMAIN_NAME"_http"
            fi
        fi
    done

    echo

    for i in $(ls $DOMAIN_DIR | cut -d / -f2); do

        DOMAIN_NAME=$(jq -r .DOMAIN $i)
        TLD="$(echo $DOMAIN_NAME | rev | cut -d '.' -f1 | rev)"

        if [[ "$DOMAIN_NAME" != "" && "$(jq -r .HTTP_PORT $i)" != "" ]]; then
            if [ "$WILDCARD" != "" ]; then
                HOST=$(echo $DOMAIN_NAME | rev | cut -d '.' -f2- | rev | cut -d '.' -f2-)
                echo "backend host_"$HOST."$TLD"
                echo "	mode http"
                echo "	server $HOST.$TLD $(jq -r .LOCAL_NAME $i):$(jq -r .HTTP_PORT $i) send-proxy"
            else
                echo "backend host_"$DOMAIN_NAME
                echo "	mode http"
                echo "	server $DOMAIN_NAME $(jq -r .LOCAL_NAME $i):$(jq -r .HTTP_PORT $i) send-proxy"
            fi
        fi
    done

    echo

    echo "frontend https
"

    cat "$global_https"
    echo

    for i in $(ls $DOMAIN_DIR | cut -d / -f2); do
        DOMAIN_NAME=$(jq -r .DOMAIN $i)
        TLD="$(echo $DOMAIN_NAME | rev | cut -d '.' -f1 | rev)"
        WILDCARD=$(echo $DOMAIN_NAME | grep '*')

        if [[ "$DOMAIN_NAME" != "" && "$(jq -r .HTTPS_PORT $i)" != "" && "$DOMAIN_NAME" != "letsencrypt" ]]; then

            if [ "$WILDCARD" != "" ]; then
                HOST=$(echo $DOMAIN_NAME | rev | cut -d '.' -f2- | rev | cut -d '.' -f2-)
                echo "acl $HOST."$TLD"_https req_ssl_sni -i ^[^\.]+\.$HOST\."$TLD"$"
            else
                echo "acl "$DOMAIN_NAME"_https req_ssl_sni -i $DOMAIN_NAME"
            fi
        fi
        if [[ "$(jq -r .HTTPS_PORT $i)" != "" && "$(jq -r .ALIASES_HTTPS[] $i)" != "" ]]; then
            ALIASES_LIST=$(jq -r .ALIASES_HTTPS[] $i)
            for ALIAS in $ALIASES_LIST; do
                echo "acl $HOST."$TLD"_https req_ssl_sni -i $ALIAS"
            done
        fi
    done

    echo

    for i in $(ls $DOMAIN_DIR | cut -d / -f2); do
        DOMAIN_NAME=$(jq -r .DOMAIN $i)
        TLD="$(echo $DOMAIN_NAME | rev | cut -d '.' -f1 | rev)"
        WILDCARD=$(echo $DOMAIN_NAME | grep '*')

        if [[ "$DOMAIN_NAME" != "" && "$(jq -r .HTTPS_PORT $i)" != "" && "$DOMAIN_NAME" != "letsencrypt" ]]; then
            if [ "$WILDCARD" != "" ]; then
                HOST=$(echo $DOMAIN_NAME | rev | cut -d '.' -f2- | rev | cut -d '.' -f2-)
                echo "use_backend host_"$HOST".$TLD if $HOST."$TLD"_https"
            else
                echo "use_backend host_"$DOMAIN_NAME" if "$DOMAIN_NAME"_https"
            fi
        fi
    done

    echo

    for i in $(ls $DOMAIN_DIR | cut -d / -f2); do

        if [[ "$DOMAIN_NAME" != "" && "$(jq -r .HTTPS_PORT $i)" != "" && "$DOMAIN_NAME" != "letsencrypt" ]]; then
            DOMAIN_NAME=$(jq -r .DOMAIN $i)
            TLD="$(echo $DOMAIN_NAME | rev | cut -d '.' -f1 | rev)"
            WILDCARD=$(echo $DOMAIN_NAME | grep '*')
            if [ "$WILDCARD" != "" ]; then
                HOST=$(echo $DOMAIN_NAME | rev | cut -d '.' -f2- | rev | cut -d '.' -f2-)
                echo "backend host_"$HOST".$TLD"
                echo "	option ssl-hello-chk"
                echo "	mode tcp"
                echo "	server $HOST.$TLD $(jq -r .LOCAL_NAME $i):$(jq -r .HTTPS_PORT $i) check send-proxy"
            else
                echo "backend host_"$DOMAIN_NAME
                echo "	option ssl-hello-chk"
                echo "	mode tcp"
                echo "	server $DOMAIN_NAME $(jq -r .LOCAL_NAME $i):$(jq -r .HTTPS_PORT $i) check send-proxy"
            fi
        fi
    done

} >>"$file"
echo "$DOMAIN" >>$PROXY_CONFIG_DIR/new_config
