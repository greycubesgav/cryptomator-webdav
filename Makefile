
all: build-cryptomator-webdav
	@echo "Default target"

test-curl-cacert:
	curl -i --cacert config/stunnel.pem https://127.0.0.1:18081/vault/

test-curl-cacert-clientcert:
	curl -i --cacert config/stunnel.pem --cert config/stunnel.pem https://127.0.0.1:18081/vault/

test-rclone:
	rclone ls vault:

test-rclone-cacert:
	rclone --ca-cert config/stunnel.pem ls vault:

test-rclone-cacert-clientcert:
	rclone --ca-cert config/stunnel.pem --client-cert config/stunnel.pem --client-key config/stunnel.pem ls vault:

gen-cert:
	openssl req -new -x509 -days 3650 -config config/pem.conf -out config/stunnel.pem -keyout config/stunnel.pem

view-cert:
	openssl x509 -text -in config/stunnel.pem

view-pkc-cert:
	openssl pkcs12 -info -in config/stunnel.p12

convert-cert:
	openssl pkcs12 -export -legacy -in config/stunnel.pem -inkey config/stunnel.pem -out config/stunnel.p12 -nodes

openssl-remote-connect:
	openssl s_client -connect 127.0.0.1:18081

openssl-remote-client-cert:
	openssl s_client -cert config/stunnel.pem -connect 127.0.0.1:18081

run-dev-env:
	docker-compose run cryptomator-webdav-env

run-dev-build:
	docker-compose run --rm --remove-orphans --service-ports  cryptomator-webdav-dev

run-dev-build-passfile:
	docker-compose run  --rm --remove-orphans --service-ports cryptomator-webdav-passfile-dev

up-cryptomator-webdav:
	docker-compose up cryptomator-webdav

build-cryptomator-webdav:
	docker-compose build cryptomator-webdav

test-cryptomator-webdav-http:
	curl -X PROPFIND http://127.0.0.1:8080/vault/ -H "Depth: 1"

test-cryptomator-webdav-https:
	curl -k -X PROPFIND https://127.0.0.1:8443/vault/ -H "Depth: 1"

test-cryptomator-webdav-https-host:
	curl -k -X PROPFIND https://127.0.0.1:18081/vault/ -H "Depth: 1"