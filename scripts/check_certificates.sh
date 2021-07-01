#!/bin/sh

# Set env variables
	
	DOMAIN_DIR=$DOMAIN_DIR
	DOMAIN=$1
	CERT_DIR=$CERT_DIR/$DOMAIN



create_self_signed_certificate() { 

# generate dhparam file
openssl dhparam -dsaparam -out $CERT_DIR/dhparam.pem 4096 

# generate key
openssl req -x509 -newkey rsa:4096 -keyout $CERT_DIR/key.pem -out $CERT_DIR/fullchain.pem -days 365 -sha256 -nodes -subj "/CN=$DOMAIN"

}


if [[ "$(ls -A $CERT_DIR)" == "" ]]; then
	echo "$DOMAIN not contains certificates, creates new."
	mkdir -p $CERT_DIR;
	create_self_signed_certificate;
fi
