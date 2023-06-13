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

if [ "$SOURCE" == "" ]; then
	SOURCE=/etc/user/config
fi

if [[ -n "$DOCKER_REGISTRY_URL" && "$DOCKER_REGISTRY_URL" != "null" ]] ; then
    SETUP="/setup";
else
    SETUP="setup";
    DOCKER_REGISTRY_URL="";
fi

    DNS_DIR="/etc/system/data/dns";
    DNS="--env DNS_DIR=$DNS_DIR";
    DNS_PATH="--volume $DNS_DIR:/etc/dns:rw";

    CA_PATH=/etc/ssl/certs;
    CA="--env CA_PATH=$CA_PATH";
    CA_FILE="--volume $CA_PATH:$CA_PATH:ro";


service_exec="docker run --rm \
$DNS $DNS_PATH \
$CA $CA_FILE \
-w /services/ \
-v $SOURCE/system.json:/etc/user/config/system.json:ro \
-v $SOURCE/user.json:/etc/user/config/user.json:ro \
-v $SERVICE_FILES/:/services/tmp/:rw \
-v /var/run/docker.sock:/var/run/docker.sock \
-v /usr/bin/docker:/usr/bin/docker:ro  \
--env DOCKER_REGISTRY_URL=$DOCKER_REGISTRY_URL \
$DOCKER_REGISTRY_URL$SETUP"


letsencrypt_certificates() {

	#cd /

	for retries in $(seq 0 $((RESTART + 1))); do
		if [[ $retries -le $RESTART ]] ; then
	
			LETS_ENCRYPT_VALUE="$(docker ps | grep letsencrypt | grep Up | wc -l)";
			if [[ $LETS_ENCRYPT_VALUE -eq 0 ]] ; then
				echo "Starting letsencrypt process";
				LETSENCRYPT_TEMP_SERVICE_FILE=$(mktemp -p /tmp/)".json";
				ENVS='[
					{"DOMAIN": "'$DOMAIN'"},
					{"TIMEOUT": "'$TIMEOUT'"},
					{"RESTART": "'$RESTART'"}
				]';
				VOLUMES='
					{
						"SOURCE": "/etc/user/config/user.json",
						"DEST": "/etc/user/config/user.json",
						"TYPE": "ro"
					}
				';
				jq '.containers[0].ENVS |='"$ENVS"' | .containers[0].VOLUMES[.containers[0].VOLUMES|length]|='"$VOLUMES" $SERVICE_FILES/$LETSENCRYPT_SERVICE_NAME > $LETSENCRYPT_TEMP_SERVICE_FILE;
				$service_exec $(basename $LETSENCRYPT_TEMP_SERVICE_FILE) start info;
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

# Check any certificate exists

	if [[ ! -f $DOMAIN_CERT_DIR/key.pem && ! -f $DOMAIN_CERT_DIR/fullchain.pem && ! -f $DOMAIN_CERT_DIR/cert.pem ]] ; then

		# generate key
		echo "No any certificates found, generate self signed";
		openssl req -x509 -newkey rsa:4096 -keyout $DOMAIN_CERT_DIR/key.pem -out $DOMAIN_CERT_DIR/cert.pem -days 365 -sha256 -nodes -subj "/CN=$DOMAIN";
		cp -a $DOMAIN_CERT_DIR/cert.pem $DOMAIN_CERT_DIR/fullchain.pem;
	

	fi

}

if [ ! -d "$DOMAIN_CERT_DIR" ]; then
	echo "$DOMAIN not contains certificates, creates new."
	mkdir -p $DOMAIN_CERT_DIR;
fi

if [ ! -f "$DOMAIN_CERT_DIR/dhparam.pem" ]; then
	# generate dhparam file
	openssl dhparam -dsaparam -out $DOMAIN_CERT_DIR/dhparam.pem 4096;
	create_self_signed_certificate;
		
	PROXY_NAMES="";
	# Check services with running containers by roles
	for CONTAINER in $(jq -r --arg ROLE $ROLE '.containers[] | select(.ROLES==$ROLE)' /$PROXY_SERVICE_FILE | jq -r .NAME) ; do
		PROXY_NAMES=$PROXY_NAMES" "$CONTAINER;
	done;

	for NAME in $(echo $PROXY_NAMES); do
		RUNNING_CONTAINER=$(docker ps | grep $NAME | grep Up);
		if [ "$RUNNING_CONTAINER" != "" ]; then
			echo "Restarting $NAME";
			docker restart $NAME;
		else
			echo "Starting $NAME";
			docker start $NAME;
		fi;
		docker ps |grep $NAME;
	done;
	
fi

if [ "$GENERATE_CERTIFICATE" == "true" ]; then
	
	CURL_CHECK="curl -s -o /dev/null -w "%{http_code}" https://$LETSENCRYPT_URL";

	if [[ "$(eval $CURL_CHECK)" == "200" ]] ; then
		
		file="$DOMAIN_CERT_DIR/letsencrypt"
		{
		echo "{ \"DOMAIN\": \"$DOMAIN\" }"
		} >> "$file";
		
		DOMAIN_CHECK="curl -s -o /dev/null -w "%{http_code}" http://$DOMAIN";
		if [[ "$(eval $DOMAIN_CHECK)" == "200" || "$(eval $DOMAIN_CHECK)" == "301" ]] ; then
			letsencrypt_certificates;
			echo "Started letsencrypt for domain: $DOMAIN first time"
		else
			echo "Not starting letsencrypt, waiting $TIMEOUT seconds"
			for retries in $(seq 0 $((RESTART + 1))); do
				if [[ $retries -le $RESTART ]] ; then
					sleep $TIMEOUT;
					echo "Starting letsencrypt process again";
					if [[ "$(eval $DOMAIN_CHECK)" == "200" || "$(eval $DOMAIN_CHECK)" == "301" ]] ; then
						letsencrypt_certificates;
						echo "Started letsencrypt for domain: $DOMAIN second time"
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
