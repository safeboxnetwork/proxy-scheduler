#!/bin/sh

service_exec=echo

# Set env variables
	
	DATE=`date +%F-%H-%M-%S`
	CERT_DIR=/keys
	PROXY_SERVICE_FILE=/etc/user/config/services/public-proxy.json
	PROXY_CONFIG_DIR=/proxy_config
	ROLE="backend-proxy"
	SERVICE_NAME="public-proxy"
	CONTAINERS_BY_ROLE=0
	RUNNING_CONTAINERS=0
	TIMEOUT=5
	RESTART=5


check_proxy_state() {
# Check services with running containers by roles

	for CONTAINER in $(jq -r --arg ROLE $ROLE '.containers[] | select(.ROLES==$ROLE)' $PROXY_SERVICE_FILE | jq -r .NAME) ; do

		CONTAINERS_BY_ROLE=$((CONTAINERS_BY_ROLE +1))

		UP=$(docker ps | grep $CONTAINER | grep Up | wc -l)
		RUNNING_CONTAINERS=$((RUNNING_CONTAINERS + UP))
	done;

# The roles numbers and the running containers numbers are equal or greater than 2
if [[ "$RUNNING_CONTAINERS" == "$CONTAINERS_BY_ROLE" || "$RUNNING_CONTAINERS" == 2 ]] ; then
	echo "Starting proxy restart process"
fi }

# Triggers by certificate or proxy config changes

unset IFS

inotifywait --exclude .sw -m -e CREATE,CLOSE_WRITE,CLOSE,DELETE -r $CERT_DIR $PROXY_CONFIG_DIR | \
while read dir op file

do 


 parent="/"$(echo $dir|cut -d / -f2)

 if [[ "${parent}" == "${CERT_DIR}" && "${op}" == "CLOSE_WRITE,CLOSE"  ]]; then
		DOMAIN=$(echo $dir|cut -d / -f3);
                echo "New cert created: '$DOMAIN'";
		check_proxy_state;

 elif [[ "${parent}" == "${PROXY_CONFIG_DIR}" && "${op}" == "CLOSE_WRITE,CLOSE" ]] || \
      [[ "${parent}" == "${PROXY_CONFIG_DIR}" && "${op}" == "DELETE" ]] ; then
		echo "proxy config created, changed or deleted";
		check_proxy_state;
 fi

done


# Running containers from existing roles
#	echo $CONTAINERS_BY_ROLE;
#	echo $RUNNING_CONTAINERS;
		#$service_exec $SERVICE_NAME.containers.$CONTAINER stop
		#$service_exec $SERVICE_NAME.containers.$CONTAINER start
