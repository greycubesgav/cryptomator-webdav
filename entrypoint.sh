#!/usr/bin/env bash
# shellcheck disable=SC1072

sleep_with_dots() {
  local seconds=$1
  for ((i = 0; i < seconds; i++)); do
    sleep 1
    echo "Waiting... " $((i + 1))
  done
}

#------------------------------------------------------------------------------------------------------------------------------
# Header
#------------------------------------------------------------------------------------------------------------------------------
# Define color variables
C_GREEN='\033[0;32m'
C_MAGENTA='\033[0;35m'
C_NC='\033[0m' # No color

UMASK=$(umask)
UID=$(grep 'Uid' < '/proc/self/status' | awk '{print $2}')
GID=$(grep 'Gid' < '/proc/self/status' | awk '{print $2}')

IFS='' read -r -d '' banner <<"EOF"
#=======================================================================================#
#                   _                  _                          _        _            #
#  __ _ _ _  _ _ __| |_ ___ _ __  __ _| |_ ___ _ _ _____ __ _____| |__  __| |__ ___ __  #
# / _| '_| || | '_ \  _/ _ \ '  \/ _` |  _/ _ \ '_|___\ V  V / -_) '_ \/ _` / _` \ V /  #
# \__|_|  \_, | .__/\__\___/_|_|_\__,_|\__\___/_|      \_/\_/\___|_.__/\__,_\__,_|\_/   #
#         |__/|_|                                                                       #
#---------------------------------------------------------------------------------------#
EOF
echo -en "${C_GREEN}${banner}${C_NC}"
echo -e "${C_GREEN}#${C_NC} cryptomator-cli listening on                   : ${C_MAGENTA}webdav://127.0.0.1:8080${C_NC}"
echo -e "${C_GREEN}#${C_NC} stunnel listening on                           : ${C_MAGENTA}https://0.0.0.0:8443${C_NC}"
echo -e "${C_GREEN}#${C_NC} TLS secured webdav cryptomator vault access on : ${C_GREEN}webdavs://containerIP:8443/vault${C_NC}"
echo -e "${C_GREEN}#----------------------------------------------------------------------------------------${C_NC}"
echo -e "${C_GREEN}#${C_NC} uid: ${C_GREEN}${UID}${C_NC} gid: ${C_GREEN}${GID}${C_NC} umask: ${C_GREEN}${UMASK}${C_NC}"
echo -e "${C_GREEN}#----------------------------------------------------------------------------------------${C_NC}"

#------------------------------------------------------------------------------------------------------------------------------

CRYPTOMATOR_PASSFILE=0 # Assume we've not been given a passfile to work with
CRYPTOMATOR_VAULT_PASSFILE='/vault.pass'

# If we've been given a vault password file location, use it, else use a default which we'll create from the environment env
if [[ -f "${CRYPTOMATOR_VAULT_PASSFILE}" ]]; then
    if [[ ! -r "${CRYPTOMATOR_VAULT_PASSFILE}" ]]; then
        echo "Error: ${CRYPTOMATOR_VAULT_PASSFILE} is mounted but is not readable:" >&2
        echo "Error: Attempting to stat file..." >&2
        stat "${CRYPTOMATOR_VAULT_PASSFILE}" >&2
        echo "Exiting...."
        exit 1
    fi
    echo "Using mounted passfile: ${CRYPTOMATOR_VAULT_PASSFILE}"
    CRYPTOMATOR_PASSFILE=1
    CRYPTOMATOR_INTERNAL_PASSFILE_LOC="$CRYPTOMATOR_VAULT_PASSFILE"
else
    # We've not been given a password file so assume we were given one in the environment variables
    echo 'Using password provided in environment variable $CRYPTOMATOR_VAULT_PASS'
    CRYPTOMATOR_INTERNAL_PASSFILE_LOC='/dev/shm/cryptomator_vault_pass'
    echo "Creating CRYPTOMATOR_INTERNAL_PASSFILE_LOC file at $CRYPTOMATOR_INTERNAL_PASSFILE_LOC"
    install -o cryptomator -g cryptomator -m 0600 /dev/null "${CRYPTOMATOR_INTERNAL_PASSFILE_LOC}"

    echo "Writing password to file $CRYPTOMATOR_INTERNAL_PASSFILE_LOC"
    echo "${CRYPTOMATOR_VAULT_PASS}" > "${CRYPTOMATOR_INTERNAL_PASSFILE_LOC}"

    # Bank out the password from the environment
    export -n CRYPTOMATOR_VAULT_PASS
fi

# Start cryptomator-cli listening on localhost
echo '#----------------------------------------------------------------------------------------'
echo 'Starting cryptomator-cli in background, will share on: webdav://127.0.0.1:8080/vault/'
echo '#----------------------------------------------------------------------------------------'
java -XX:-UsePerfData -jar '/usr/local/bin/cryptomator-cli.jar' --bind='127.0.0.1' --port='8080' \
    --vault "vault=/vault"  \
    --passwordfile "vault=${CRYPTOMATOR_INTERNAL_PASSFILE_LOC}" &
CRYPTOMATOR_PID=$!


# If we were not given a CRYPTOMATOR_VAULT_PASSFILE, we clean up our temporary file
if [[ "$CRYPTOMATOR_PASSFILE" == 0 ]]; then
    echo "Waiting for cryptomator-cli to start..."
    sleep_with_dots 5
    echo "Removing temporary pass file ${CRYPTOMATOR_INTERNAL_PASSFILE_LOC}"
    rm -f "${CRYPTOMATOR_INTERNAL_PASSFILE_LOC}"
fi

# Start stunnel to wrap the cryptomator-cli webdav in a TLS tunnel and export on container lan ip
echo "Starting stunnel, TLS tunneling 127.0.0.1:8080 => 0.0.0.0:8443"
echo '#----------------------------------------------------------------------------------------'
exec /usr/local/bin/stunnel
