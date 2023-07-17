FROM eclipse-temurin:17.0.7_7-jre-ubi9-minimal

ENV CRYPTOMATOR_VAULT_NAME='demoVault'
ENV CRYPTOMATOR_SRC_PATH='/path/to/cryptomator/vault/files'
ENV CRYPTOMATOR_VAULT_PASS='password'
ENV CRYPTOMATOR_PORT='18081'
ENV CRYPTOMATOR_UID='1000'
ENV CRYPTOMATOR_GID='1000'

EXPOSE ${CRYPTOMATOR_PORT}

RUN groupadd -g "${CRYPTOMATOR_GID}" cryptomator && useradd --no-log-init -u "${CRYPTOMATOR_UID}" -g cryptomator cryptomator

COPY --chown=cryptomator:cryptomator --chmod=0440 packages/cryptomator-cli-latest.jar /usr/local/bin/cryptomator-cli.jar
COPY --chown=cryptomator:cryptomator --chmod=0550 entrypoint.sh /entrypoint.sh

USER cryptomator

ENTRYPOINT ["/entrypoint.sh"]
