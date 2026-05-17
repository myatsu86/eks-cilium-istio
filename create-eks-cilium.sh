#!/bin/bash
set -euo pipefail

CLUSTER_NAME=my-eks-cluster
REGION=ap-southeast-1
AWS_PROFILE=aws-master-admin  # pc-sandbox-admin

# create EKS cluster with eksctl
echo "Creating EKS cluster with eksctl..."
eksctl create cluster -f cilium-eks-config.yaml --profile "$AWS_PROFILE"

# wait for cluster to be ACTIVE before proceeding
echo "Waiting for cluster to become ACTIVE ..."
aws eks wait cluster-active \
  --name "$CLUSTER_NAME" \
  --region "$REGION" \
  --profile "$AWS_PROFILE"

# write kubeconfig to a local file so it doesn't touch ~/.kube/config
KUBECONFIG_PATH="$(pwd)/kubeconfig"
aws eks update-kubeconfig \
  --region "$REGION" \
  --name "$CLUSTER_NAME" \
  --profile "$AWS_PROFILE" \
  --kubeconfig "$KUBECONFIG_PATH"
export KUBECONFIG="$KUBECONFIG_PATH"
echo "Using kubeconfig: $KUBECONFIG_PATH"

# get api server host for cilium helm install
API_SERVER_HOST="$(aws eks describe-cluster \
  --name "$CLUSTER_NAME" \
  --region "$REGION" \
  --profile "$AWS_PROFILE" \
  --query 'cluster.endpoint' \
  --output text | sed 's#^https://##')"

echo "API Server Host: $API_SERVER_HOST"

# install cilium with helm on EKS using $API_SERVER_HOST
echo "Installing Cilium..."
helm install cilium cilium/cilium --version 1.17.4 \
  --namespace kube-system \
  --set eni.enabled=true \
  --set ipam.mode=eni \
  --set egressMasqueradeInterfaces=eth+ \
  --set routingMode=native \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost="$API_SERVER_HOST" \
  --set k8sServicePort=443

# wait for cilium daemonset to be rolled out before adding nodes
echo "Waiting for Cilium daemonset to be ready..."
kubectl rollout status daemonset/cilium -n kube-system --timeout=300s

# install node group with eksctl
echo "Creating node group with eksctl..."
eksctl create nodegroup -f node-group.yaml --profile "$AWS_PROFILE"

# wait for all nodes to reach Ready state
echo "Waiting for nodes to be Ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=600s

# check the status of the nodes
echo "Checking node status..."
kubectl get nodes

# check if any AWS daemonsets are present in the cluster
echo "Checking daemon sets..."
kubectl get ds -A

# validate cilium health
echo "Validating Cilium health..."
kubectl -n kube-system exec ds/cilium -- cilium status

echo " =================================================================="
echo "Cilium installation and node group creation complete!"
