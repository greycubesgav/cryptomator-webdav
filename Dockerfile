FROM openjdk:17-slim

ENV CRYPTOMATOR_VAULT_NAME demoVault
ENV CRYPTOMATOR_SRC_PATH /path/to/cryptomator/vault/files
ENV CRYPTOMATOR_VAULT_PATH /vault
ENV CRYPTOMATOR_VAULT_PASS password
ENV CRYPTOMATOR_PORT "12345"

EXPOSE 18181

RUN groupadd -r cryptomator && useradd --no-log-init -r -g cryptomator cryptomator

COPY --chown=cryptomator:cryptomator --chmod=0440 packages/cryptomator-cli-latest.jar /usr/local/bin/cryptomator-cli.jar
COPY --chown=cryptomator:cryptomator --chmod=0550 entrypoint.sh /entrypoint.sh

USER cryptomator

ENTRYPOINT ["/entrypoint.sh"]
