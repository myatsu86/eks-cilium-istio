#!/bin/bash
set -euo pipefail

# This step is required if you expose kubeconfig file to this folder. 
# If you have already set KUBECONFIG env var to point to your kubeconfig file, you can skip this step.
aws eks --region ap-southeast-1 update-kubeconfig --name my-eks-cluster --profile pc-sandbox-admin --kubeconfig ./kubeconfig
export KUBECONFIG=$(pwd)/kubeconfig

# check if kubectl can connect to the cluster
echo "Checking cluster connectivity..."
kubectl cluster-info
kubectl get nodes

sleep 3

# create namespace for retail banking app
echo "Creating namespace for retail banking app..."
kubectl create namespace retail-banking-team || echo "Namespace retail-banking-team already exists, skipping creation."

# label namespace for istio sidecar injection
echo "Labeling namespace for Istio sidecar injection..."
kubectl label namespace retail-banking-team istio-injection=enabled

# verify namespace and label
echo "Verifying namespace and label..."
kubectl get namespace retail-banking-team --show-labels

# install retail banking app with kubectl
echo "Installing retail banking app..."
kubectl apply -f customer-profile.yaml -n retail-banking-team
kubectl apply -f account.yaml -n retail-banking-team
kubectl apply -f statement.yaml -n retail-banking-team

# wait for all pods to be ready
echo "Waiting for retail banking app pods to be ready..."
kubectl wait --for=condition=Ready pods --all -n retail-banking-team --timeout=300s

echo "Retail banking app installation completed successfully!"
kubectl get all -n retail-banking-team

echo "Install istio gateway and virtual service for retail banking app..."
kubectl apply -f istio-gateway.yaml -n retail-banking-team
kubectl apply -f istio-virtualservice.yaml -n retail-banking-team

kubectl wait --for=condition=Ready pods --all -n retail-banking-team --timeout=300s

echo "Attaching ACM certificate to CLB..."
kubectl annotate svc istio-ingressgateway -n istio-system \
  service.beta.kubernetes.io/aws-load-balancer-ssl-cert="arn:aws:acm:ap-southeast-1:$(aws sts get-caller-identity --query Account --output text --profile pc-sandbox-admin):certificate/71d33bf7-5fe0-4740-ab18-33bff8256c4e" \
  service.beta.kubernetes.io/aws-load-balancer-ssl-ports="443" \
  --overwrite

echo "Retail banking app is exposed via Istio Gateway."
echo "  HTTP:  http://retail-banking.myatsumon.info"
echo "  HTTPS: https://retail-banking.myatsumon.info"






