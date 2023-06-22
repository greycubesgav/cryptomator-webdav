#!/usr/bin/env bash

JAR_LOCATION='/usr/local/bin/cryptomator-cli.jar'
CRYPTOMATOR_PASSFILE_LOC='/tmp/vault_pass'
CRYPTOMATOR_BIND='0.0.0.0'

# Write the password to a tmp file to prevent it appearing in the process list
if [[ ! -f "${CRYPTOMATOR_PASSFILE_LOC}" ]]; then
    touch "${CRYPTOMATOR_PASSFILE_LOC}"
    echo "${CRYPTOMATOR_VAULT_PASS}" > "${CRYPTOMATOR_PASSFILE_LOC}"
    chmod 0400 "${CRYPTOMATOR_PASSFILE_LOC}"
fi

echo "Starting cryptomator-cli, will listen on: http://${CRYPTOMATOR_BIND}:${CRYPTOMATOR_PORT}/${CRYPTOMATOR_VAULT_NAME}"
echo "------------------------------"
exec java -jar "${JAR_LOCATION}" --bind="${CRYPTOMATOR_BIND}" --port="${CRYPTOMATOR_PORT}" \
    --vault "${CRYPTOMATOR_VAULT_NAME}=${CRYPTOMATOR_VAULT_PATH}"  \
    --passwordfile "${CRYPTOMATOR_VAULT_NAME}=${CRYPTOMATOR_PASSFILE_LOC}"
