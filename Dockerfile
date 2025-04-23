#------------------------------------------------------------------------------------------
# Stage 1: Build container
#------------------------------------------------------------------------------------------
FROM debian:sid-20250407-slim AS builder

# Install ssl dependencies
RUN apt-get update && apt-get install --no-install-recommends -y openssl unzip && rm -rf /var/lib/apt/lists/*

# Create a new selfsigned certificate
COPY config/pem.conf /root/pem.conf
RUN openssl req -newkey rsa:2048 -nodes -keyout /root/stunnel.pem -x509 -days 3650 -out /root/stunnel.pem -config /root/pem.conf

# Copy over cryptomator-cli package and unzip
COPY packages/cryptomator-cli-latest-linux-x64.zip /opt/cryptomator-cli.zip
RUN unzip -o /opt/cryptomator-cli.zip -d /opt/cryptomator/ && rm -f /opt/cryptomator-cli.zip

#------------------------------------------------------------------------------------------
# Stage 2: Final container
#------------------------------------------------------------------------------------------
FROM debian:sid-20250407-slim

RUN apt-get update && apt-get install --no-install-recommends -y stunnel curl netcat-openbsd && rm -rf /var/lib/apt/lists/*

# Set temporary UID and GID's to create the initial user and group
# Use the 'standard' linux starting UID and GID for interactive users
# These will be updated by the init.sh script to match the user given values when the container is started
ENV CRYPTOMATOR_TMP_UID='1000'
ENV CRYPTOMATOR_TMP_GID='1000'

# Expose the final stunnel port
EXPOSE 8443

# Create a local cryptomator user and group to keep files contained to local user
RUN groupadd -g "${CRYPTOMATOR_TMP_GID}" cryptomator && useradd --no-log-init -u "${CRYPTOMATOR_TMP_UID}" -g cryptomator cryptomator

# Copy over the stunnel config and self signed cert
COPY --chown=cryptomator:cryptomator --chmod=0440 config/stunnel.conf /etc/stunnel/stunnel.conf
COPY --from=builder --chown=cryptomator:cryptomator --chmod=0440 /root/stunnel.pem /etc/stunnel/stunnel.pem
COPY --from=builder --chown=cryptomator:cryptomator /opt/cryptomator/ /opt/

# Copy over the init scripts last (to speed up dev rebuilds when these change)
COPY --chown=root:root --chmod=0555 scripts/init.sh /init.sh
COPY --chown=cryptomator:cryptomator --chmod=0555 scripts/entrypoint.sh /entrypoint.sh

# Set the entrypoint as the initial init.sh script, wil be run as root to allow drop privileges to provide UID and GID
ENTRYPOINT ["/init.sh"]
