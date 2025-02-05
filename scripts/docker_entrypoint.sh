#!/bin/bash
set -e

ssl_dir="/opt/ssl"

if [ ! "$SERVER_HOSTNAME" ]; then export SERVER_HOSTNAME=example.com; fi


#If LDAP_TLS_CACERT is set then write it out as a file
#and set up the LDAP client conf to use it.

if [ "$LDAP_TLS_CACERT" ]; then
  echo "$LDAP_TLS_CACERT" >/opt/ca.crt
  sed -i "s/TLS_CACERT.*/TLS_CACERT \/opt\/ca.crt/" /etc/ldap/ldap.conf
fi


########################
#If there aren't any SSL certs then create a CA and then CA-signed certificate

if [ ! -f "${ssl_dir}/server.key" ] && [ ! -f "${ssl_dir}/server.crt" ]; then

  mkdir -p $ssl_dir
  confout="${ssl_dir}/conf"
  keyout="${ssl_dir}/server.key"
  certout="${ssl_dir}/server.crt"
  cakey="${ssl_dir}/ca.key"
  cacert="${ssl_dir}/ca.crt"
  serialfile="${ssl_dir}/serial"

  echo "Generating CA key"
  openssl genrsa -out $cakey 2048
  if [ $? -ne 0 ]; then exit 1 ; fi

  echo "Generating CA certificate"
  openssl req \
          -x509 \
          -new \
          -nodes \
          -subj "/C=GB/ST=GB/L=GB/O=CA/OU=CA/CN=Wheelybird" \
          -key $cakey \
          -sha256 \
          -days 7300 \
          -out $cacert
  if [ $? -ne 0 ]; then exit 1 ; fi

  echo "Generating openssl configuration"

  cat <<EoCertConf>$confout
subjectAltName = DNS:${SERVER_HOSTNAME},IP:127.0.0.1
extendedKeyUsage = serverAuth
EoCertConf

  echo "Generating server key..."
  openssl genrsa -out $keyout 2048
  if [ $? -ne 0 ]; then exit 1 ; fi

  echo "Generating server signing request..."
  openssl req \
               -subj "/CN=${SERVER_HOSTNAME}" \
               -sha256 \
               -new \
               -key $keyout \
               -out /tmp/server.csr
  if [ $? -ne 0 ]; then exit 1 ; fi

  echo "Generating server cert..."
  openssl x509 \
                -req \
                -days 7300 \
                -sha256 \
                -in /tmp/server.csr \
                -CA $cacert \
                -CAkey $cakey \
                -CAcreateserial \
                -CAserial $serialfile \
                -out $certout \
                -extfile $confout
  if [ $? -ne 0 ]; then exit 1 ; fi

fi


########################
#Create Apache config


if [ -f "/opt/tls/chain.pem" ]; then $ssl_chain="SSLCertificateChainFile /opt/tls/chain.pem"; fi

cat <<EoC >/etc/apache2/sites-enabled/lum.conf

Listen 443

<VirtualHost *:80>

 RewriteEngine On
 RewriteRule ^/?(.*) https://%{SERVER_NAME}/\$1 [R,L]

</VirtualHost>

<VirtualHost _default_:443>

 ServerName $SERVER_HOSTNAME
 DocumentRoot /opt/ldap_user_manager

 DirectoryIndex index.php index.html

 <Directory /opt/ldap_user_manager>
   Require all granted
 </Directory>

 SSLEngine On
 SSLCertificateFile /opt/ssl/server.crt
 SSLCertificateKeyFile /opt/ssl/server.key
 $ssl_chain

 php_value include_path "/opt/ldap_user_manager/includes"

</VirtualHost>
EoC


########################
#Run Apache

# first arg is `-f` or `--some-option`
if [ "${1#-}" != "$1" ]; then
	set -- apache2-foreground "$@"
fi

exec "$@"
