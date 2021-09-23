#!/bin/sh


# Initial parameters
DATE=`date +%F-%H-%M-%S`

# Set env variables
PROXY_TYPE=$PROXY_TYPE
DOMAIN_DIR=$DOMAIN_DIR
CERT_DIR=$CERT_DIR
PROXY_CONFIG_DIR=$PROXY_CONFIG_DIR

# Triggers by certificate or domain config changes

unset IFS

inotifywait --exclude .sw -m -e CREATE,CLOSE_WRITE,DELETE -r $DOMAIN_DIR $CERT_DIR | \
while read dir op file

do 

 parent="/"$(echo $dir|cut -d / -f2)

 if [[ "${parent}" == "${CERT_DIR}" && "${op}" == "CLOSE_WRITE,CLOSE" ]] ; then
		DOMAIN=$(echo $dir|cut -d / -f3);
		if [[ -f $CERT_DIR/$DOMAIN/renew_certificate && ! -f $PROXY_CONFIG_DIR/new_config ]]; then
			rm $CERT_DIR/$DOMAIN/renew_certificate;
			echo "New cert created: '$DOMAIN'";
			echo "newcert check proxy";
			/scripts/check_proxy_state.sh $DOMAIN;
		
		elif [[ -f $CERT_DIR/$DOMAIN/new_certificate && ! -f $PROXY_CONFIG_DIR/new_config ]]; then
			rm $CERT_DIR/$DOMAIN/new_certificate;
			echo "New cert created: '$DOMAIN'";
			echo "newcert check proxy";
			/scripts/check_proxy_state.sh $DOMAIN;
		fi
 
 elif [[ "${parent}" == "${DOMAIN_DIR}" && "${op}" == "CLOSE_WRITE,CLOSE" ]]; then
		DOMAIN=$(echo $file);
		
		if [[ "${PROXY_TYPE}" == "haproxy" ]]; then
			echo "haproxy config created, changed";
			/scripts/config_haproxy_generate.sh;
		fi
		
		echo "domain config created, changed";
		/scripts/nginx_config_create.sh "$DOMAIN";
		
		if [ -f "$PROXY_CONFIG_DIR/new_config" ] ; then
			/scripts/check_proxy_state.sh "$DOMAIN";
 		fi

 elif [[ "${parent}" == "${DOMAIN_DIR}" && "${op}" == "DELETE" ]] ; then
		DOMAIN=$(echo $file);
		echo "domain deleted";
		if [ ! -f "$DOMAIN_DIR/$DOMAIN" ]; then
			/scripts/nginx_config_create.sh "$DOMAIN" "DEL";
			/scripts/check_proxy_state.sh "$DOMAIN" "DEL";
 		fi

 fi


done
