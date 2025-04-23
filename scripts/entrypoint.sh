#!/usr/bin/env sh
# shellcheck disable=SC1072,SC2120,SC2059

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

    # Blank out the password from the environment
    CRYPTOMATOR_VAULT_PASS=''
    export CRYPTOMATOR_VAULT_PASS
fi

CRYPTOMATOR_LISTEN_IP='127.0.0.1'
CRYPTOMATOR_LISTEN_PORT='8080'
CRYPTOMATOR_INTERNAL_MAX_WAIT_TIME=5

# Start cryptomator-cli listening on localhost
echo "Starting cryptomator-cli in background, will share on: webdav://${CRYPTOMATOR_LISTEN_IP}:${CRYPTOMATOR_LISTEN_PORT}/vault/"

# Note: Currenly hardcoded path for alpine java location

if [ "$CRYPTOMATOR_DEBUG" -eq 1 ]; then
    printf "cryptomator-cli command: /opt/cryptomator-cli/bin/cryptomator-cli unlock \
  --mounter=org.cryptomator.frontend.webdav.mount.FallbackMounter \
  --volumeId='vault' \
  --loopbackPort=\"${CRYPTOMATOR_LISTEN_PORT}\" \
  --password:file=\"${CRYPTOMATOR_INTERNAL_PASSFILE_LOC}\" \
  /vault &"
fi

/opt/cryptomator-cli/bin/cryptomator-cli unlock \
  --mounter=org.cryptomator.frontend.webdav.mount.FallbackMounter \
  --volumeId='vault' \
  --loopbackPort="${CRYPTOMATOR_LISTEN_PORT}" \
  --password:file="${CRYPTOMATOR_INTERNAL_PASSFILE_LOC}" \
  /vault &

CRYPTOMATOR_PID=$!
echo "cryptomator-cli PID: ${CRYPTOMATOR_PID}"

start_time=$(date +%s)
elapsed_time=$(($(date +%s) - start_time))
#max_time="$CRYPTOMATOR_INTERNAL_MAX_WAIT_TIME"
cryptomator_port_ready=0
cryptomator_vault_ready=0

echo -n "Waiting for cryptomator-cli to begin..."
# Keep checking if the port is available until the maximum wait time is reached
while [ $((elapsed_time <= CRYPTOMATOR_INTERNAL_MAX_WAIT_TIME)) -eq 1 ] && [ $cryptomator_port_ready -eq 0 ]; do
    nc -n -z -w 1 "$CRYPTOMATOR_LISTEN_IP" "$CRYPTOMATOR_LISTEN_PORT"  >/dev/null 2>&1
    ret=$?
    echo -n "."
    if [ $ret -eq 0 ]; then
        echo
        echo "Cryptomator-cli port is now available on ${CRYPTOMATOR_LISTEN_IP}:${CRYPTOMATOR_LISTEN_PORT}"
        cryptomator_port_ready=1
        break
    fi
    # Sleep for a brief period before retrying
    sleep 0.1
    elapsed_time=$(($(date +%s) - start_time))
done

# Whether we succeeded or not we remove the temporary pass file ASAP
# If we were not given a CRYPTOMATOR_VAULT_PASSFILE clean up our temporary file
if [ "$CRYPTOMATOR_PASSFILE" = 0 ]; then
    echo "Removing temporary pass file ${CRYPTOMATOR_INTERNAL_PASSFILE_LOC}"
    rm -f "${CRYPTOMATOR_INTERNAL_PASSFILE_LOC}"
fi

# If we have not managed to connect to cryptomator-cli in the allotted time, exit
if [ "$cryptomator_port_ready" -ne 1 ]; then
    echo "Error: Cryptomator-cli port could not be reached after $CRYPTOMATOR_INTERNAL_MAX_WAIT_TIME seconds." >&2
    echo "Ensuring cryptomator process is not still running in the background.."
    if [ -f "/proc/${CRYPTOMATOR_PID}/stat" ]; then
        echo "Error: Cryptomator-cli still running in the background. PID: $CRYPTOMATOR_PID" >&2
        echo "Killing...." >&2
        kill $CRYPTOMATOR_PID
    fi
    echo "Exiting entrypoint.sh!" >&2
    exit 1
fi

echo -n "Waiting for cryptomator-cli to share the vault..."
# Keep checking if the share is available until the maximum wait time is reached
while [ $((elapsed_time <= CRYPTOMATOR_INTERNAL_MAX_WAIT_TIME)) -eq 1 ] && [ $cryptomator_vault_ready -eq 0 ]; do
    curl --silent --fail --show-error --max-time 1 "http://${CRYPTOMATOR_LISTEN_IP}:${CRYPTOMATOR_LISTEN_PORT}/vault/"  >/dev/null 2>&1
    ret=$?
    echo -n "."
    if [ $ret -eq 0 ]; then
        echo
        echo "Cryptomator-cli share is now available."
        cryptomator_vault_ready=1
        break
    fi
    # Sleep for a brief period before retrying
    sleep 0.1
    elapsed_time=$(($(date +%s) - start_time))
done

# If we have not managed to connect to cryptomator-cli in the allotted time, exit
if [ "$cryptomator_vault_ready" -ne 1 ]; then
    echo "Error: cryptomator-cli vault could not be reached after $CRYPTOMATOR_INTERNAL_MAX_WAIT_TIME seconds." >&2
    echo "Ensuring cryptomator process is not still running in the background.."
    if [ -f "/proc/${CRYPTOMATOR_PID}/stat" ]; then
        echo "Error: Cryptomator-cli still running in the background. PID: $CRYPTOMATOR_PID" >&2
        echo "Killing...." >&2
        kill $CRYPTOMATOR_PID
    fi
    echo "Exiting entrypoint.sh" >&2
    exit 2
fi

echo '#-------------------------------------------------------'

# Start stunnel to wrap the cryptomator-cli webdav in a TLS tunnel and export on container lan ip
# ToDo: Add code to update stunnel.conf based on the CRYPTOMATOR_LISTEN_IP and CRYPTOMATOR_LISTEN_PORT above
echo "Starting stunnel, TLS tunneling ${CRYPTOMATOR_LISTEN_IP}:${CRYPTOMATOR_LISTEN_PORT} => 0.0.0.0:8443"
/usr/bin/stunnel /etc/stunnel/stunnel.conf &
STUNNEL_PID=$!
echo "stunnel PID: ${STUNNEL_PID}"
echo '#-------------------------------------------------------'

# Wait for the stunnel command to finish, run the cleanup if it dies
wait $STUNNEL_PID
cleanup EXIT