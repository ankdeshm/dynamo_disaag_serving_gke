
## 📝 Phase 2: Google Cloud Infrastructure

This phase configures your Google Cloud project, creates necessary storage buckets, and sets up Artifact Registry to host your Docker images.

You will need to replace the placeholder variables (e.g., `PROJECT_ID`, `BUCKET_NAME`, etc.) with your actual values.

### 1\. Configure Project and Storage

Set your active project and create the Cloud Storage buckets. These buckets are essential for Terraform backend state management and for storing the LLM model weights and other assets.

```bash
# 1. Set your Project ID
# Replace PROJECT_ID with your actual Google Cloud Project ID
gcloud config set project PROJECT_ID

# --- VARIABLES TO REPLACE ---
# BUCKET_NAME: A globally unique name for your storage bucket (e.g., dynamo-llama3-assets-12345)
# BUCKET_LOCATION: The region for your bucket (e.g., europe-west4, us-central1)
# PROJECT_NUMBER: Your Google Cloud Project Number (found on the dashboard)
# ----------------------------

# 2. Create the bucket
gcloud storage buckets create gs://BUCKET_NAME \
  --location=BUCKET_LOCATION \
  --no-public-access-prevention --uniform-bucket-level-access

# 3. Configure Workload Identity Access Control
# This grants the default Kubernetes service account (used by the cluster)
# necessary permissions to read and write objects in the bucket.
gcloud storage buckets add-iam-policy-binding gs://BUCKET_NAME \
  --role=roles/storage.objectAdmin \
  --member=principal://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/PROJECT_ID.svc.id.goog/subject/ns/default/sa/default \
  --condition=None

gcloud storage buckets add-iam-policy-binding gs://BUCKET_NAME \
  --role=roles/storage.legacyBucketReader \
  --member=principal://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/PROJECT_ID.svc.id.goog/subject/ns/default/sa/default \
  --condition=None
```

### 2\. Set up Artifact Registry

Set up a Docker repository in **Artifact Registry** for storing any custom Docker images.

```bash
# 1. Create the Artifact Registry Docker repository
# Replace REPOSITORY with your desired repo name (e.g., dynamo-repo)
# Replace BUCKET_LOCATION with the region (e.g., europe-west4)
gcloud artifacts repositories create REPOSITORY \
    --repository-format=docker \
    --location=BUCKET_LOCATION \
    --description="Dynamo Disaggregated Serving Docker Images"

# 2. Authenticate application-default credentials
# This ensures that gcloud commands for the cluster toolkit can authenticate.
gcloud auth application-default login
```

-----
