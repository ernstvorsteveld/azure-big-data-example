# Create the local certs directory if it doesn't exist
mkdir -p ./certs

# Generate Private CA
openssl genrsa -out certs/ca-key.pem 4096 > /dev/null 2>&1
openssl req -new -x509 -days 365 -key certs/ca-key.pem -sha256 -out certs/ca.pem -subj "/CN=ServerlessSparkCA" > /dev/null 2>&1

# Generate Server Credentials
openssl genrsa -out certs/server-key.pem 4096 > /dev/null 2>&1
openssl req -subj "/CN=spark.serverless.local" -sha256 -new -key certs/server-key.pem -out certs/server.csr > /dev/null 2>&1
openssl x509 -req -days 365 -sha256 -in certs/server.csr -CA certs/ca.pem -CAkey certs/ca-key.pem -CAcreateserial -out certs/server-cert.pem > /dev/null 2>&1

# Generate Client Credentials for your Laptop
openssl genrsa -out certs/client-key.pem 4096 > /dev/null 2>&1
openssl req -subj '/CN=localhost-client' -new -key certs/client-key.pem -out certs/client.csr > /dev/null 2>&1
openssl x509 -req -days 365 -sha256 -in certs/client.csr -CA certs/ca.pem -CAkey certs/ca-key.pem -CAcreateserial -out certs/client-cert.pem > /dev/null 2>&1

# Clean up temporary signing elements
rm -f certs/*.csr certs/*.srl
