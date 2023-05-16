#!/bin/sh

GENERATE_CERTIFICATE=$GENERATE_CERTIFICATE

cd /proxy_config

FILENAME=$1

DOMAIN_SOURCE=/domains/$FILENAME
#DOMAIN_SOURCE=./domains/$FILENAME #TEMP
DOMAIN_NAME=$(jq -r .DOMAIN $DOMAIN_SOURCE)
HTTP_PORT=$(jq -r .HTTP_PORT $DOMAIN_SOURCE)
HTTPS_PORT=$(jq -r .HTTPS_PORT $DOMAIN_SOURCE);
ALIASES_HTTP=$(jq -r '.ALIASES_HTTP | select(.!="null") | join(" ")' $DOMAIN_SOURCE)
ALIASES_HTTPS=$(jq -r '.ALIASES_HTTPS | select(.!="null") | join(" ")' $DOMAIN_SOURCE)
REDIRECT_HTTP=$(jq -r .REDIRECT_HTTP $DOMAIN_SOURCE)
REDIRECT_HTTPS=$(jq -r .REDIRECT_HTTPS $DOMAIN_SOURCE)
ERROR_PAGE=$(jq -r .ERROR_PAGE $DOMAIN_SOURCE)
MAX_BODY_SIZE=$(jq -r .MAX_BODY_SIZE $DOMAIN_SOURCE)
DEBUG=$(jq -r .DEBUG $DOMAIN_SOURCE)
ALLOWED_NETWORK=$(jq -r '.ALLOWED_NETWORK | select(.!="null") | join(" ")' $DOMAIN_SOURCE)
OPERATION=$(jq -r '.OPERATION' $DOMAIN_SOURCE)
ALTERNATE_LOCATION_PATH=$(jq -r .ALTERNATE_LOCATION_PATH $DOMAIN_SOURCE)
LOCAL_NAME=$(jq -r .LOCAL_NAME $DOMAIN_SOURCE 2>/dev/null);
if [[ "$LOCAL_NAME" == "" || "$LOCAL_NAME" == "null" ]]; then
        LOCAL_NAME=$(jq -r .LOCAL_IP $DOMAIN_SOURCE 2>/dev/null);
fi
RELOAD_LOCATIONS="";

if [ -n "$2" ]; then
	echo "$DOMAIN_NAME DELETED";
	rm $DOMAIN_NAME.conf;
	exit;
fi

add_alternate_location() {
	{
		cat $DOMAIN_NAME.conf | head -n -1
		add_location;
		echo "}"

	} >> "$file"
}

add_location() {

		if [[ "$ALTERNATE_LOCATION_PATH" != "" ]]; then

			ALP_IDX=$(jq -r '.ALTERNATE_LOCATION_PATH | length' $DOMAIN_SOURCE)
			ALP_IDX=$(( $ALP_IDX - 1 ))

			for i in $(seq 0 $ALP_IDX) ;
			do
				ALP=$(jq -r .ALTERNATE_LOCATION_PATH[$i] $DOMAIN_SOURCE)

				ALP_LOCAL_PATH=$(echo $ALP | jq -rc .LOCAL_PATH);
				ALP_LOCAL_NAME=$(echo $ALP | jq -rc .LOCAL_NAME);
				ALP_LOCAL_PORT=$(echo $ALP | jq -rc .LOCAL_PORT);
				ALP_LOCAL_ALLOWED_NETWORK=$(echo $ALP | jq -rc '.LOCAL_ALLOWED_NETWORK | select(.!="null") | join(" ")');

				# do not duplicate locations
				EXISTS=$(grep -rn "location $ALP_LOCAL_PATH {" -m 1 $DOMAIN_NAME.conf);
				if [ -n "$EXISTS" ]; then
					ROW_NUMBER=$(echo $EXISTS | cut -d ':' -f1);
					START=$(($ROW_NUMBER + 2));
					OFFSET=$(tail -n+$START $DOMAIN_NAME.conf | grep -n '}' -m 1 | cut -d ':' -f1);
					OFFSET=$(($OFFSET - 2));
					ALP_ALLOWED=$(echo $(tail -n+$START $DOMAIN_NAME.conf | head -n $OFFSET | awk '{print $2}')); # echo removes space at the end
					if [ "$ALP_LOCAL_ALLOWED_NETWORK" != "$ALP_ALLOWED" ]; then
						RELOAD_LOCATIONS=$RELOAD_LOCATIONS$ALP_LOCAL_PATH" "
					fi;
					# skip if exists
					continue;
				fi;

				if [[ "$ALP_LOCAL_NAME" = "" ]]; then
					ALP_LOCAL_NAME=$LOCAL_NAME
				fi;

				if [[ "$ALP_LOCAL_PORT" = "" ]]; then
					ALP_LOCAL_PORT=$HTTP_PORT
				fi;

				echo "location $ALP_LOCAL_PATH {"

				if [[ "$ALP_LOCAL_ALLOWED_NETWORK" != "" ]]; then
					echo " limit_except GET HEAD {";
					for i in $(echo $ALP_LOCAL_ALLOWED_NETWORK) ; do
						echo " 	allow $i";
					done;
					echo " 	deny all;";
					echo " }";
				fi

				if [[ "$ALP_LOCAL_PORT" != "" ]]; then
					echo " proxy_pass http://$ALP_LOCAL_NAME:$ALP_LOCAL_PORT/;"
				else
					echo " proxy_pass http://$ALP_LOCAL_NAME:80;"
				fi
 
				echo " proxy_set_header Host "'$http_host'";
 proxy_set_header X-Real-IP "'$remote_addr'";
 proxy_set_header X-Forwarded-For "'$proxy_add_x_forwarded_for'";
 proxy_set_header X-Forwarded-Proto "'$scheme'";
 proxy_set_header Upgrade "'$http_upgrade;'"
 proxy_cookie_path $ALP_LOCAL_PATH $ALP_LOCAL_PATH;
 proxy_set_header Connection "'$http_connection'";
 proxy_connect_timeout      300;
 proxy_send_timeout         300;
 proxy_read_timeout         300;
 proxy_next_upstream off;"

				if [[ "$DEBUG" != "true" ]]; then
					echo " access_log off;"
				fi
				echo " proxy_redirect off;"
				echo " proxy_buffering off;"
				echo "}"
				echo "# location end"
			done;
		fi;

}

remove_alternate_location() {

	if [[ "$ALTERNATE_LOCATION_PATH" != "" ]]; then

		ALP_IDX=$(jq -r '.ALTERNATE_LOCATION_PATH | length' $DOMAIN_SOURCE)
		ALP_IDX=$(( $ALP_IDX - 1 ))

		for i in $(seq 0 $ALP_IDX) ;
		do
			ALP=$(jq -r .ALTERNATE_LOCATION_PATH[$i] $DOMAIN_SOURCE)
			ALP_LOCAL_PATH=$(echo $ALP | jq -rc .LOCAL_PATH);
			remove_location $ALP_LOCAL_PATH
		done;
	fi;
}

remove_location() {
	local LOCATION=$1

	LOCATION_ROW="location $LOCATION {";
	ROW_NUMBER=$(grep -rn "$LOCATION_ROW" $DOMAIN_NAME.conf | cut -d ':' -f1);
	if [ -n "$ROW_NUMBER" ]; then
		OFFSET=$(tail -n+$ROW_NUMBER $DOMAIN_NAME.conf | grep -n '# location end' -m 1 | cut -d ':' -f1);
		START=$(($ROW_NUMBER - 1));
		END=$(($ROW_NUMBER + $OFFSET));

		{
			head -n$START $DOMAIN_NAME.conf
			tail -n+$END $DOMAIN_NAME.conf
		} >> $file

		mv $file $DOMAIN_NAME.conf;
	fi;
}

# create new nginx config
create_new_config() {
{

if [[ "$HTTP_PORT" != "80" ]]; then
	echo "server {
listen 80 proxy_protocol;"
	if [[ "$ALIASES_HTTP" != "" ]]; then
		echo "server_name $DOMAIN_NAME $ALIASES_HTTP;"
	else
		echo "server_name $DOMAIN_NAME;"
	fi 
echo "set_real_ip_from 0.0.0.0/0;
real_ip_header proxy_protocol;
rewrite_log on;
return 301 https://$DOMAIN_NAME;
}"

fi	

if [[ "$HTTP_PORT" != "" && "$HTTP_PORT" != "80" ]]; then
	echo "server {
	listen $HTTP_PORT proxy_protocol;
	set_real_ip_from 0.0.0.0/0;
	real_ip_header proxy_protocol;"
	
		if [[ "$ALIASES_HTTP" != "" ]]; then
			echo "server_name $DOMAIN_NAME $ALIASES_HTTP;"
		else
			echo "server_name $DOMAIN_NAME;"
		fi 
		
		if [[ "$MAX_BODY_SIZE" != "" ]]; then
		echo "client_max_body_size "$MAX_BODY_SIZE";"
		
		else
		
		echo "client_max_body_size 0;"
		fi 
	
	echo "rewrite_log on;"
	
	
		if [[ "$REDIRECT_HTTP" != "" ]] ; then 
			echo "return 301 $REDIRECT_HTTP;"
		elif [[  "$HTTP_PORT" == "" ]]; then
			echo "return 301 https://"$DOMAIN_NAME;
	
		else
			echo "location / {"
			
			if [[ "$ALLOWED_NETWORK" != "" ]]; then
				ALLOWED_NETWORK_IDX=$(jq -r '.ALLOWED_NETWORK | length' $DOMAIN_SOURCE)
				ALLOWED_NETWORK_IDX=$(( $ALLOWED_NETWORK_IDX - 1 ))
				
				echo " limit_except GET HEAD {";
				for i in $(seq 0 $ALLOWED_NETWORK_IDX) ; do
					AN=$(jq -r .ALLOWED_NETWORK[$i] $DOMAIN_SOURCE)
					echo " 	allow "$AN";"
				done
				echo " 	deny  all;"
				echo " }";
		 	fi
	
			if [[ "$HTTP_PORT" != "" ]]; then
	 			echo " proxy_pass http://$LOCAL_NAME:$HTTP_PORT;"
			fi
	
			echo " proxy_set_header Host "'$http_host'";
	 proxy_set_header X-Real-IP "'$remote_addr'";
	 proxy_set_header X-Forwarded-For "'$proxy_add_x_forwarded_for'";
	 proxy_set_header X-Forwarded-Proto "'$scheme'";
	 proxy_set_header Upgrade "'$http_upgrade;'"
	 proxy_cookie_path / /;
	 proxy_set_header Connection "'$http_connection'" ;"
	
			if [[ "$DEBUG" != "true" ]]; then
			 	echo " access_log off;"
			fi
			echo " proxy_redirect off;"
			echo " proxy_buffering off;"
			echo "}"
				
			if [[ "$ERROR_PAGE" != "" && "$HTTP_PORT" != "" ]]; then
				echo "error_page 404 /$ERROR_PAGE;
				location = /$ERROR_PAGE {
				      root    html;
				      allow   all;
				      index   404.html;
				      rewrite ^ "'$scheme'" http://$ERROR_PAGE"'$request_uri'" permanent;
					      }"
			fi
		fi
	echo "}"
fi

if [[ "$HTTPS_PORT" != "" ]]; then
	echo "server {
listen 443 ssl proxy_protocol;
set_real_ip_from 0.0.0.0/0;
real_ip_header proxy_protocol;"

if [[ "$ALIASES_HTTPS" != "" ]]; then
	echo "server_name $DOMAIN_NAME $ALIASES_HTTPS;"
else
	echo "server_name $DOMAIN_NAME;"
fi 

if [[ "$MAX_BODY_SIZE" != "" ]]; then
	echo "client_max_body_size "$MAX_BODY_SIZE";"
else
	echo "client_max_body_size 0;"
fi 

echo "rewrite_log on;
proxy_ssl_server_name on; 
 ssl_dhparam /etc/ssl/keys/$DOMAIN_NAME/dhparam.pem;"

if [ "$GENERATE_CERTIFICATE" == "true" ]; then 

echo "ssl_certificate /etc/ssl/keys/$DOMAIN_NAME/fullchain.pem;
 ssl_certificate_key /etc/ssl/keys/$DOMAIN_NAME/key.pem;"

else 
	echo "ssl_certificate /etc/ssl/keys/fullchain.pem;
 ssl_certificate_key /etc/ssl/keys/key.pem;"

fi

echo "ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
 ssl_prefer_server_ciphers on;
 ssl_ciphers "'"EECDH+ECDSA+AESGCM EECDH+aRSA+AESGCM EECDH+ECDSA+SHA384 EECDH+ECDSA+SHA256 EECDH+aRSA+SHA384 EECDH+aRSA+SHA256 EECDH+aRSA+RC4 EECDH EDH+aRSA RC4 !aNULL !eNULL !LOW !3DES !MD5 !EXP !PSK !SRP !DSS !RC4 !kDHE"'";
ssl_session_cache shared:SSL:50m;
ssl_session_timeout 5m;
ssl_stapling on;"


	if [[ "$ERROR_PAGE" != "" && "$HTTPS_PORT" != "" ]]; then
		echo "error_page 404 /$ERROR_PAGE;
location = /$ERROR_PAGE {
      root    html;
      allow   all;
      index   404.html;
      rewrite ^ "'$scheme' "http://$ERROR_PAGE"'$request_uri'" permanent;
	      }"
	fi

	if [[ "$REDIRECT_HTTPS" != ""  ]]; then
		echo "return 301 $REDIRECT_HTTPS;"
	else 
		echo "location / {"

		if [[ "$ALLOWED_NETWORK" != "" ]]; then
			ALLOWED_NETWORK_IDX=$(jq -r '.ALLOWED_NETWORK | length' $DOMAIN_SOURCE)
			ALLOWED_NETWORK_IDX=$(( $ALLOWED_NETWORK_IDX - 1 ))
			
			echo " limit_except GET HEAD {";
			for i in $(seq 0 $ALLOWED_NETWORK_IDX) ; do
					AN=$(jq -r .ALLOWED_NETWORK[$i] $DOMAIN_SOURCE)
					echo " 	allow "$AN";"
			done
			echo " 	deny  all;"
			echo " }";
	 	fi	
echo " proxy_pass http://$LOCAL_NAME:$HTTPS_PORT;"
 
		echo " proxy_set_header Host "'$http_host'";
 proxy_set_header X-Real-IP "'$remote_addr'";
 proxy_set_header X-Forwarded-For "'$proxy_add_x_forwarded_for'";
 proxy_set_header X-Forwarded-Proto "'$scheme'";
 proxy_set_header Upgrade "'$http_upgrade;'"
 proxy_cookie_path / /;
 proxy_set_header Connection "'$http_connection'";
 proxy_connect_timeout      300;
 proxy_send_timeout         300;
 proxy_read_timeout         300;
 proxy_next_upstream off;"

		if [[ "$DEBUG" != "true" ]]; then
		 	echo " access_log off;"
		fi
		echo " proxy_redirect off;"
		echo " proxy_buffering off;"
		echo "}"

		echo "# first location end";

		add_location;

	fi

if [ "$OPERATION" != "MODIFY" ]; then
	echo "}"
fi;

fi

} >> "$file"

}


file="/tmp/$DOMAIN_NAME.conf"

# check whether certificates exist or not


echo "created domain name: "$DOMAIN_NAME;

#cp -a /scripts/nginx_template.conf /tmp/$DOMAIN.conf

# if domain already exists as a config file append alternate location there
if [ -f $DOMAIN_NAME.conf ]; then

	if [ "$OPERATION" = "DELETE" ]; then
		remove_alternate_location;
	elif [ "$OPERATION" = "MODIFY" ]; then
		# must be before create_new_config
		remove_alternate_location;
		add_alternate_location;
		mv $file $DOMAIN_NAME.conf;

		# regenerates nginx config into $file
		create_new_config;

		#  append existing alternate locations to new config file
		OFFSET=$(cat $DOMAIN_NAME.conf | grep -n '# first location end' -m 1 | cut -d ':' -f1);
		OFFSET=$(($OFFSET + 1));
		{
			tail -n+$OFFSET $DOMAIN_NAME.conf
		} >> $file

	else
		# default CREATE, append location
		add_alternate_location;

		# reload alternate locations if allowed networks has changed
		if [ -n "$RELOAD_LOCATIONS" ]; then
			rm $file;
			remove_alternate_location;
			add_alternate_location;
		fi;
	fi;
else

	# rewrite operation if nginx config file doesn't exists
	OPERATION="CREATE";
	create_new_config;

fi; # end of create new nginx config

if [ "$OPERATION" != "DELETE" ]; then
	mv $file $DOMAIN_NAME.conf;
fi;
echo "$DOMAIN" >> new_config

if [ "$HTTPS_PORT" != "" ]; then
	/scripts/check_certificates.sh "$DOMAIN_NAME";
fi
