# Cryptomator-webdav Docker File
This repo contains a set of docker files to create a docker image to run the [Cryptomator cli](https://github.com/cryptomator/cli) within Docker.
The Cryptomator-cli application shares a local Cryptmator vault over an (unencrypted) webdav share.

:warning: The webdav server contained within the Cryptomator-cli application provides an **unencrypted** webdav share, with **no username or password** required for access. Take your own appropriate security precautions.

:warning: As of June 2023, Cryptomator states the cli application is still in an early stage and not ready for production use. We recommend using it only for testing and evaluation purposes.

## Rebuild Intructions

* Clone the repo
* Build with docker-compose

```bash
docker-compose build cryptomator-webdav
```

## Usage Instructions

* Copy the `dot_env_sample` file to `.env`
* Update `.env` file with your local settings
* Run `docker-compose up cryptomator-webdav`
```bash
docker-compose up cryptomator-webdav
```
* The vault will be accessible on the docker host machine on the port and folder specified in the .env file
* By default this would be available at http://dockerhost:18081/demoVault, with no username or password on the webdav share

### Environment variables explanation

```bash
# CRYPTOMATOR_VAULT_SRC_PATH: The location of the local, encrypted Cryptomator files
CRYPTOMATOR_VAULT_SRC_PATH='/location/of/local/cryptomator/vaule/files'

# CRYPTOMATOR_VAULT_NAME: The path that will be added to the webdav share e.g. demovault would be shared at http://localhost:18081/demovault
CRYPTOMATOR_VAULT_NAME=demoVault

# CRYPTOMATOR_VAULT_PASS: The cryptomator password to unencrypt the vault
CRYPTOMATOR_VAULT_PASS='password'

# CRYPTOMATOR_PORT: The port the webdav share will be shared on
CRYPTOMATOR_PORT=18081

# CRYPTOMATOR_VAULT_CONTAINER_PATH: Doesn't need changed!
# The path where the local encrypted files will be mounted by docker-compose within the container.
CRYPTOMATOR_VAULT_CONTAINER_PATH=/vault
```

## Upgrade cryptomator-cli instructions
To upgrade to a newer version of cryptomator-cli:

* Download the new .jar from the [cryptomator-cli releases page](https://github.com/cryptomator/cli/releases)
* Update the `packages/cryptomator-cli-latest.jar` symlink to point the new jar version
```bash
ln -sf cryptomator-cli-0.5.1.jar packages/cryptomator-cli-latest.jar
```
* Rebuild the docker image
```bash
docker-compose build cryptomator-webdav
```

## Debugging

### Cryptomator Environment Variables
To check what environment variables are getting set in the container:
* Run `docker-compose run cryptomator-webdav-env`

### To run the docker container and connect to a local shell
* Run `docker-compose run --service-ports cryptomator-webdav-dev`