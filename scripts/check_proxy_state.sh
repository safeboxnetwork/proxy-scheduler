# Initial parameters

DATE=`date +%F-%H-%M-%S`
TIMEOUT=$TIMEOUT
RESTART=$RESTART
RESTART_COUNTER=0
REGISTRY_URL=$DOCKER_REGISTRY_URL

# Set env variables
FILENAME="$1"
DOMAIN_DIR=$DOMAIN_DIR
if [ -f $DOMAIN_DIR"/"$FILENAME ]; then
	DOMAIN=$(jq -r .DOMAIN $DOMAIN_DIR"/"$FILENAME)
else
	# in case of CERT_DIR
	DOMAIN=$FILENAME
fi;
PROXY_SERVICE_FILE=$PROXY_SERVICE_FILE
ROLE=$ROLE
SERVICE_NAME=$SERVICE_NAME
PROXY_CONFIG_DIR=$PROXY_CONFIG_DIR

SETUP_VERSION=${SETUP_VERSION:-latest};

# Setup docker registry url path

if [[ -n "$DOCKER_REGISTRY_URL" && "$DOCKER_REGISTRY_URL" != "null" ]] ; then
	SETUP="/setup";
else
	SETUP="setup";
	DOCKER_REGISTRY_URL="";
fi
# SPECIAL MOUNTS CHEKING

DNS_DIR=$DNS_DIR
if [ "$DNS_DIR" == "" ] ; then
        DNS_DIR="/etc/system/data/dns";
else
        DNS="--env DNS_DIR=$DNS_DIR";
        DNS_PATH="--volume $DNS_DIR:/etc/dns:rw";
fi

USER_INIT_PATH=$USER_INIT_PATH

if [ "$USER_INIT_PATH" == "" ]; then
        USER_INIT_PATH=/etc/user/config;
else
        USER_ENV="--env $USER_INIT_PATH=/etc/user/config";
        USER_PATH="--volume $USER_INIT_PATH:/etc/user/config:ro";
fi

# Setting service files path

SERVICE_FILES=$SERVICE_FILES

if [ "$SERVICE_FILES" == "" ]; then
        SERVICE_FILES=/etc/user/config/services
fi

CA_PATH=$CA_PATH
if [ "$CA_PATH" == "" ]; then
        CA_PATH=/etc/ssl/certs;
else
        CA="--env CA_PATH=$CA_PATH";
        CA_FILE="--volume $CA_PATH:$CA_PATH:ro";
fi


service_exec="docker run --rm \
 $DNS $DNS_PATH \
 $CA $CA_FILE \
 $USER_ENV $USER_PATH \
 -w /services/ \
 -v $SERVICE_FILES/:/services/:ro \
 -v $SERVICE_FILES/tmp/:/services/tmp/:rw \
 -w /services/ \
 -v /etc/user/config/services/:/services/:ro \
 -v /etc/user/config/services/tmp/:/services/tmp/:rw \
 -v /var/run/docker.sock:/var/run/docker.sock \
 --env DOCKER_REGISTRY_URL=$DOCKER_REGISTRY_URL \
 $DOCKER_REGISTRY_URL$SETUP:$SETUP_VERSION"

do_proxy_restart() { 

        local NAMES="$1"


	for PROXY_NAME in $NAMES ; do 
		
		DO_RESTART="true";
		if [ "$FORCE_RESTART" != "true" ]; then
			docker stop $PROXY_NAME;
			docker start $PROXY_NAME;
			sleep $TIMEOUT;
			
			if docker ps | grep $PROXY_NAME | grep Up ; then
				echo "$PROXY_NAME restarted successful";
				DO_RESTART="false";
			fi
		fi
		
		if [ "$DO_RESTART" == "true" ]; then
			for retries in $(seq 0 $((RESTART + 1))); do
				if [[ $retries -le $RESTART ]] ; then
					echo "Proxy "$PROXY_NAME" restarting in progress";
					$service_exec $SERVICE_NAME.containers.$PROXY_NAME stop force;
					
					## finding network name for starting affected network
					#NETWORK_NAME=$(jq -r --arg NAME $PROXY_NAME '.containers[] | select(.NAME==$NAME)' $PROXY_SERVICE_FILE | jq -r .NETWORK)
					#$service_exec $SERVICE_NAME.networks.$NETWORK_NAME start
					
					$service_exec $SERVICE_NAME.containers.$PROXY_NAME start
					sleep $TIMEOUT;
					if docker ps | grep $PROXY_NAME | grep Up ; then
						echo "$PROXY_NAME restarted successful";
						break ;
					else	
						echo "Restarting number is only: "$retries" so try again"
					fi
				else
					echo "Reached retrying limit: "$RESTART" ,giving up, starting recocer previous state"
					recover_process;
				fi
			done
		fi
	done
}

check_domain() {
	echo "Checking $DOMAIN name";
	CURL_CHECK="curl -m 5 -s -o /dev/null -w "%{http_code}" https://$DOMAIN";
	if [[ "$(eval $CURL_CHECK)" == "200" ]] ; then 
		echo "$DOMAIN accessed successful";
	else 
		send_error_msg $DOMAIN;
	fi
}

recover_process() { 
	echo "Recovering previous state";
	rm $DOMAIN_DIR/$FILENAME;

	echo "#############################################################################"
	echo "########    DOMAIN    #####    $DOMAIN   ####   DELETED      ################"
	echo "#############################################################################"
	exit;
		
}

send_error_msg () { echo "Sending error messages"
}

check_proxy_state() {

# Set restart counter to zero
	CONTAINER_NAMES="";
	CONTAINERS_BY_ROLE=0
	RUNNING_CONTAINERS=0

# Check services with running containers by roles
for CONTAINER in $(jq -r --arg ROLE $ROLE '.containers[] | select(.ROLES==$ROLE)' $PROXY_SERVICE_FILE | jq -r .NAME) ; do

	CONTAINERS_BY_ROLE=$((CONTAINERS_BY_ROLE +1))

	UP=$(docker ps | grep $CONTAINER | grep Up | wc -l)
	RUNNING_CONTAINERS=$((RUNNING_CONTAINERS + UP))
		
	CONTAINERS=$CONTAINERS" "$CONTAINER;

	if [[ "$UP" != 0 ]]; then
		CONTAINER_NAMES=$CONTAINER_NAMES" "$CONTAINER;
	fi;
done;

# The roles numbers and the running containers numbers are equal or greater than 2
if [[ "$RUNNING_CONTAINERS" == "$CONTAINERS_BY_ROLE" || "$RUNNING_CONTAINERS" -ge 2 ]] ; then
	echo "Starting proxy restart process";
	do_proxy_restart "$CONTAINER_NAMES";

# In case of no running proxies found, try to start the service
elif [[ "$RUNNING_CONTAINERS" -eq 0 ]] ; then 
	echo "No running proxies found, starting all";
	
	do_proxy_restart "$CONTAINERS";
	
	for proxies in $CONTAINERS ; do 

		if docker ps | grep $proxies | grep Up; then
			echo "$proxies started successful";
		else 
			echo "$proxies starting was unsuccesful";
			# In case of unsuccessfuly restarted proxy needed to start the proxy containers restarting process.
			do_proxy_restart $proxies;
		fi
	done

# In case of only one running proxy found, try to start the others of the service
elif [[ "$RUNNING_CONTAINERS" -eq 1 ]] ; then 
	echo "Only one running proxy found, starting all of the others";
	for proxies in $CONTAINERS ; do
		if [[ $proxies != $CONTAINER_NAMES ]] ; then
			echo "No running containers: "$proxies" found.";
			
			do_proxy_restart $proxies;
			
			if docker ps | grep $proxies | grep Up ; then
				echo "$proxies started successful";
			else 
				echo "$proxies starting was unsuccesful";
			fi
		else
			ONLY_RUNNING_PROXY_NAME=$proxies;
			
		fi

	done	

	# At last need to restart the only one running proxy when the others started successful.
	for CHECK_PROXIES in $CONTAINERS ; do
		if [[ $CHECK_PROXIES != $ONLY_RUNNING_PROXY_NAME ]] ; then
			if docker ps | grep $CHECK_PROXIES | grep Up ; then
				echo "Not running proxies successfuly started, let's start the only running one.";
				do_proxy_restart $ONLY_RUNNING_PROXY_NAME;
			else
				echo "Not enough running proxies found, can't start the only running one.";
			fi
		fi
	done
fi 

} # end of check_proxy_state


# call method
check_proxy_state

echo "PROXY RESTARTED SUCCESSFULY"
# in case of new proxy configuration generated needed to copy the domain name  to the configs file.then remove new_config flag.
if [[ -f $PROXY_CONFIG_DIR/new_config ]] ; then 
	if [[ ! -f $PROXY_CONFIG_DIR/config || "$(grep $DOMAIN $PROXY_CONFIG_DIR/config 2>/dev/null)" == "" ]] ; then 
		cat $PROXY_CONFIG_DIR/new_config >> $PROXY_CONFIG_DIR/config;
	fi
	
	rm $PROXY_CONFIG_DIR/new_config;
fi

# At last check the previously settings of domain.
check_domain

#				sleep $TIMEOUT;
#				RESTART_COUNTER=$((RESTART_COUNTER +1))
#
#				echo "RUNNING CONTAINERS: "$RUNNING_CONTAINERS;
#
#				if [[ "$RESTART_COUNTER" -le "$RESTART" ]] ; then
#					echo "ELSE: check proxy state";
#					check_proxy_state;
#				else
#					recover_process;
#				fi
#	for CONTAINER in `echo $CONTAINER_NAMES`; do 


#	done;
