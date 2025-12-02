## 📝 Phase 3: Cluster Deployment (Toolkit)

In this phase, you will use the **Google Cloud Cluster Toolkit** binary (`gcluster`) to deploy the GKE cluster configured for NVIDIA Dynamo. We will be using a custom blueprint (`gke-a3-ultragpu-dynamo.yaml`) that is pre-tuned for Disaggregated Serving on A3 Ultra nodes, including the necessary configurations for Flex-Start/DWS.


### 1\. Download and Build the Toolkit

Assuming you ahve already cloned the cluster toolkit repo during your [local environment setup](https://github.com/ankdeshm/dynamo_disaag_serving_gke/blob/main/01-local-environment-setup.md#9-set-up-google-cloud-cluster-toolkit):

```bash
# Navigate to the cluster toolkit directory
cd cluster-toolkit

# Build the toolkit executable (this compiles the 'gcluster' command)
make
```

### 2\. Add and Inspect the Custom Dynamo Blueprint
Because we are using a blueprint customized for the Disaggregated Worker Service (DWS) and Flex-Start features, you must place the custom YAML file in the correct directory.

```bash

# Download/copy the custom YAML into the examples directory
wget https://raw.githubusercontent.com/ankdeshm/dynamo_disaag_serving_gke/main/gke-a3-ultragpu-dynamo.yaml -O examples/gke-a3-ultragpu/gke-a3-ultragpu-dynamo.yaml

# Inspect the file content
# It is recommended to quickly inspect the file to ensure the configurations are defined.
cat examples/gke-a3-ultragpu/gke-a3-ultragpu-dynamo.yaml
```

### 3\. Deploy the A3 Ultra Flex-Start Blueprint

Now, run the deployment command. The Cluster Toolkit will use the custom YAML you just placed to provision the GKE cluster. We will pass all required environment-specific values as variables (`--vars`).

You will need to replace the placeholder variables with your specific configuration values.

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
