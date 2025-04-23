#!/usr/bin/env sh
# shellcheck disable=SC2059

cleanup() {
  echo "Received signal: $1"
  if [ -n "$CRYPTOMATOR_ENTRYPOINT_PID" ] && [ -f "/proc/${CRYPTOMATOR_ENTRYPOINT_PID}/stat" ]; then
    echo "Cleaning up entrypoint.sh (PID: $CRYPTOMATOR_ENTRYPOINT_PID)"
    kill -s TERM "$CRYPTOMATOR_ENTRYPOINT_PID"
  fi
  echo 'Exiting init....'
  exit 0
}

# Trap signals to call the cleanup function
trap 'cleanup SIGTERM' TERM
trap 'cleanup SIGHUP' HUP
trap 'cleanup SIGINT' INT

CRYPTOMATOR_USER='cryptomator'

#------------------------------------------------------------------------------------------------------------------------------
# Header
#------------------------------------------------------------------------------------------------------------------------------
# Define color variables
export C_GREEN='\033[0;32m'
export C_MAGENTA='\033[0;35m'
export C_RED='\033[0;31m'
export C_NC='\033[0m' # No color

printf "${C_GREEN}#=======================================================================================#${C_NC}\n"
printf "${C_GREEN}#                   _                  _                          _        _            #${C_NC}\n"
printf "${C_GREEN}#  __ _ _ _  _ _ __| |_ ___ _ __  __ _| |_ ___ _ _ _____ __ _____| |__  __| |__ ___ __  #${C_NC}\n"
printf "${C_GREEN}# / _| '_| || | '_ \  _/ _ \ '  \/ _\` \|  _/ _ \ '_|___\ V  V / -_) '_ \/ _\` / _\` \ V / #${C_NC}\n"
printf "${C_GREEN}# \__|_|  \_, | .__/\__\___/_|_|_\__,_|\__\___/_|      \_/\_/\___|_.__/\__,_\__,_|\_/   #${C_NC}\n"
printf "${C_GREEN}#         |__/|_|                                                                       #${C_NC}\n"
printf "${C_GREEN}#---------------------------------------------------------------------------------------#${C_NC}\n"

if [ -n "${CRYPTOMATOR_UID}" ]; then
    printf "${C_GREEN}#${C_MAGENTA} Updating user ${CRYPTOMATOR_USER} UID to match env supplied UID (${C_GREEN}${CRYPTOMATOR_UID}${C_MAGENTA})...${C_NC}\n"
    usermod --uid "${CRYPTOMATOR_UID}" "${CRYPTOMATOR_USER}" | grep -v 'usermod: no changes'
    printf "${C_GREEN}#${C_MAGENTA} Changing ownership of stunnel config so ${C_GREEN}${CRYPTOMATOR_UID}${C_MAGENTA} can read (${C_GREEN}/etc/stunnel${C_MAGENTA})...${C_NC}\n"
    chown -R "${CRYPTOMATOR_UID}" /etc/stunnel
else
    printf "${C_GREEN}#${C_RED} No CRYPTOMATOR_UID supplied, required to drop privileges, exiting...${C_NC}\n"
    exit 11
fi

if [ -n "${CRYPTOMATOR_GID}" ]; then
    printf "${C_GREEN}#${C_MAGENTA} Updating group ${CRYPTOMATOR_USER} GID to match env supplied GID (${C_GREEN}${CRYPTOMATOR_GID}${C_MAGENTA})...${C_NC}\n"
    groupmod --gid "${CRYPTOMATOR_GID}" "${CRYPTOMATOR_USER}"
    printf "${C_GREEN}#${C_MAGENTA} Updating user ${CRYPTOMATOR_USER}'s default group to match env supplied GID (${C_GREEN}${CRYPTOMATOR_GID}${C_MAGENTA})...${C_NC}\n"
    usermod --gid "${CRYPTOMATOR_GID}" "${CRYPTOMATOR_USER}" | grep -v 'usermod: no changes'
else
    printf "${C_GREEN}#${C_RED} No CRYPTOMATOR_GID supplied, required to drop privileges, exiting...${C_NC}\n"
    exit 12
fi

if [ -n "${CRYPTOMATOR_UMASK}" ]; then
    printf "${C_GREEN}#${C_MAGENTA} Setting env supplied file umask (${C_GREEN}${CRYPTOMATOR_UMASK}${C_MAGENTA})...${C_NC}\n"
    umask "${CRYPTOMATOR_UMASK}"
fi

printf "${C_GREEN}#${C_MAGENTA} Dropping privileges and executing ${C_GREEN}/entrypoint.sh${C_MAGENTA}...${C_NC}\n"

# Don't use 'su', see http://jdebp.info/FGA/dont-abuse-su-for-dropping-privileges.html
/usr/bin/setpriv --reuid="${CRYPTOMATOR_UID}" --regid="${CRYPTOMATOR_GID}" --clear-groups -- sh -c '/entrypoint.sh' &
CRYPTOMATOR_ENTRYPOINT_PID=$!

printf "${C_GREEN}#${C_MAGENTA} entrypoint.sh PID: ${C_GREEN}${CRYPTOMATOR_ENTRYPOINT_PID}${C_NC}\n"

# Wait for the entrypoint command to finish, run the cleanup if it dies
wait $CRYPTOMATOR_ENTRYPOINT_PID
cleanup EXIT
