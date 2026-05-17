# EKS + Cilium + Istio — Retail Banking POV

This sets up an EKS cluster with Cilium as the CNI, Istio as the service mesh, and a retail banking demo app exposed via Istio Gateway.

## What's in here

```
EKS/
├── cilium-eks-config.yaml   # EKS cluster config (control plane only, no nodes)
├── node-group.yaml          # Node group: 4x t3.small
├── create-eks-cilium.sh     # Step 1: create cluster + install Cilium + add nodes
└── retail-banking-app/
    ├── istio-install.sh     # Step 2: install Istio
    ├── install-app.sh       # Step 3: deploy app + gateway + attach ACM cert
    ├── customer-profile.yaml
    ├── account.yaml
    ├── statement.yaml
    ├── istio-gateway.yaml
    └── istio-virtualservice.yaml
```

## Prerequisites

- `eksctl`, `kubectl`, `helm`, `aws` CLI installed
- `asdf` installed (for Istio version management)
- AWS profile configured (`aws-master-admin`)
- ACM certificate issued for `retail-banking.myatsumon.info`

---

## Step 1 — Create EKS cluster with Cilium

Cilium needs to be installed before nodes join the cluster, so this script creates the control plane first, installs Cilium, then adds the node group.

```bash
cd EKS
bash create-eks-cilium.sh
```

This takes about 15-20 minutes. It will:
- Create the EKS cluster (control plane only)
- Write kubeconfig to `./kubeconfig` without touching `~/.kube/config`
- Install Cilium 1.17.4 via Helm
- Add 4x t3.small nodes
- Validate Cilium health

After it's done, export the kubeconfig in your terminal:
```bash
export KUBECONFIG=$(pwd)/kubeconfig
```

---

## Step 2 — Install Istio

```bash
cd retail-banking-app
bash istio-install.sh
```

This installs Istio 1.29.0 using `istioctl` (managed via asdf) with the `demo` profile.

---

## Step 3 — Deploy the app

```bash
bash install-app.sh
```

This will:
- Deploy the three services into the `retail-banking-team` namespace with Istio sidecar injection enabled
- Apply the Istio Gateway and VirtualService
- Attach the ACM certificate to the Classic Load Balancer for HTTPS

## App architecture

All traffic enters through `customer-profile-svc`. The other two are internal only.

```
Internet → CLB → Istio Gateway → customer-profile-svc (8081)
                                        ↓
                                  account-svc (8082)
                                        ↓
                                 statement-svc (8083)
```

---

## Step 4 — DNS

Get the CLB hostname:
```bash
kubectl get svc istio-ingressgateway -n istio-system
```

In Route 53, create an **A record (Alias)** under `myatsumon.info`:
- Record name: `retail-banking`
- Alias target: the CLB hostname from above

Verify DNS:
```bash
dig retail-banking.myatsumon.info @8.8.8.8
```

> **Heads up on DNS cache:** After creating the record, your local DNS (usually your router) might still cache the old `NXDOMAIN` response for a while. If `curl` says "Could not resolve host" but the `dig @8.8.8.8` above shows the correct IPs, that's what's happening. Fix it by flushing your Mac's DNS cache:
> ```bash
> sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
> ```
> If it still doesn't resolve, your router is the one caching it. Either wait a minute or two for it to expire, or temporarily change your DNS server to `8.8.8.8` in System Settings → Network.

---

## Verify everything works

```bash
# test HTTP
curl http://retail-banking.myatsumon.info/

# test HTTPS
curl https://retail-banking.myatsumon.info/

# check pods (should all show 2/2 — app + Envoy sidecar)
kubectl get pods -n retail-banking-team

# check Cilium health
kubectl -n kube-system exec ds/cilium -- cilium status

# check Istio config
istioctl analyze -n retail-banking-team
```

---

## Cleanup

```bash
eksctl delete cluster my-eks-cluster --region ap-southeast-1 --profile aws-master-admin
```

Delete the cluster when you're done to avoid charges. The Classic Load Balancer will also be deleted automatically.
