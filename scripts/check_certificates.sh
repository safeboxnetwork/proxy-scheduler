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

	local RUNNING_CONTAINERS;

	cd /

	# Check services with running containers by roles
	for CONTAINER in $(jq -r --arg ROLE $ROLE '.containers[] | select(.ROLES==$ROLE)' /$PROXY_SERVICE_FILE | jq -r .NAME) ; do
		UP=$(docker ps | grep $CONTAINER | grep Up | wc -l)
		RUNNING_CONTAINERS=$((RUNNING_CONTAINERS + UP))
	done;

	# In case of no running proxies found, try to start the service
	if [[ "$RUNNING_CONTAINERS" -eq 0 ]] ; then 
		echo "No running proxies found, create self signed cetificate";
		create_self_signed_certificate;
	fi;

	$service_exec /services/letsencrypt.json start
}

create_self_signed_certificate() { 

# generate key
openssl req -x509 -newkey rsa:4096 -keyout $DOMAIN_CERT_DIR/key.pem -out $DOMAIN_CERT_DIR/cert.pem -days 365 -sha256 -nodes -subj "/CN=$DOMAIN";
cp -a $DOMAIN_CERT_DIR/cert.pem $DOMAIN_CERT_DIR/fullchain.pem;

}

if [ ! -d "$DOMAIN_CERT_DIR" ]; then
	echo "$DOMAIN not contains certificates, creates new."
	mkdir -p $DOMAIN_CERT_DIR;
fi

if [ ! -f "$DOMAIN_CERT_DIR/dhparam.pem" ]; then
	# generate dhparam file
	openssl dhparam -dsaparam -out $DOMAIN_CERT_DIR/dhparam.pem 4096; 
fi

CURL_CHECK="curl -s -o /dev/null -w "%{http_code}" https://$LETSENCRYPT_URL";

if [[ "$(eval $CURL_CHECK)" != "200" ]] ; then
	create_self_signed_certificate;
else
	file="$DOMAIN_CERT_DIR/letsencrypt"
	{
	echo "{ \"DOMAIN\": \"$DOMAIN\" }"
	} >> "$file"
	letsencrypt_certificates;
fi


