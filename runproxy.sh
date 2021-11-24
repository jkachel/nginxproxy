#!/bin/bash

datestr=`date '+%Y%m%d-%H%M%S'`

start_nginx () {
	docker run -d --restart unless-stopped -p 80:80 -p 443:443 -v `pwd`/logs:/var/log/nginx --network httpproxy --name nginxproxy nginxproxy
}

while getopts "hrc" arg
do
	case $arg in
		r) 
			echo "Stopping and removing existing nginxproxy container (probably be some errors here)"
			docker stop nginxproxy
			docker rm nginxproxy
			echo "Rebuilding container"
			docker build -t nginxproxy .
			echo "Rotating tires"
			sudo chown -R jkachel:jkachel logs
			sudo chmod -R a+rw logs
			cp logs/access.log logs/access-$datestr.log
			cp logs/error.log logs/error-$datestr.log
			gzip logs/*-$datestr.log
			echo -n "" > logs/access.log
			echo -n "" > logs/error.log
			echo "Running new copy" 
			start_nginx
			exit
			;;
		c)
			echo -e "Removing newcert.* from the SSL folder..."
			rm config/ssl/newcert.* 
			echo -e "Cleaning up and copying the OpenSSL config over..."
			docker cp config/ssl/openssl.cnf nginxproxy:/etc/nginx/ssl/openssl.cnf
			docker exec nginxproxy /bin/sh -c "rm /etc/nginx/ssl/newcert.*"
			echo -e "Generating new certificate request and key..."
			docker exec nginxproxy openssl req -new -keyout /etc/nginx/ssl/newcert.key -out /etc/nginx/ssl/newcert.csr -nodes -config /etc/nginx/ssl/openssl.cnf
			docker cp nginxproxy:/etc/nginx/ssl/newcert.key config/ssl/newcert.key
			docker cp nginxproxy:/etc/nginx/ssl/newcert.csr config/ssl/newcert.csr
			echo -e "Your new CSR and key should be in config/ssl/newcert.csr and newcert.key."
			echo -e "Once you've issued the new cert, the cert and key need to replace the cert.key and cert.pem files respectivey."
			echo -e "Then, rebuild the container and your new cert should be active."
			exit
			;;
		h)
			echo -e "Stops, cleans up, rebuilds, and reruns the nginxproxy container.\n"
			echo -e "$0 -r"
			echo -e "\tRebuilds and re-runs the proxy container"
			echo -e "$0 -h"
			echo -e "\tDisplays this help"
			echo -e "$0 -c"
			echo -e "\tGenerate a CSR based on config/ssl/openssl.cnf (for issuing later)"
			echo -e "\tProxy will need to be running for this"
			echo -e "\n"
			exit
			;;
		*)
			;;

	esac
done

echo -e "Stopping/removing nginxproxy and restarting....\n"
docker stop nginxproxy
docker rm nginxproxy
start_nginx
