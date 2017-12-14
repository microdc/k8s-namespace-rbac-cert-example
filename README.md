# apps-namespace
Kubernetes configuration and extras for an apps namespace


# Create, sign and upload user cert to s3 and configure cluster with new user
```
$ ./create-user-cert.sh
```
script to perform the following:
* create certs
* sign certs
* upload certs to s3 for distribution
* apply config yaml to allow use of specified user
* setup user locally



