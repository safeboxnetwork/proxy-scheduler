# Initial parameters
DATE=`date +%F-%H-%M-%S`
TIMEOUT=$TIMEOUT
RESTART=$RESTART
RESTART_COUNTER=0

# Set env variables
PROXY_SERVICE_FILE=$PROXY_SERVICE_FILE
ROLE=$ROLE
SERVICE_NAME=$SERVICE_NAME
PROXY_CONFIG_DIR=$PROXY_CONFIG_DIR

service_exec="docker run --rm -v /etc/user/config/services/:/services/:ro -v /var/run/docker.sock:/var/run/docker.sock -v /usr/bin/docker:/usr/bin/docker:ro registry.format.hu/setup /scripts/service-exec"

do_proxy_restart() { 

        local NAMES="$1"

	for proxies in $NAMES ; do 
		docker stop $proxies;
		sleep $TIMEOUT;
		$service_exec $SERVICE_NAME.containers.$proxies start
		if docker ps | grep $proxies ; then
			if [ -z "$DOMAIN" ] ; then
				echo "$proxies restarted successful";
			else
				check_domain;
			fi
		else 
			PROXY_NAME=$proxies
			for retries in $(seq 0 $((RESTART + 1))); do
				if [[ $retries -le $RESTART ]] ; then
					echo "Proxy "$PROXY_NAME" restarting in progress";
					docker stop $PROXY_NAME;
					sleep $TIMEOUT;
					$service_exec $SERVICE_NAME.containers.$PROXY_NAME start
						if docker ps | grep $PROXY_NAME ; then
							echo "$PROXY_NAME restarted successful";
							break ;
						else	
							echo "Restarting number is only: "$retries" so try again"
							sleep $TIMEOUT;
						fi
				else
					echo "Reached retrying limit: "$RESTART" ,giving up, starting recocer previous state"
					recover_process;
				fi
			done
		fi
	done
	# in case of new proxy configuration generated needed to copy the domain name  to the configs file.then remove new_config flag.
	if [[ -f $PROXY_CONFIG_DIR/new_config ]] ; then 
		if [[ "$(grep $DOMAIN $PROXY_CONFIG_DIR/config)" == "" || ! -f $PROXY_CONFIG_DIR/config ]] ; then 
			cat $PROXY_CONFIG_DIR/new_config >> $PROXY_CONFIG_DIR/config;
		fi
		
		rm $PROXY_CONFIG_DIR/new_config;
	fi
}

check_domain() {
	echo "Checking $DOMAIN name";
	CURL_CHECK="curl -s -o /dev/null -w "%{http_code}" https://$DOMAIN";
	if [[ "$(eval $CURL_CHECK)" == "200" ]] ; then 
		echo "$proxies restarted successful";
	else 
		send_error_msg;
	fi
}

recover_process() { echo "Recovering previous state"
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
	
	$service_exec /services/$SERVICE_NAME.json stop;
	$service_exec /services/$SERVICE_NAME.json start;
	
	for proxies in $CONTAINERS ; do 

		if docker ps | grep $proxies ; then
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
			
			if docker ps | grep $proxies ; then
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
			if docker ps | grep $CHECK_PROXIES ; then
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
