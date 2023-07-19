#!/usr/bin/env bash

sleep_with_dots() {
  local seconds=$1
  for ((i = 0; i < seconds; i++)); do
    sleep 1
    echo "Waiting... " $((i + 1))
  done
}

# Show the current UID and GID of the running process
echo "Currently running as UIDs/GIDs:"
grep '[UG]id' < '/proc/self/status'

# Set the umask to ensure files are not created world readable
umask 0026
echo "With umask of: $(umask)"

CRYPTOMATOR_PASSFILE=0 # Assume we've not been given a passfile to work with
CRYPTOMATOR_VAULT_PASSFILE='/vault.pass'

# If we've been given a vault password file location, use it, else use a default which we'll create from the environment env
if [[ -f "${CRYPTOMATOR_VAULT_PASSFILE}" ]]; then
    if [[ ! -r "${CRYPTOMATOR_VAULT_PASSFILE}" ]]; then
        CRYPTOMATOR_PASSFILE=1
        echo "Error: ${CRYPTOMATOR_VAULT_PASSFILE} is mounted but is not readable:" >&2
        echo "Error: Attempting to stat file..." >&2
        stat "${CRYPTOMATOR_VAULT_PASSFILE}" >&2
        echo "Exiting...."
        exit 1
    fi
    echo "Using mounted passfile"
    CRYPTOMATOR_INTERNAL_PASSFILE_LOC="$CRYPTOMATOR_VAULT_PASSFILE"
else
    # We've not been given a password file so assume we were given one in the environment variables
    echo "Using password provided in environment"
    CRYPTOMATOR_INTERNAL_PASSFILE_LOC='/dev/shm/cryptomator_vault_pass'
    echo "Creating CRYPTOMATOR_INTERNAL_PASSFILE_LOC file at $CRYPTOMATOR_INTERNAL_PASSFILE_LOC"
    install -o cryptomator -g cryptomator -m 0600 /dev/null "${CRYPTOMATOR_INTERNAL_PASSFILE_LOC}"

    echo "Writing password to file $CRYPTOMATOR_INTERNAL_PASSFILE_LOC"
    echo "${CRYPTOMATOR_VAULT_PASS}" > "${CRYPTOMATOR_INTERNAL_PASSFILE_LOC}"

    # Bank out the password from the environment
    export -n CRYPTOMATOR_VAULT_PASS
fi

# Start cryptomator-cli listening on localhost
echo 'Starting cryptomator-cli in background, will share on: http://127.0.0.1:8080/vault/'
echo "------------------------------"
java -XX:-UsePerfData -jar '/usr/local/bin/cryptomator-cli.jar' --bind='127.0.0.1' --port='8080' \
    --vault "vault=/vault"  \
    --passwordfile "vault=${CRYPTOMATOR_INTERNAL_PASSFILE_LOC}" &

# If we were not given a CRYPTOMATOR_VAULT_PASSFILE, we clean up our temporary file
if [[ "$CRYPTOMATOR_PASSFILE" == 0 ]]; then
    echo "Waiting for cryptomator-cli to start..."
    sleep_with_dots 5
    echo "Removing temporary pass file ${CRYPTOMATOR_INTERNAL_PASSFILE_LOC}"
    rm -f "${CRYPTOMATOR_INTERNAL_PASSFILE_LOC}"
fi

# Start stunnel to wrap the cryptomator-cli webdav in a TLS tunnel and export on container lan ip
echo "Starting stunnel, will share on: https://0.0.0.0:8443/vault/"
exec /usr/local/bin/stunnel
