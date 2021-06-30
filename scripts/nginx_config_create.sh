#!/bin/sh

JQ="jq -r"

DOMAIN=$1
DEL=$2
if [[ "$DEL" != "" ]]; then
	echo "$DOMAIN DELETED";
	exit;
fi

DOMAIN_SOURCE=/domains/$DOMAIN

DOMAIN_NAME=$(jq -r .DOMAIN $DOMAIN_SOURCE)
HTTP_PORT=$(jq -r .HTTP_PORT $DOMAIN_SOURCE)
HTTPS_PORT=$(jq -r .HTTPS_PORT $DOMAIN_SOURCE)
LOCAL_IP=$(jq -r .LOCAL_IP $DOMAIN_SOURCE)
ALIASES_HTTP=$(jq -r .ALIASES_HTTP $DOMAIN_SOURCE)
ALIASES_HTTPS=$(jq -r .ALIASES_HTTPS $DOMAIN_SOURCE)
REDIRECT_HTTP=$(jq -r .REDIRECT_HTTP $DOMAIN_SOURCE)
REDIRECT_HTTPS=$(jq -r .REDIRECT_HTTPS $DOMAIN_SOURCE)
ERROR_PAGE=$(jq -r .ERROR_PAGE $DOMAIN_SOURCE)

echo $DOMAIN;
exit;

cd /proxy_config

file="$DOMAIN.conf"

cp -a nginx_template.conf $DOMAIN.conf

{

if [ $HTTP_PORT != "" ]; then
	echo "server {
listen $HTTP_PORT;
server_name $DOMAIN_NAME;
rewrite_log on"
fi

echo

if [[ $REDIRECT_HTTP != "" ]]; then
	echo "return 301 http://$REDIRECT_HTTP;
 }"
elif [[ $REDIRECT_HTTPS != "" ]]; then
	echo "return 301 https://$REDIRECT_HTTPS;
 }"
	else
		if [[ $ERROR_PAGE != "" ]]; then
		echo "error_page 404 /$ERROR_PAGE;
location = /$ERROR_PAGE {
      root    html;
      allow   all;
      index   404.html
      rewrite ^ "'$scheme'"http://$ERROR_PAGE"'$request_uri'" permanent;
              }"
		fi
	echo "location / {
 proxy_pass http://$LOCAL_IP:$HTTP_PORT;
 proxy_redirect off;
 proxy_buffering off;
 proxy_set_header X-Forwarded-For "'$proxy_add_x_forwarded_for'";
 proxy_set_header Upgrade "'$http_upgrade'";
 proxy_set_header Connection "'$http_connection'";
 proxy_cookie_path / /;
 access_log off;
 }"
fi

if [[ $HTTPS_PORT == "" ]] ; then
	echo "}"
fi

if [ $HTTPS_PORT != "" ]; then
	echo "server {
listen $HTTPS_PORT ssl;
server_name $DOMAIN_NAME;
rewrite_log on
proxy_ssl_server_name on; 
ssl_dhparam /etc/ssl/keys/dhparams.pem;
 ssl_certificate /etc/ssl/keys/fullchain.pem;
 ssl_certificate_key /etc/ssl/keys/key.pem;
 ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
 ssl_prefer_server_ciphers on;
 ssl_ciphers "'"EECDH+ECDSA+AESGCM EECDH+aRSA+AESGCM EECDH+ECDSA+SHA384 EECDH+ECDSA+SHA256 EECDH+aRSA+SHA384 EECDH+aRSA+SHA256 EECDH+aRSA+RC4 EECDH EDH+aRSA RC4 !aNULL !eNULL !LOW !3DES !MD5 !EXP !PSK !SRP !DSS !RC4"'";

 # Hardening as-per https://gist.github.com/plentz/6737338
ssl_session_cache shared:SSL:50m;
ssl_session_timeout 5m;
ssl_stapling on;"
fi

echo

if [[ $ERROR_PAGE != "" ]]; then
	echo "error_page 404 /$ERROR_PAGE;
location = /$ERROR_PAGE {
      root    html;
      allow   all;
      index   404.html
      rewrite ^ "'$scheme'" http://$ERROR_PAGE"'$request_uri'" permanent;
              }"
fi
echo 

echo "location / {
 proxy_pass http://$LOCAL_IP:$HTTP_PORT;
 proxy_redirect off;
 proxy_buffering off;
 proxy_set_header X-Forwarded-For "'$proxy_add_x_forwarded_for'";
 proxy_set_header Upgrade "'$http_upgrade'";
 proxy_set_header Connection "'$http_connection'";
 proxy_cookie_path / /;
 access_log off;
 } 
}"

} >> "$file"

# check whether certificates exist or not

if [ $HTTPS_PORT != "" ]; then
	./check_certificates.sh;
fi


