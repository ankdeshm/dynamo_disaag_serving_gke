## 📝 Phase 3: Cluster Deployment (Toolkit)

In this phase, you will use the **Google Cloud Cluster Toolkit** binary (`gcluster`) to deploy the GKE cluster configured for NVIDIA Dynamo. This blueprint is specifically designed to provision the necessary A3 Ultra GPU nodes and networking for high-performance AI workloads.

### 1\. Download and Build the Toolkit

Assuming you ahve already cloned the cluster toolkit repo during your [local environment setup]():

```bash
# Navigate to the cluster toolkit directory
cd cluster-toolkit

# Build the toolkit executable (this compiles the 'gcluster' command)
make
```

### 2\. Deploy the A3 Ultra Flex-Start Blueprint

The deployment command uses a pre-configured blueprint (`gke-a3-ultragpu-dynamo.yaml`) that defines the necessary A3 Ultra node pools (8x H200-141GB GPUs) and cluster settings required for Dynamo.

You will need to replace the placeholder variables (e.g., `CLUSTER_NAME`, `PROJECT_ID`, etc.) with the values you decided on in Phase 2.

```bash
# --- VARIABLES TO REPLACE ---
# BUCKET_NAME: The bucket you created in Phase 2 (for Terraform state)
# CLUSTER_NAME: A name for your GKE cluster (e.g., dynamo-a3u-cluster)
# PROJECT_ID: Your Google Cloud Project ID
# COMPUTE_REGION: The region where your A3 Ultra node quota is available (e.g., europe-west4)
# COMPUTE_ZONE: The specific zone within that region (e.g., europe-west4-a)
# ----------------------------

./gcluster deploy \
  examples/gke-a3-ultragpu/gke-a3-ultragpu-dynamo.yaml \
  --backend-config "bucket=BUCKET_NAME" \
  --vars "deployment_name=CLUSTER_NAME" \
  --vars "project_id=PROJECT_ID" \
  --vars "region=COMPUTE_REGION" \
  --vars "zone=COMPUTE_ZONE" \
  --vars "system_node_pool_disk_size_gb=200" \
  --vars "a3ultra_node_pool_disk_size_gb=200" \
  --vars "accelerator_type=nvidia-h200-141gb"
```

> **Note:** Deployment typically takes **15–20 minutes** as the underlying Google Cloud resources, including the specialized A3 Ultra GKE cluster, are provisioned. The command will output status updates as it progresses.

-----
