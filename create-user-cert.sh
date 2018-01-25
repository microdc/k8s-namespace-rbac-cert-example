#!/bin/bash

set -eo pipefail

: "${K8S_USER:?must be set}"
: "${K8S_GROUPS:?must be set}"
: "${K8S_CLUSTER:?must be set}"

current_dir="${PWD}"
working_dir=$(mktemp -d)
tmp_dir=$(mktemp -d)

cd "${working_dir}"
echo ${working_dir}

if [[ -z ${USER_CSR} ]] ; then
	export USER_CSR="${tmp_dir}/${K8S_USER}.csr"
	echo "Generating the user cert. Consider the user supplying a CSR to the USER_CSR env rather as this is like generating a users password :(" >&2
	echo '   They can generate one by running `openssl genrsa -out "${USER}.key" 4098` followed by `openssl req -new -key "${USER}.key" -out "${USER}.csr" -subj "/CN=${USER}/O=developer"`'
	sleep 5
	openssl genrsa -out "${K8S_USER}.key" 4098
	O='O='$(echo "${K8S_GROUPS}" | sed 's/,/\/O=/g')
	openssl req -new -key "${K8S_USER}.key" -out "${USER_CSR}" -subj "/CN=${K8S_USER}/${O}"
fi

# Check subject matches user and groups

REQ_SUBJECT="$(openssl req -noout -in ${USER_CSR} -subject)"
for group in ${K8S_GROUPS//,/ } ; do
	REQ_SUBJECT=${REQ_SUBJECT/\/O=${group}}
done
echo "${REQ_SUBJECT}" | grep "^subject=\/CN=${K8S_USER}$" || { echo "Subject doesn't match expected subject"; exit 1 ; }

cat <<EOF | kubectl --server "https://api.${K8S_CLUSTER}" create -f -
apiVersion: certificates.k8s.io/v1beta1
kind: CertificateSigningRequest
metadata:
  name: ${K8S_USER}
spec:
  request: $(cat ${USER_CSR} | base64 | tr -d '\n')
EOF

kubectl --server "https://api.${K8S_CLUSTER}" certificate approve "${K8S_USER}"

USER_CERT="${K8S_USER}.${K8S_CLUSTER}.crt"
CLUSTER_CERT="${K8S_CLUSTER}.crt"

kubectl --server "https://api.${K8S_CLUSTER}" get csr "${K8S_USER}" -o jsonpath='{.status.certificate}' |  base64 --decode > "${USER_CERT}"

openssl s_client -showcerts -connect api.dev.k8s.moneynp.xinja.com.au:443 </dev/null 2>/dev/null | openssl x509 > "${CLUSTER_CERT}"

zip ${current_dir}/${K8S_USER}.${K8S_CLUSTER}.zip *

echo
echo "========================================================="
cat <<EOF | cat -
Send ${K8S_USER}.${K8S_CLUSTER}.zip to ${K8S_USER}, tell them to unzip it and run the following to set up their kubectl:
\`\`\`
kubectl config set-credentials "${K8S_USER}.${K8S_CLUSTER}" --client-certificate="${USER_CERT}" --client-key="${K8S_USER}.key" --embed-certs=true
kubectl config set-cluster "${K8S_CLUSTER}" --server=https://api.${K8S_CLUSTER} --certificate-authority="${CLUSTER_CERT}" --embed-certs=true
kubectl config set-context "${K8S_USER}.${K8S_CLUSTER}" --cluster="${K8S_CLUSTER}" --namespace=apps --user="${K8S_USER}.${K8S_CLUSTER}"
kubectl --context="${K8S_USER}.${K8S_CLUSTER}" get pods -n apps
\`\`\`
EOF
