# Cryptomator-webdav Docker File
This repo contains a set of docker files to create a docker image to run the [Cryptomator cli](https://github.com/cryptomator/cli) within Docker.
The Cryptomator-cli application shares a local Cryptmator vault over an TLS protected webdav share.

:warning: The webdav server contained within the Cryptomator-cli application provides **no username or password** access controls. Take your own appropriate security precautions.

:warning: As of June 2023, Cryptomator states the cli application is still in an early stage and not ready for production use. We recommend using it only for testing and evaluation purposes.

## Docker Image Rebuild Intructions


```shell
# Clone the repo
git clone git@github.com:greycubesgav/cryptomator-webdav.git
cd cryptomator-webdav
# Copy the `sample.env` file to `.env`
cp sample.env .env
# Build the docker image using docker-compose
docker-compose build cryptomator-webdav
# Image will be built as greycubesgav/cryptomator-webdav
```

## Usage Instructions

Set your cryptomator vault password, either by setting the CRYPTOMATOR_VAULT_PASS variable in `.env`, or writing it to a file named `vault.pass` in the root of the repo.

```shell
# Copy the `sample.env` file to `.env`
cp sample.env .env
# Update `.env` file with your local settings
# Either set CRYPTOMATOR_VAULT_PASS in .env or write password to a file named 'vault.pass'
# Run the image using docker-compose
docker-compose up cryptomator-webdav
# The vault will be accessible on the docker host machine on the port specified in the .env file
```
By default the cryptomator vault will be available over webdav at `webdavs://127.0.0.1:18081/vault`, with no username or password on the webdav share.

If you wish to be able to access the vault over the the docker host's external IPs, update CRYPTOMATOR_HOST in `.env` to either 0.0.0.0 (all ips), or a specific docker host IP.

### Environment variables explanation

```bash
# CRYPTOMATOR_VAULT_SRC_PATH: The location of the local, encrypted Cryptomator files
CRYPTOMATOR_VAULT_SRC_PATH='/location/of/local/cryptomator/vaule/files'

# CRYPTOMATOR_VAULT_PASS: The cryptomator password to unencrypt the vault
CRYPTOMATOR_VAULT_PASS='password'
# Or CRYPTOMATOR_VAULT_PASSFILE: The path to a local password file
CRYPTOMATOR_VAULT_PASSFILE='./vault.pass'
# Note: CRYPTOMATOR_VAULT_PASSFILE takes precidence

# CRYPTOMATOR_HOST: The ip the container should attach to, 127.0.0.1 by default
# Set to 0.0.0.0 if you are happy having the webdav share accessible to the docker host's external IPs
CRYPTOMATOR_HOST='127.0.0.1'

# CRYPTOMATOR_PORT: The port the webdav share will be shared on outside the container, used in docker-compose when running the container
CRYPTOMATOR_PORT=18081

# CRYPTOMATOR_UID: The user ID cryptomator should run as
CRYPTOMATOR_UID=1000

# CRYPTOMATOR_GID: The group ID cryptomator should run as
CRYPTOMATOR_GID=1000

# CRYPTOMATOR_UMASK: The umask to create new file as, the default only allows access by owner
CRYPTOMATOR_UMASK=0077
```

## Upgrade version of internal cryptomator-cli instructions
To upgrade to a newer version of cryptomator-cli within the docker image:

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

### To run the docker container using an environment variable password and connect to a local shell
* Run `docker-compose run --service-ports cryptomator-webdav-dev`

### To run the docker container using an password file and connect to a local shell
* Run `docker-compose run --service-ports cryptomator-webdav-passfile-dev`
