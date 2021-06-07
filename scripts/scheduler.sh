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

# Triggers by certificate or proxy config changes

unset IFS

inotifywait --exclude .swp -m -e CREATE,CLOSE_WRITE,CLOSE,DELETE -r $CERT_DIR $PROXY_CONFIG_DIR | \
while read dir op file

do 

 if [[ "${dir}" == "${CERT_DIR}" && "${op}" == "CLOSE_WRITE" ]]; then
                DOMAIN=$(echo $dir|cut -d / -f3)
                echo "New cert created: '$DOMAIN'"

 elif [[ "${dir}" == "${PROXY_CONFIG_DIR}" && "${op}" == "CLOSE_WRITE" ]] || \      
      [[ "${dir}" == "${PROXY_CONFIG_DIR}" && "${op}" == "CREATE" ]] || \
      [[ "${dir}" == "${PROXY_CONFIG_DIR}" && "${op}" == "DELETE" ]] ; then
		echo "proxy config created, changed or deleted"
 fi

done

# Check services with running containers by roles

	#CONTAINER=$(jq -r --arg ROLE $ROLE '.containers[] | select(.ROLES==$ROLE)' $FILE | jq -r .NAME)
	for CONTAINER in $(jq -r --arg ROLE $ROLE '.containers[] | select(.ROLES==$ROLE)' $PROXY_SERVICE_FILE | jq -r .NAME) ; do

		#$service_exec $SERVICE_NAME.containers.$CONTAINER stop
		#$service_exec $SERVICE_NAME.containers.$CONTAINER start
		CONTAINERS_BY_ROLE=$((CONTAINERS_BY_ROLE +1))

		UP=$(docker ps | grep $CONTAINER | grep Up | wc -l)
		#if [[ $UP -eq 1 ]] ; then
		#	echo "FUT";
		#fi
		RUNNING_CONTAINERS=$((RUNNING_CONTAINERS + UP))
	done;

# Running containers from existing roles
#	echo $CONTAINERS_BY_ROLE;
#	echo $RUNNING_CONTAINERS;
# The roles numbers and the running containers numbers are equal or greater than 2

if [[ "$RUNNING_CONTAINERS" == "$CONTAINERS_BY_ROLE" || "$RUNNING_CONTAINERS" == 2 ]] ; then
	echo "Starting proxy restart process"
fi
		#if [[ $UP -eq 1 ]] ; then
		#fi

