#!/bin/sh


# Initial parameters
DATE=`date +%F-%H-%M-%S`

# Set env variables
DOMAIN_DIR=$DOMAIN_DIR
CERT_DIR=$CERT_DIR
PROXY_CONFIG_DIR=$PROXY_CONFIG_DIR

# Triggers by certificate or proxy config changes

unset IFS

inotifywait --exclude .sw -m -e CREATE,CLOSE_WRITE,DELETE -r $DOMAIN_DIR $CERT_DIR $PROXY_CONFIG_DIR | \
while read dir op file

do 

 parent="/"$(echo $dir|cut -d / -f2)

 if [[ "${parent}" == "${CERT_DIR}" && "${op}" == "CLOSE_WRITE,CLOSE" ]] ; then
		DOMAIN=$(echo $dir|cut -d / -f3);
		if [ -f "$CERT_DIR/$DOMAIN/new_certificate"  ]; then
			echo "New cert created: '$DOMAIN'";
			echo "newcert check proxy";
			/scripts/check_proxy_state.sh;
		fi

 elif [[ "${parent}" == "${PROXY_CONFIG_DIR}" && "${op}" == "CLOSE_WRITE,CLOSE" ]]; then
		echo "proxy config created, changed ";
		/scripts/check_proxy_state.sh;
 
 elif     [[ "${parent}" == "${PROXY_CONFIG_DIR}" && "${op}" == "DELETE" ]] ; then
		echo "proxy config deleted";
		FILE=$(echo $file)
		if [ ! -f "$PROXY_CONFIG_DIR/$FILE" ]; then
			/scripts/check_proxy_state.sh;
 		fi
 
 elif [[ "${parent}" == "${DOMAIN_DIR}" && "${op}" == "CLOSE_WRITE,CLOSE" ]]; then
		DOMAIN=$(echo $file);
		echo "domain config created, changed";
		/scripts/nginx_config_create.sh "$DOMAIN";
 
 elif [[ "${parent}" == "${DOMAIN_DIR}" && "${op}" == "DELETE" ]] ; then
		DOMAIN=$(echo $file);
		echo "domain deleted";
		if [ ! -f "$DOMAIN_DIR/$DOMAIN" ]; then
			/scripts/nginx_config_create.sh "$DOMAIN" "DEL";
 		fi
 fi


done
