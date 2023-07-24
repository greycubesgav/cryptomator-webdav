
all:
	@echo "Default target"


test-client-cert-success:
	curl -i --cacert config/stunnel.pem --cert config/stunnel.pem https://127.0.0.1:18081/vault/

test-client-cert-fail:
	curl -i --cacert config/stunnel.pem https://127.0.0.1:18081/vault/

test-rclone-fail:
	rclone ls vault:

test-rclone-cert-fail:
	rclone --ca-cert config/stunnel.pem ls vault:

test-rclone-cert-pass:
	rclone --ca-cert config/stunnel.pem --client-cert config/stunnel.pem --client-key config/stunnel.pem ls vault:

gen-cert:
	openssl req -new -x509 -days 3650 -config config/pem.conf -out config/stunnel.pem -keyout config/stunnel.pem

view-cert:
	openssl x509 -text -in config/stunnel.pem

view-pkc-cert:
	openssl pkcs12 -info -in config/stunnel.p12

convert-cert:
	openssl pkcs12 -export -legacy -in config/stunnel.pem -inkey config/stunnel.pem -out config/stunnel.p12 -nodes

openssl-remote-cert-fail:
	openssl s_client -connect 127.0.0.1:18081

openssl-remote-cert-pass:
	openssl s_client -cert config/stunnel.pem -connect 127.0.0.1:18081

run-dev-build:
	docker-compose run --service-ports cryptomator-webdav-dev
