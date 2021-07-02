#!/bin/sh

# Set env variables
	
	LETSENCRYPT_URL=$LETSENCRYPT_URL
	DOMAIN_DIR=$DOMAIN_DIR
	DOMAIN=$1
	DOMAIN_CERT_DIR=$CERT_DIR/$DOMAIN

service_exec="docker run --rm \
 -v /etc/user/config/user.json:/etc/user/config/user.json:ro \
 -v /etc/user/config/services/:/services/:ro \
 -v /var/run/docker.sock:/var/run/docker.sock \
 -v /usr/bin/docker:/usr/bin/docker:ro registry.format.hu/setup /scripts/service-exec"

letsencrypt_certificates() {
$service_exec /services/letsencrypt.json start
}

create_self_signed_certificate() { 

# generate dhparam file
openssl dhparam -dsaparam -out $DOMAIN_CERT_DIR/dhparam.pem 4096; 

# generate key
openssl req -x509 -newkey rsa:4096 -keyout $DOMAIN_CERT_DIR/key.pem -out $DOMAIN_CERT_DIR/cert.pem -days 365 -sha256 -nodes -subj "/CN=$DOMAIN";
cp -a $DOMAIN_CERT_DIR/cert.pem $DOMAIN_CERT_DIR/fullchain.pem;

}

if [ ! -d "$DOMAIN_CERT_DIR" ]; then
	echo "$DOMAIN not contains certificates, creates new."
	mkdir -p $DOMAIN_CERT_DIR;
	CURL_CHECK="curl -s -o /dev/null -w "%{http_code}" https://$LETSENCRYPT_URL";

	if [[ "$(eval $CURL_CHECK)" != "200" ]] ; then
		create_self_signed_certificate;
	fi
else
	file="$DOMAIN_CERT_DIR/letsencrypt"
	{
	echo "{ \"DOMAIN\": \"$DOMAIN\" }"
	} >> "$file"
	letsencrypt_certificates;
fi

