#! /bin/bash
export SERVICEACCOUNT_NAME="myserviceaccount"
export NAMESPACE="test"

echo "####################################################################################################"
echo "create namespace $NAMESPACE. We want to create a Serviceaccount in this namespace"
kubectl create ns $NAMESPACE
kubectl config set-context --current --namespace=$NAMESPACE

echo "####################################################################################################"
echo "Apply ServiceAccount $SERVICEACCOUNT_NAME, Role, RoleBinding and a ServiceAccount secret"
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: $SERVICEACCOUNT_NAME
  namespace: $NAMESPACE
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-creator
  namespace: $NAMESPACE
rules:
  - apiGroups: [""]
    resources: ["*"]
    verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: pod-creator
  namespace: $NAMESPACE
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: pod-creator
subjects:
  - kind: ServiceAccount
    name: $SERVICEACCOUNT_NAME
    namespace: $NAMESPACE
---
apiVersion: v1
kind: Secret
metadata:
  name: $SERVICEACCOUNT_NAME-token
  annotations:
    kubernetes.io/service-account.name: $SERVICEACCOUNT_NAME
type: kubernetes.io/service-account-token
EOF

echo "####################################################################################################"
echo "Show the secret/$SERVICEACCOUNT_NAME-token so we can see that Kubernetes has added a valid cert and token"
kubectl get secret/$SERVICEACCOUNT_NAME-token  -o yaml

echo "####################################################################################################"
echo "export variables that we will need for creating the kubeconfig file"
export USER_TOKEN_VALUE=$(kubectl get secret/$SERVICEACCOUNT_NAME-token -o=go-template='{{.data.token}}' | base64 --decode)
export CURRENT_CONTEXT=$(kubectl config current-context)
export CURRENT_CLUSTER=$(kubectl config view --raw -o=go-template='{{range .contexts}}{{if eq .name "'''${CURRENT_CONTEXT}'''"}}{{ index .context "cluster" }}{{end}}{{end}}')
export CLUSTER_CA=$(kubectl config view --raw -o=go-template='{{range .clusters}}{{if eq .name "'''${CURRENT_CLUSTER}'''"}}"{{with index .cluster "certificate-authority-data" }}{{.}}{{end}}"{{ end }}{{ end }}')
export CLUSTER_SERVER=$(kubectl config view --raw -o=go-template='{{range .clusters}}{{if eq .name "'''${CURRENT_CLUSTER}'''"}}{{ .cluster.server }}{{end}}{{ end }}')
echo "USER_TOKEN_VALUE: $USER_TOKEN_VALUE"
echo "CURRENT_CONTEXT: $CURRENT_CONTEXT"
echo "CURRENT_CLUSTER: $CURRENT_CLUSTER"
echo "CLUSTER_CA: $CLUSTER_CA"
echo "CLUSTER_SERVER: $CLUSTER_SERVER"

#export -p USER_TOKEN_VALUE CURRENT_CONTEXT CURRENT_CLUSTER CLUSTER_CA CLUSTER_SERVER

echo "####################################################################################################"
echo "Create local kubeconfig file for Serviceaccount $SERVICEACCOUNT_NAME"
cat << EOF > kubeconfig-${SERVICEACCOUNT_NAME}
apiVersion: v1
kind: Config
current-context: ${CURRENT_CONTEXT}
contexts:
- name: ${CURRENT_CONTEXT}
  context:
    cluster: ${CURRENT_CONTEXT}
    user: $SERVICEACCOUNT_NAME
    namespace: $NAMESPACE
clusters:
- name: ${CURRENT_CONTEXT}
  cluster:
    certificate-authority-data: ${CLUSTER_CA}
    server: ${CLUSTER_SERVER}
users:
- name: $SERVICEACCOUNT_NAME
  user:
    token: ${USER_TOKEN_VALUE}
EOF
cat kubeconfig-${SERVICEACCOUNT_NAME}

echo "####################################################################################################"
echo "Apply a test pod using the Serviceaccount  $SERVICEACCOUNT_NAME"
POD_NAME=nginxpod
kubectl --kubeconfig $(pwd)/kubeconfig-${SERVICEACCOUNT_NAME} apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: $POD_NAME
spec:
  containers:
  - image: nginx:latest
    name: $POD_NAME
  serviceAccountName: $SERVICEACCOUNT_NAME
EOF

echo "####################################################################################################"
echo "delete pod"
kubectl --kubeconfig $(pwd)/kubeconfig-${SERVICEACCOUNT_NAME}  delete pod $POD_NAME
echo "delete Namespace"
kubectl --kubeconfig $(pwd)/kubeconfig-${SERVICEACCOUNT_NAME}  delete ns $NAMESPACE



