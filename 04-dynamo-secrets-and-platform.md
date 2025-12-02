## 📝 Phase 4: Dynamo Platform Configuration

This phase prepares the GKE environment by setting necessary variables, connecting to the cluster, creating the required namespace, and deploying the core Dynamo platform components (Operator and Control Plane).

### 1\. Configure Environment Variables

Export the variables required for the Dynamo deployment. **You must replace all placeholder values** (e.g., `<YOUR_NGC_API_KEY>`) with your actual information.

```bash
# 1. Project and Cluster Details (Use the same values from Phase 3)
export PROJECT_ID=PROJECT_ID_FROM_PHASE_2
export CLUSTER_NAME=CLUSTER_NAME_FROM_PHASE_3
export COMPUTE_REGION=COMPUTE_REGION_FROM_PHASE_3
export COMPUTE_ZONE=COMPUTE_ZONE_FROM_PHASE_3

# 2. Dynamo Specifics
export NAMESPACE=dynamo-cloud
export RELEASE_VERSION=0.6.1

# 3. Secure Credentials (REPLACE WITH YOUR TOKENS)
export NGC_API_KEY=<YOUR_NGC_API_KEY>
export HF_TOKEN=<YOUR_HF_TOKEN>
```

### 2\. Connect to the GKE Cluster

Fetch the credentials for your newly created GKE cluster and configure `kubectl` to use them.

```bash
gcloud container clusters get-credentials ${CLUSTER_NAME} --location ${COMPUTE_REGION}
```

### 3\. Create Secrets & Namespace

Create the Kubernetes namespace and the secrets required for pulling images from NVIDIA's registry (NGC) and downloading gated models from Hugging Face.

```bash
# 1. Create Dynamo Namespace
kubectl create namespace ${NAMESPACE}

# Set the context to use the new namespace for subsequent commands
kubectl config set-context --current --namespace=${NAMESPACE}

# 2. Create Docker Registry Secret (for NVIDIA NGC images)
# This uses the NGC_API_KEY defined above.
kubectl create secret docker-registry nvcr-secret \
  --namespace=${NAMESPACE} \
  --docker-server=nvcr.io \
  --docker-username='$oauthtoken' \
  --docker-password=${NGC_API_KEY}

# 3. Create Hugging Face Token Secret (Crucial for Gated Models like Llama 3.1)
# We use a hybrid command to ensure idempotency and correct key naming.
kubectl create secret generic hf-secret \
  --from-literal=hf_api_token=${HF_TOKEN} \
  -n ${NAMESPACE} \
  --dry-run=client -o yaml | kubectl apply -f -
```

### 4\. Dynamo Platform Installation

Install the Dynamo Custom Resource Definitions (CRDs) and the Dynamo Operator/Control Plane components using Helm.

```bash
# 1. Add NVIDIA Helm Repo
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia \
  --username='$oauthtoken' --password=${NGC_API_KEY}
helm repo update

# 2. Install Custom Resource Definitions (CRDs)
# These define the 'DynamoGraphDeployment' resource type.
helm install dynamo-crds https://helm.ngc.nvidia.com/nvidia/ai-dynamo/charts/dynamo-crds-${RELEASE_VERSION}.tgz \
  --namespace default \
  --wait \
  --atomic

# 3. Install Dynamo Platform (Operator and Control Plane)
# We set custom images/tags for etcd to prevent known issues and allow insecure images.
helm install dynamo-platform https://helm.ngc.nvidia.com/nvidia/ai-dynamo/charts/dynamo-platform-${RELEASE_VERSION}.tgz \
  --namespace ${NAMESPACE} \
  --set etcd.image.repository="bitnamilegacy/etcd" \
  --set etcd.image.tag="3.6.4-debian-12-r4" \
  --set global.security.allowInsecureImages=true

# 4. Install Missing Volcano CRDs (Critical Fix for Operator Crashes)
# This prevents the Dynamo Operator from crashing due to missing resource definitions.
kubectl apply -f https://raw.githubusercontent.com/volcano-sh/volcano/master/installer/helm/chart/volcano/crds/scheduling.volcano.sh_podgroups.yaml
```

-----
