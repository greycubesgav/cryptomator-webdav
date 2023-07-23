#!/usr/bin/env sh
##!/usr/bin/env bash
# shellcheck disable=SC1072,SC2120,SC2059

sleep_with_dots() {
  msg="$1"
  seconds="$2"
  i=1
  while [ "$i" -le "$seconds" ]; do
    sleep 1
    echo "${msg}${i}/${seconds}"
    i=$((i + 1))
  done
}

# Define steps to clean up container parts when exiting
cleanup() {
  echo "Received signal: $1"
  if [ -n "$CRYPTOMATOR_PID" ]; then
    echo "Cleaning up cryptomator-cli (PID: $CRYPTOMATOR_PID)"
    kill -s TERM "$CRYPTOMATOR_PID"
  fi
  if [ -n "$STUNNEL_PID" ]; then
    echo "Cleaning up stunnel (PID: $STUNNEL_PID)"
    kill -s TERM "$STUNNEL_PID"
  fi
  echo 'Exiting entrypoint....'
  exit 0
}

# Trap signals to call the cleanup function
trap 'cleanup SIGTERM' TERM
trap 'cleanup SIGHUP' HUP
trap 'cleanup SIGINT' INT

#------------------------------------------------------------------------------------------------------------------------------
# Ouput status information on the current user/group and umask
CUR_UMASK=$(umask)
CUR_UID=$(setpriv -d | grep '^uid' | awk '{print $2}')
CUR_GID=$(setpriv -d | grep '^gid' | awk '{print $2}')

printf "${C_GREEN}#----------------------------------------------------------------------------------------${C_NC}\n"
printf "${C_GREEN}#${C_NC} uid: ${C_GREEN}%s${C_NC} gid: ${C_GREEN}%s${C_NC} umask: ${C_GREEN}%s${C_NC}\n" "$CUR_UID" "$CUR_GID" "$CUR_UMASK"
printf "${C_GREEN}#----------------------------------------------------------------------------------------${C_NC}\n"
printf "${C_GREEN}#${C_NC} cryptomator-cli listening on                   : ${C_MAGENTA}%s${C_NC}\n" "webdav://127.0.0.1:8080"
printf "${C_GREEN}#${C_NC} stunnel listening on                           : ${C_MAGENTA}%s${C_NC}\n" "https://0.0.0.0:8443"
printf "${C_GREEN}#${C_NC} TLS secured webdav cryptomator vault access on : ${C_GREEN}%s${C_NC}\n" "webdavs://containerIP:8443/vault"
printf "${C_GREEN}#----------------------------------------------------------------------------------------${C_NC}\n"

#------------------------------------------------------------------------------------------------------------------------------

CRYPTOMATOR_PASSFILE=0 # Assume we've not been given a passfile to work with
CRYPTOMATOR_VAULT_PASSFILE='/vault.pass' # Set the default local location where we expect the vault password file to be mounted

# If we've been given a vault password file location, use it, else use a default which we'll create from the environment env
if [ -f "${CRYPTOMATOR_VAULT_PASSFILE}" ]; then
    if [ ! -r "${CRYPTOMATOR_VAULT_PASSFILE}" ]; then
        echo "Error: ${CRYPTOMATOR_VAULT_PASSFILE} is mounted but is not readable:" >&2
        echo "Error: Attempting to stat file for debug purposes..." >&2
        stat "${CRYPTOMATOR_VAULT_PASSFILE}" >&2
        echo "Exiting...."
        exit 1
    fi
    echo "Using mounted passfile: ${CRYPTOMATOR_VAULT_PASSFILE}"
    CRYPTOMATOR_PASSFILE=1
    CRYPTOMATOR_INTERNAL_PASSFILE_LOC="$CRYPTOMATOR_VAULT_PASSFILE"
else
    # We've not been given a password file so assume we were given one in the environment variables
    echo "Using password provided in environment variable"
    CRYPTOMATOR_INTERNAL_PASSFILE_LOC='/dev/shm/cryptomator_vault_pass'
    echo "Creating CRYPTOMATOR_INTERNAL_PASSFILE_LOC file at $CRYPTOMATOR_INTERNAL_PASSFILE_LOC"
    install -o cryptomator -g cryptomator -m 0600 /dev/null "${CRYPTOMATOR_INTERNAL_PASSFILE_LOC}"

    echo "Writing password to file $CRYPTOMATOR_INTERNAL_PASSFILE_LOC"
    echo "${CRYPTOMATOR_VAULT_PASS}" > "${CRYPTOMATOR_INTERNAL_PASSFILE_LOC}"

    # Bank out the password from the environment
    CRYPTOMATOR_VAULT_PASS=''
    export CRYPTOMATOR_VAULT_PASS
fi

# Start cryptomator-cli listening on localhost
echo 'Starting cryptomator-cli in background, will share on: webdav://127.0.0.1:8080/vault/'

# Note: Currenly hardcoded path for alpine java location
/usr/bin/java -XX:-UsePerfData -jar '/usr/local/bin/cryptomator-cli.jar' --bind='127.0.0.1' --port='8080' \
    --vault "vault=/vault"  \
    --passwordfile "vault=${CRYPTOMATOR_INTERNAL_PASSFILE_LOC}" &
CRYPTOMATOR_PID=$!
echo "cryptomator-cli PID: ${CRYPTOMATOR_PID}"

# If we were not given a CRYPTOMATOR_VAULT_PASSFILE, we give time for cryptomator-cli to start, then clean up our temporary file
if [ "$CRYPTOMATOR_PASSFILE" = 0 ]; then
    echo "Waiting for cryptomator-cli to start..."
    sleep_with_dots "Waiting for cryptomator-cli... " 5
    echo "Removing temporary pass file ${CRYPTOMATOR_INTERNAL_PASSFILE_LOC}"
    rm -f "${CRYPTOMATOR_INTERNAL_PASSFILE_LOC}"
fi
echo '#-------------------------------------------------------'

# Start stunnel to wrap the cryptomator-cli webdav in a TLS tunnel and export on container lan ip
echo "Starting stunnel, TLS tunneling 127.0.0.1:8080 => 0.0.0.0:8443"
/usr/bin/stunnel /etc/stunnel/stunnel.conf &
STUNNEL_PID=$!
echo "stunnel PID: ${STUNNEL_PID}"
echo '#-------------------------------------------------------'

# Wait for the stunnel command to finish, run the cleanup if it dies
wait $STUNNEL_PID
cleanup EXIT