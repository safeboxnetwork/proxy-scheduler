#!/bin/sh

cd /proxy_config

DOMAIN=$1
if [ -n "$2" ]; then
	echo "$DOMAIN DELETED";
	rm $DOMAIN.conf;
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

# check whether certificates exist or not

if [[ $HTTPS_PORT != "" ]]; then
	/scripts/check_certificates.sh "$DOMAIN";
fi

echo "created domain name: "$DOMAIN;

file="/tmp/$DOMAIN.conf"

#cp -a /scripts/nginx_template.conf /tmp/$DOMAIN.conf

{

if [[ $HTTP_PORT != "" ]]; then
	echo "server {
listen $HTTP_PORT;
server_name $DOMAIN_NAME;
rewrite_log on;"

echo

	if [[ $REDIRECT_HTTP != "" && $HTTP_PORT != "" ]]; then
		echo "return 301 $REDIRECT_HTTP;"

	elif [[ $REDIRECT_HTTPS != "" && $HTTP_PORT != "" ]]; then
		echo "return 301 $REDIRECT_HTTPS;"

	else
		if [[ $ERROR_PAGE != "" && $HTTP_PORT != "" ]]; then
			echo "error_page 404 /$ERROR_PAGE;
location = /$ERROR_PAGE {
      root    html;
      allow   all;
      index   404.html;
      rewrite ^ "'$scheme'" http://$ERROR_PAGE"'$request_uri'" permanent;
              }"
		fi
	fi
	echo "location / {"
	
	if [[ $HTTP_PORT != "" ]]; then
 		echo "proxy_pass http://$LOCAL_IP:$HTTP_PORT;"
	else
 		echo "proxy_pass http://$LOCAL_IP:80;"
	fi

 echo "proxy_redirect off;
 proxy_buffering off;
 proxy_set_header X-Forwarded-For "'$proxy_add_x_forwarded_for'";
 proxy_set_header Upgrade "'$http_upgrade'";
 proxy_set_header Connection "'$http_connection'";
 proxy_cookie_path / /;
 access_log off;
 }
}"
fi

if [[ $HTTPS_PORT != "" ]]; then
	echo "server {
listen $HTTPS_PORT ssl;
server_name $DOMAIN_NAME;
rewrite_log on;
proxy_ssl_server_name on; 
ssl_dhparam /etc/ssl/keys/$DOMAIN/dhparam.pem;
 ssl_certificate /etc/ssl/keys/$DOMAIN/fullchain.pem;
 ssl_certificate_key /etc/ssl/keys/$DOMAIN/key.pem;
 ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
 ssl_prefer_server_ciphers on;
 ssl_ciphers "'"EECDH+ECDSA+AESGCM EECDH+aRSA+AESGCM EECDH+ECDSA+SHA384 EECDH+ECDSA+SHA256 EECDH+aRSA+SHA384 EECDH+aRSA+SHA256 EECDH+aRSA+RC4 EECDH EDH+aRSA RC4 !aNULL !eNULL !LOW !3DES !MD5 !EXP !PSK !SRP !DSS !RC4"'";

 # Hardening as-per https://gist.github.com/plentz/6737338
ssl_session_cache shared:SSL:50m;
ssl_session_timeout 5m;
ssl_stapling on;"

echo

	if [[ $ERROR_PAGE != "" && $HTTPS_PORT != "" ]]; then
		echo "error_page 404 /$ERROR_PAGE;
location = /$ERROR_PAGE {
      root    html;
      allow   all;
      index   404.html;
      rewrite ^ "'$scheme'":http://$ERROR_PAGE"'$request_uri'" permanent;
              }"
	fi

echo "location / {"

	if [[ $HTTP_PORT != "" ]]; then
		echo "proxy_pass http://$LOCAL_IP:$HTTP_PORT;"
	else
		echo "proxy_pass http://$LOCAL_IP:80;"
	fi
 
echo "proxy_redirect off;
 proxy_buffering off;
 proxy_set_header X-Forwarded-For "'$proxy_add_x_forwarded_for'";
 proxy_set_header Upgrade "'$http_upgrade'";
 proxy_set_header Connection "'$http_connection'";
 proxy_cookie_path / /;
 access_log off;
}
}"
fi

} >> "$file"

mv /tmp/$DOMAIN.conf $DOMAIN.conf;
echo "$DOMAIN" >> new_config
