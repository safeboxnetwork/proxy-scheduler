#!/bin/sh

# Set env variables
	
	DOMAIN_DIR=$DOMAIN_DIR
	CERT_DIR=$CERT_DIR
	DOMAIN=$1


# generate dhparam file
openssl dhparam -out $CERT_DIR/dhparam.pem 4096 

create_self_signed_certificate() { 
# generate key
openssl req -x509 -newkey rsa:4096 -keyout $CERT_DIR/key.pem -out $CERT_DIR/cert.pem -days 365 -sha256 -nodes -subj '/CN=$DOMAIN'

}


if [[ "$(ls -A $CERT_DIR)" == "" ]]; then
	echo "$DOMAIN not contains certificates, creates new."
	create_self_signed_certificate;
fi
