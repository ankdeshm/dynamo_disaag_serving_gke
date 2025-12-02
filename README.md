# NVIDIA Dynamo Disaggregated Serving on Google Cloud

**Authors: Ankita Deshmukh & Zhenzhen Tan**

This repository provides a step-by-step guide and all necessary configuration files to deploy **NVIDIA Dynamo** for disaggregated LLM serving on **Google Kubernetes Engine (GKE)**, leveraging the power of **A3 Ultra (H200) nodes**.

The guide focuses on deploying the **Llama 3.1 70B Instruct** model using a split architecture (Prefill and Decode Workers) to improve tail latency and stream smoothness for high-concurrency, mixed-workload scenarios.

## 🗺️ Guide Structure and Deployment Phases

The deployment is broken into five logical, sequential phases. **Please ensure you complete the steps in order.**

| Phase | Description | Estimated Time | Guide Link |
| :--- | :--- | :--- | :--- |
| **Phase 1: Local Setup** | Install required tools: Terraform, Packer, Go, Git, and `make` and set up cluster toolkit | 5-10 min | [01-local-environment-setup.md](01-local-environment-setup.md) |
| **Phase 2: Cloud Infrastructure** | Configure your Google Cloud Project, create Storage Buckets, and set up Artifact Registry. | 5 min | [02-google-cloud-infra.md](02-google-cloud-infra.md) |
| **Phase 3: Cluster Deployment** | Deploy the A3 Ultra GKE Cluster using the custom cluster-toolkit blueprint. | 15-20 min | [03-cluster-deployment.md](03-cluster-deployment.md) |
| **Phase 4: Dynamo Platform** | Export environment variables, set up Kubernetes Secrets (NGC, HF), and install the Dynamo Operator and Platform via Helm. | 5 min | [04-dynamo-secrets-and-platform.md](04-dynamo-secrets-and-platform.md) |
| **Phase 5: Model Deployment** | Apply the Dynamo model YAML and monitor pod status. | 15-20 min  | [05-model-deployment.md](05-model-deployment.md) |
| **Phase 6: Validation & Benchmark** | Run end-to-end inference tests and performance benchmarks. | 10-15 min  | [06-benchmarking-validation.md](06-benchmarking-validation.md) |


---

## 🔒 Prerequisites

Before starting Phase 1, ensure you have:

* **A Google Cloud Project** with billing enabled and the necessary quotas for A3 Ultra nodes.
* **Access to the Llama 3.1 70B Model** on Hugging Face (a **gated model**).
* **A valid NGC API Key** for pulling NVIDIA's core images.
* **A valid Hugging Face Token (`HF_TOKEN`)** for model downloads.

---

## ⚡ Next Step:
### Phase 1

Begin the deployment by setting up your local environment:

➡️ **[Continue to Phase 1: Local Environment Setup](01-local-environment-setup.md)**

### Phase 2

Once your local environment is ready, move on to setting up your Google Cloud infrastructure.

➡️ **[Continue to Phase 2: Google Cloud Infrastructure]((02-google-cloud-infra.md))**



## Phase 3

With your cloud infrastructure configured, you are now ready to deploy the specialized GKE cluster.

➡️ **[Continue to Phase 3: Cluster Deployment (Toolkit)](03-cluster-deployment.md)**


## Phase 4

Once the deployment completes successfully, you can move on to configure your environment and install the Dynamo platform components.

➡️ **[Continue to Phase 4: Dynamo Platform Configuration](04-dynamo-secrets-and-platform.md)**



## Phase 5

With the Dynamo platform installed, the next phase focuses on deploying the Llama 3.1 70B model itself.

➡️ **[Continue to Phase 5: Model Deployment](05-model-deployment.md)**


## Phase 6

Once the model is deployed, you can run a a few queries to test the deployment as well as run a benchmarking script to compare the performance.

➡️ **[Continue to Phase 6: Validation & Benchmark](06-benchmarking-validation.md)**



## 📈 Performance Analysis

If you are interested in the detailed results and analysis comparing the tail latency benefits of [Dynamo Disaggregated Serving](llama31_70b_dynamo_a3u.yaml) versus a standard [vLLM Monolithic setup](llama31_70b_standard_vllm.yaml) on the A3 Ultra node, please see the dedicated results page:

➡️ **[View Performance Comparison and Analysis](07-performance-comparison-analysis.md)**




