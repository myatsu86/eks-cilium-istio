#!/bin/bash
# eksctl create cluster -f cilium-eks-config.yaml
# create EKS cluster with eksctl
    eksctl create cluster \
    --name my-eks-cluster \
    --region ap-southeast-1 \
    --profile aws-master-admin \
    --nodegroup-name ng-1 \
    --node-type t3.small \
    --nodes 1 \
    --nodes-min 1 \
    --nodes-max 1 \
    --managed

# check cluster
    eksctl get cluster my-eks-cluster --region ap-southeast-1 --profile aws-master-admin 


# delete EKS cluster
# eksctl delete cluster my-eks-cluster --region ap-southeast-1 --profile aws-master-admin

# Copy kubeconfig file to EKS folder
    aws eks --region ap-southeast-1 update-kubeconfig --name my-eks-cluster --profile aws-master-admin --kubeconfig ./kubeconfig
    export KUBECONFIG=/Users/myatsu/Documents/CAP/pov-kubernetes/EKS/kubeconfig