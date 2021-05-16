#!/bin/sh

unset IFS

service_exec=echo


CERT_DIR=/keys

inotifywait --exclude .swp -m -e CLOSE_WRITE,CLOSE -r $CERT_DIR | \

while read dir op file
do 
   if [[ "${op}" == "CLOSE_WRITE,CLOSE" ]] ; then
        DOMAIN=$(echo $dir|cut -d / -f3)

	FILE=$(find /etc/user/config/services/ -name *.json | xargs -I {} jq '{"file": input_filename, "MAIN": ..|.main?'} {} | jq -c 'select(.MAIN | length > 0)' | grep $DOMAIN | jq -r .file)
	
	ROLE=$ROLES

	CONTAINER=$(jq -r --arg ROLE $ROLE '.containers[] | select(.ROLES==$ROLE)' $FILE | jq -r .NAME)

	SERVICE_NAME=$(basename $FILE|cut -d . -f1)

	$service_exec $SERVICE_NAME.containers.$CONTAINER stop

	$service_exec $SERVICE_NAME.containers.$CONTAINER start

   fi

done

