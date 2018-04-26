# apps-namespace
Kubernetes configuration and extras for an apps namespace

script to perform the following:
* create certs
* sign certs
* generate zip file for distribution
* describe user setup


## Where possible encourage users to generate their own keys and only supply CSRs

This can be done by the admin but really users keys should never leave their own environment.

### Prerequisites
* openssl (command line util)

Share the following  two commands with the user to have them generate a key.

`openssl genrsa -out "${USER}.key" 4096` generates a key

`openssl req -new -key "${USER}.key" -out "${USER}.csr" -subj "/CN=${USER}/O=developer"` generates a CSR for a user in the `developer` group


## Create, sign and zip up user creds
```
$ export K8S_USER=jim
$ export K8S_GROUPS=developer
$ export K8S_CLUSTER=dev.k8s.example.com
$ export USER_CSR=/tmp/jim.csr ## This is optional but encouraged, keys will be generated if no CSR is supplied
$ ./create-user-cert.sh
```
