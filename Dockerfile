#------------------------------------------------------------------------------------------
# Stage 1: Build container
#------------------------------------------------------------------------------------------
FROM redhat/ubi9 as builder

# Install build dependencies
RUN yum install -y gcc make openssl-devel

# Download and build stunnel
RUN curl -LO https://www.stunnel.org/downloads/stunnel-5.70.tar.gz \
    && tar -xzf stunnel-5.70.tar.gz \
    && cd stunnel-5.70 \
    && ./configure \
    && make \
    && make install

# Create a new selfsigned certificate
COPY config/pem.conf /root/pem.conf
RUN openssl req -newkey rsa:2048 -nodes -keyout /root/stunnel.pem -x509 -days 3650 -out /root/stunnel.pem -config /root/pem.conf

#------------------------------------------------------------------------------------------
# Stage 2: Final container
#------------------------------------------------------------------------------------------
FROM eclipse-temurin:17.0.7_7-jre-ubi9-minimal

# Copy stunnel binary from the builder stage
COPY --from=builder /usr/local/bin/stunnel /usr/local/bin/stunnel

ENV CRYPTOMATOR_SRC_PATH='/path/to/cryptomator/vault/files'
ENV CRYPTOMATOR_VAULT_PASS='password'
ENV CRYPTOMATOR_UID='1000'
ENV CRYPTOMATOR_GID='1000'

EXPOSE 8443

# Createa  local cryptomator user and group to keep files contained to local user
RUN groupadd -g "${CRYPTOMATOR_GID}" cryptomator && useradd --no-log-init -u "${CRYPTOMATOR_UID}" -g cryptomator cryptomator

COPY --chown=cryptomator:cryptomator --chmod=0444 packages/cryptomator-cli-latest.jar /usr/local/bin/cryptomator-cli.jar
COPY --chown=cryptomator:cryptomator --chmod=0444 config/stunnel.conf /usr/local/etc/stunnel/stunnel.conf
COPY --from=builder --chown=cryptomator:cryptomator --chmod=0444 /root/stunnel.pem /usr/local/etc/stunnel/stunnel.pem

# Copy over the main entrypoint script last (to speed up rebuilds)
COPY --chown=cryptomator:cryptomator --chmod=0555 entrypoint.sh /entrypoint.sh

USER cryptomator

ENTRYPOINT ["/entrypoint.sh"]
