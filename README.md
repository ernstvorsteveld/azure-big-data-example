# Big data infrastructure on Azure

## Prepare
```bash
# Install Azure client
brew update && brew install azure-cli

# Make deploy.sh executable
chmod +x deploy.sh

# Make certs.sh executable
chmod +x certs.sh

# Set your docker credentials as environment variables
export DOCKER_USER="your docker username"
export DOCKER_PAT="your docker password"
```


## Install on Azure
```bash
# Create certificates
./certs.sh

# Login into Azure
az login

# Run deploy.sh script, using source, to allow values for your environment variables
source deploy.sh
```

## Certificate management

```bash
# Combine cert and key into a .p12 for macOS Keychain
openssl pkcs12 -export \
  -in certs/client-cert.pem \
  -inkey certs/client-key.pem \
  -out certs/client.p12 \
  -passout pass:changeme
```


## Test
```bash
# Set the IP address variable
export BIG_DATA_CLUSTER_IP=your-ip-address

# Test HTTP request to the nginx server
curl --cacert certs/ca.pem \
     --cert certs/client-cert.pem \
     --key certs/client-key.pem \
     "https://spark.serverless.local:8443"
```


## Other commands

```bash
# Check container states
az container show \
  --resource-group spark-serverless-rg \
  --name spark-serverless-group \
  --query "containers[].{name:name, state:instanceView.currentState.state, restartCount:instanceView.restartCount}" \
  -o table

```


## Docker compose

For running apache spark/iceberg on localhost using docker, use docker compose file.

```bash
docker compose up
```
