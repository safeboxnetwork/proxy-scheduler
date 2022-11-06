#!/bin/sh

# Set env variables

	SERVICE_FILES=$SERVICE_FILES
	GENERATE_CERTIFICATE=$GENERATE_CERTIFICATE
	DOCKER_REGISTRY_URL=$DOCKER_REGISTRY_URL
	LETSENCRYPT_URL=$LETSENCRYPT_URL
	LETSENCRYPT_SERVICE_NAME=$LETSENCRYPT_SERVICE_NAME
	CERT_DIR=$CERT_DIR
	DOMAIN_DIR=$DOMAIN_DIR
	DOMAIN=$1
	DOMAIN_CERT_DIR=$CERT_DIR/$DOMAIN
	TIMEOUT=$TIMEOUT
	RESTART=$RESTART

# Setup docker registry url path

if [[ -n "$DOCKER_REGISTRY_URL" && "$DOCKER_REGISTRY_URL" != "null" ]] ; then
	SETUP="/setup";
else
	SETUP="setup";
	DOCKER_REGISTRY_URL="";
fi

# Setting service files path

if [ "$SERVICE_FILES" == "" ]; then
	SERVICE_FILES=/etc/user/config/services
fi

service_exec="docker run --rm \
 -w /services/ \
 -v $SERVICE_FILES/:/services/:ro \
 -v $SERVICE_FILES/tmp/:/services/tmp/:rw \
 -v /var/run/docker.sock:/var/run/docker.sock \
 -v /usr/bin/docker:/usr/bin/docker:ro  \
 --env DOCKER_REGISTRY_URL=$DOCKER_REGISTRY_URL $DOCKER_REGISTRY_URL$SETUP"

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
	fi;
	
	LETS_ENCRYPT_VALUE="$(docker ps | grep letsencrypt | grep Up | wc -l)";
	
	for retries in $(seq 0 $((RESTART + 1))); do
		if [[ $retries -le $RESTART ]] ; then
	
			if [[ $LETS_ENCRYPT_VALUE -eq 0 ]] ; then
				echo "Starting letsencrypt process";
				$service_exec $LETSENCRYPT_SERVICE_NAME start ;
				break;
			else
				echo "Waiting "$TIMEOUT" second for previous letsencrypt process ending";
				sleep $TIMEOUT;

				echo "Not reached number of restart limit: "$RESTART" sleep "$TIMEOUT" and try again to start lets encrypt process." 
			fi
		else
				echo "Reached retrying limit: "$RESTART" ,giving up to start lets encrypt process, try self sign the certificate";
		fi

	done

}

create_self_signed_certificate() { 

# Check any certificate exxits

	if [[ ! -f $DOMAIN_CERT_DIR/key.pem && ! -f $DOMAIN_CERT_DIR/fullchain.pem && ! -f $DOMAIN_CERT_DIR/cert.pem ]] ; then

# generate key
openssl req -x509 -newkey rsa:4096 -keyout $DOMAIN_CERT_DIR/key.pem -out $DOMAIN_CERT_DIR/cert.pem -days 365 -sha256 -nodes -subj "/CN=$DOMAIN";
cp -a $DOMAIN_CERT_DIR/cert.pem $DOMAIN_CERT_DIR/fullchain.pem;
touch $DOMAIN_CERT_DIR/new_certificate;

	fi

}

if [ ! -d "$DOMAIN_CERT_DIR" ]; then
	echo "$DOMAIN not contains certificates, creates new."
	mkdir -p $DOMAIN_CERT_DIR;
fi

if [ ! -f "$DOMAIN_CERT_DIR/dhparam.pem" ]; then
	# generate dhparam file
	openssl dhparam -dsaparam -out $DOMAIN_CERT_DIR/dhparam.pem 4096; 
fi

if [ "$GENERATE_CERTIFICATE" == "true" ]; then

	create_self_signed_certificate;
	
	CURL_CHECK="curl -s -o /dev/null -w "%{http_code}" https://$LETSENCRYPT_URL";

	if [[ "$(eval $CURL_CHECK)" == "200" ]] ; then
		
		file="$DOMAIN_CERT_DIR/letsencrypt"
		{
		echo "{ \"DOMAIN\": \"$DOMAIN\" }"
		} >> "$file";
		
		DOMAIN_CHECK="curl -s -o /dev/null -w "%{http_code}" http://$DOMAIN";
		if [[ "$(eval $DOMAIN_CHECK)" == "200" || "$(eval $DOMAIN_CHECK)" == "301" ]] ; then
			letsencrypt_certificates;
			echo "Starting letsencrypt"
		else
			echo "Not starting letsencrypt, waiting $TIMEOUT seconds"
			for retries in $(seq 0 $((RESTART + 1))); do
				if [[ $retries -le $RESTART ]] ; then
					sleep $TIMEOUT;
					echo "Starting letsencrypt process";
					if [[ "$(eval $DOMAIN_CHECK)" == "200" || "$(eval $DOMAIN_CHECK)" == "301" ]] ; then
						letsencrypt_certificates;
						break;
					else
						echo "Waiting "$TIMEOUT" second for starting proxies";
						sleep $TIMEOUT;
						echo "Not reached number of restart limit: "$RESTART" sleep "$TIMEOUT" and try again to start lets encrypt process."
					fi
				else
					echo "Reached retrying limit: "$RESTART" ,giving up to start lets encrypt process, try self sign the certificate";
				fi

			done
		fi		
	fi

fi
