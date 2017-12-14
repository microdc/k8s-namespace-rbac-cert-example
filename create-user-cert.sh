#!/bin/bash

CERT_DIR="~/.kube/certs"
KEY="${CERT_DIR}/apps.key"
CSR="${CERT_DIR}/apps.csr"
CRT="${CERT_DIR}/apps.crt"
USER="apps"
NAMESPACE="apps"
BUCKET="${BUCKET}"
CLUSTER="${CLUSTER}"

mkdir -p "${CERT_DIR}"

openssl genrsa -out "${KEY}" 2048

openssl req -new -key "${KEY}" -out "${CSR}" -subj "/CN=${USER}/O=microdc"

kubectl create -f <(cat role-user.yaml|envsubst)

kubectl create -f <(cat rolebinding-user.yaml|envsubst)

cat <<EOF | kubectl create -f -
apiVersion: certificates.k8s.io/v1beta1
kind: CertificateSigningRequest
metadata:
  name: ${USER}.${NAMESPACE}
spec:
  groups:
  - system:authenticated
  request: $(cat ${CSR} | base64 | tr -d '\n')
  usages:
  - digital signature
  - key encipherment
  - server auth
EOF

kubectl certificate approve "${USER}.${NAMESPACE}"

kubectl get csr "${USER}.${NAMESPACE}" -o jsonpath='{.status.certificate}' |  base64 --decode > "${CRT}"

aws s3 cp "${CRT}" "s3://${BUCKET}/"
aws s3 cp "${KEY}" "s3://${BUCKET}/"
aws s3 cp "${CSR}" "s3://${BUCKET}/"

#Add certs as user
kubectl config set-credentials ${USER} --client-certificate="${CRT}"  --client-key="${KEY}"
#set user as current context
kubectl config set-context employee-context --cluster="${CLUSTER}" --namespace="${NAMESPACE}" --user="${USER}"
