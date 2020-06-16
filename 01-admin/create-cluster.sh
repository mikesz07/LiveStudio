#!/bin/sh

# Clean up screen and terminate any remaining proxy processes
kill -9 $(ps -ux | grep 'kubectl proxy' | awk '{print $2}' | head -1)

# delete any cluster by the same name that we are trying to create
kind delete cluster --name $1

# create the new cluster with our 3-node template
kind create cluster --name $1 --config ./kind-3nodes.yaml

# print out the basic info for the cluster connectivity
kubectl cluster-info --context kind-$1

# Install the Dashboard application into our cluster
kubectl apply -f ./create-dashboard.yaml
kubectl apply -f ./create-admin-account.yaml
kubectl apply -f ./bind-admin-role.yaml

# Get the Token for the ServiceAccount
BEARER_TOKEN=$(kubectl -n kubernetes-dashboard describe secret $(kubectl -n kubernetes-dashboard get secret | grep admin-user | 
awk '{print $1}') | grep 'token:' | awk '{print $2}')

# Add the token to kubernetes config
kubectl config set-credentials cluster-admin --token=$BEARER_TOKEN

# Install a better metrics server
# Create a service account for tiller
sleep 20s
kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount=kube-system:tiller
helm init --service-account tiller
kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'
sleep 20s
helm install --name metrics-server --namespace kube-system stable/metrics-server --set rbac.create=true --set args={"--kubelet-insecure-tls=true, --kubelet-preferred-address-types=InternalIP"}
sleep 20s
kubectl apply -f ./kube-state-metrics/examples/standard

# Copy the token and copy it into the Dashboard login and press "Sign in"
kubectl proxy & > /tmp/kube-dashboard.log

echo "\n\nCopy the token and paste into the dashboard login page\n"
echo $BEARER_TOKEN
echo "\n"
echo "\n\nEnter the URL on your browser: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/\n\n"
