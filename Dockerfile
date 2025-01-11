#------------------------------------------------------------------------------------------
# Stage 1: Build container
#------------------------------------------------------------------------------------------
FROM alpine:3.21.2 as builder

# Install ssl dependencies
RUN apk --no-cache add openssl

# Create a new selfsigned certificate
COPY config/pem.conf /root/pem.conf
RUN openssl req -newkey rsa:2048 -nodes -keyout /root/stunnel.pem -x509 -days 3650 -out /root/stunnel.pem -config /root/pem.conf

#------------------------------------------------------------------------------------------
# Stage 2: Final container
#------------------------------------------------------------------------------------------
FROM alpine:3.21.2

RUN apk --no-cache add stunnel openjdk17-jre-headless setpriv shadow

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

# Copy over the latest cryptomator-cli.jar file
COPY --chown=cryptomator:cryptomator --chmod=0444 packages/cryptomator-cli-latest.jar /usr/local/bin/cryptomator-cli.jar

# Copy over the init scripts last (to speed up dev rebuilds when these change)
COPY --chown=root:root --chmod=0555 scripts/init.sh /init.sh
COPY --chown=cryptomator:cryptomator --chmod=0555 scripts/entrypoint.sh /entrypoint.sh

# Set the entrypoint as the initial init.sh script, wil be run as root to allow drop privileges to provide UID and GID
ENTRYPOINT ["/init.sh"]
