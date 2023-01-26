#!/bin/sh

# Initial parameters
DATE=`date +%F-%H-%M-%S`

DOMAIN=$1

# Set env variables
DOMAIN_DIR=$DOMAIN_DIR
PROXY_CONFIG_DIR=$PROXY_CONFIG_DIR

cd $DOMAIN_DIR
file="$PROXY_CONFIG_DIR/haproxy.cfg"

global_http="/scripts/global_http"
global_https="/scripts/global_https"

cp -a /scripts/haproxy_template.cfg $PROXY_CONFIG_DIR/haproxy.cfg

{

echo "frontend http
";

cat "$global_http"
echo 

#echo "acl letsencrypt path_beg /.well-known/acme-challenge/";

echo 

for i in `ls $DOMAIN_DIR|cut -d / -f2` ;  do
  
        if [[ "$(jq -r .REDIRECT_HTTPS $i)" != "" && "$(jq -r .HTTP_PORT $i)" != "" && "$(jq -r .DOMAIN $i)" != "letsencrypt" ]]
        then    
            echo "redirect prefix https://$(jq -r .REDIRECT_HTTPS $i) code 301 if { hdr(host) -i $(jq -r .DOMAIN $i) }";
        fi
done
echo

for i in `ls $DOMAIN_DIR|cut -d / -f2` ;  do

	if [[ "$(jq -r .DOMAIN $i)" != "" && "$(jq -r .HTTP_PORT $i)" != "" && "$(jq -r .DOMAIN $i)" != "letsencrypt" ]]
	then
		echo "acl $(jq -r .DOMAIN $i)_http hdr(host) -i $(jq -r .DOMAIN $i)";
	fi

	if [[ "$(jq -r .DOMAIN $i)" != "letsencrypt"  && "$(jq -r .HTTP_PORT $i)" != "" && "$(jq -r .ALIASES_HTTP[] $i)" != "" ]]
	then
		ALIASES_LIST=$(jq -r .ALIASES_HTTP[] $i)
		for ALIAS in $ALIASES_LIST
		do
		 	echo "acl $(jq -r .DOMAIN $i)_http hdr(host) -i $ALIAS";
		done
	fi

done

echo 

#echo "use_backend letsencrypt_http if letsencrypt"

for i in `ls $DOMAIN_DIR|cut -d / -f2` ;  do
        
	if [[ "$(jq -r .DOMAIN $i)" != "" && "$(jq -r .HTTP_PORTS $i)" != "" && "$(jq -r .DOMAIN $i)" != "letsencrypt" ]]
	then
		echo "use_backend $(jq -r .DOMAIN $i)_http if $(jq -r .DOMAIN $i)_http"; 
	fi
done

echo

for i in `ls $DOMAIN_DIR|cut -d / -f2` ;  do

      	if [[ "$(jq -r .DOMAIN $i)" != "" && "$(jq -r .HTTP_PORT $i)" != "" ]]
      	then
      		echo "backend $(jq -r .DOMAIN $i)_http";
		echo "	mode http";
		echo "	server $(jq -r .DOMAIN $i) $(jq -r .LOCAL_NAME $i):$(jq -r .HTTP_PORT $i) send-proxy";
	fi
done

echo

echo "frontend https
";

cat "$global_https"
echo 

for i in `ls $DOMAIN_DIR|cut -d / -f2` ;  do

	if [[ "$(jq -r .DOMAIN $i)" != "" && "$(jq -r .HTTPS_PORT $i)" != "" && "$(jq -r .DOMAIN $i)" != "letsencrypt" ]]
	then
		echo "acl $(jq -r .DOMAIN $i)_https req_ssl_sni -i $(jq -r .DOMAIN $i)";
	fi
	if [[ "$(jq -r .HTTPS_PORT $i)" != "" && "$(jq -r .ALIASES_HTTPS[] $i)" != "" ]]
	then
		 ALIASES_LIST=$(jq -r .ALIASES_HTTPS[] $i)
	         for ALIAS in $ALIASES_LIST
	         do
	                   echo "acl $(jq -r .DOMAIN $i)_https req_ssl_sni -i $ALIAS";
	         done
	 fi
done

echo 

for i in `ls $DOMAIN_DIR|cut -d / -f2` ;  do

	if [[ "$(jq -r .DOMAIN $i)" != "" && "$(jq -r .HTTPS_PORT $i)" != "" && "$(jq -r .DOMAIN $i)" != "letsencrypt" ]]
	then
		echo "use_backend $(jq -r .DOMAIN $i)_https if $(jq -r .DOMAIN $i)_https"; 
	fi
done

echo 

for i in `ls $DOMAIN_DIR|cut -d / -f2` ;  do

      	if [[ "$(jq -r .DOMAIN $i)" != "" && "$(jq -r .HTTPS_PORT $i)" != "" && "$(jq -r .DOMAIN $i)" != "letsencrypt" ]]
      	then
      		echo "backend $(jq -r .DOMAIN $i)_https";
		echo "	option ssl-hello-chk";
		echo "	mode tcp";
		echo "	server $(jq -r .DOMAIN $i) $(jq -r .LOCAL_NAME $i):$(jq -r .HTTPS_PORT $i) check send-proxy";
	fi
done

} >> "$file";
echo "$DOMAIN" >> $PROXY_CONFIG_DIR/new_config
