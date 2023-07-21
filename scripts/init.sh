#!/usr/bin/env bash

CRYPTOMATOR_USER='cryptomator'

#------------------------------------------------------------------------------------------------------------------------------
# Header
#------------------------------------------------------------------------------------------------------------------------------
# Define color variables
export C_GREEN='\033[0;32m'
export C_MAGENTA='\033[0;35m'
export C_NC='\033[0m' # No color


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

if [ -n "${CRYPTOMATOR_UID}" ]; then
    echo -e "${C_GREEN}#${C_MAGENTA} Updating user ${CRYPTOMATOR_USER} UID to match env supplied UID (${CRYPTOMATOR_UID})...${C_NC}"
    usermod --uid "${CRYPTOMATOR_UID}" "${CRYPTOMATOR_USER}" | grep -v 'usermod: no changes'
fi

if [ -n "${CRYPTOMATOR_GID}" ]; then
    echo -e "${C_GREEN}#${C_MAGENTA} Updating group ${CRYPTOMATOR_USER} GID to match env supplied GID (${CRYPTOMATOR_GID})...${C_NC}"
    groupmod --gid "${CRYPTOMATOR_GID}" "${CRYPTOMATOR_USER}"
    echo -e "${C_GREEN}#${C_MAGENTA} Updating user ${CRYPTOMATOR_USER}'s default group to match env supplied GID (${CRYPTOMATOR_GID})...${C_NC}"
    usermod --gid "${CRYPTOMATOR_GID}" "${CRYPTOMATOR_USER}" | grep -v 'usermod: no changes'
fi

if [ -n "${CRYPTOMATOR_UMASK}" ]; then
    echo -e "${C_GREEN}#${C_MAGENTA} Setting env supplied file umask (${CRYPTOMATOR_UMASK})...${C_NC}"
    umask "${CRYPTOMATOR_UMASK}"
fi

echo -e "${C_GREEN}#${C_MAGENTA} Dropping privileges...${C_NC}"
# Don't use 'su', see http://jdebp.info/FGA/dont-abuse-su-for-dropping-privileges.html
setpriv --reuid="${CRYPTOMATOR_UID}" --regid="${CRYPTOMATOR_GID}" --clear-groups -- bash -c '/entrypoint.sh'
