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


## Test
```bash
# Set the IP address variable
export BIG_DATA_CLUSTER_IP=your-ip-address

# Test HTTP request to the nginx server
curl --cacert certs/ca.pem \
     --cert certs/client-cert.pem \
     --key certs/client-key.pem \
     https://${BIG_DATA_CLUSTER_IP}
```
