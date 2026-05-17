#!/bin/bash

set -euo pipefail

# This script assumes you have already created an EKS cluster and have your kubeconfig file ready. 
# It will install Istio on the cluster using istioctl.
aws eks --region ap-southeast-1 update-kubeconfig --name my-eks-cluster --profile pc-sandbox-admin --kubeconfig ./kubeconfig
export KUBECONFIG=$(pwd)/kubeconfig

# check if kubectl can connect to the cluster
echo "Checking cluster connectivity..."
kubectl cluster-info
kubectl get nodes

sleep 3

ISTIO_VERSION=1.29.0

# add istio plugin if not already added
asdf plugin add istio https://github.com/virtualstaticvoid/asdf-istio.git 2>/dev/null || true

# install and set istio version
asdf install istio "$ISTIO_VERSION"
asdf set istio "$ISTIO_VERSION"

# install istio on the cluster
echo "Installing Istio $ISTIO_VERSION..."
istioctl install --set profile=demo -y

# wait for istio-system pods to be ready
echo "Waiting for Istio pods to be ready..."
kubectl wait --for=condition=Ready pods --all -n istio-system --timeout=300s


echo "Istio installation complete! Here are the Istio pods:"
kubectl get pods -n istio-system