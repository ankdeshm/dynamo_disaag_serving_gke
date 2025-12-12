## Phase 5: Model Deployment

This is the final phase of the deployment. Here, you will deploy the Llama 3.1 70B model using the Dynamo Disaggregated Architecture (split Prefill and Decode workers) and then validate that the system is fully operational.

### 1\. Model Deployment

We will apply the model deployment YAML, which defines the Disaggregated Worker Service (DWS) architecture for Llama 3.1 70B across your A3 Ultra node pool.

**Note:** Ensure your custom `llama31_70b_dynamo_a3u.yaml` file (which you should place in a directory like `benchmarking/` in your repository) is available.

```bash
# 1. Download the Dynamo model deployment YAML from the root of this repository
# This command downloads the raw file content to the current directory (./).
wget https://raw.githubusercontent.com/ankdeshm/dynamo_disaag_serving_gke/main/llama31_70b_dynamo_a3u.yaml -O llama31_70b_dynamo_a3u.yaml

# 2. Apply the Deployment YAML
# This command uses the file you just downloaded.
kubectl apply -f ./llama31_70b_dynamo_a3u.yaml
```

### 2\. Monitor Pod Lifecycle

Watch the pods spin up. The process involves several key stages, especially the initialization containers which handle large model downloads.

```bash
# Watch the pods and their status
kubectl get pods -n dynamo-cloud -w
```

Pods will typically transition through these critical states:

| State | Description |
| :--- | :--- |
| **Pending** | Waiting for A3 Ultra nodes to scale up (if not already running). |
| **Init:0/2** | Running **Init Containers** (NCCL Plugin and Model Download). |
| **PodInitializing** | Finalizing network setup and volume mounts. |
| **Running** | The main vLLM engine container is starting. |

#### 2.1 Verify Init Containers

The **Model Downloader** init container downloads the large Llama 3.1 70B model (\~140GB) to the worker's local SSD (`/ssd`). If the model already exists from a previous deployment, this step skips almost instantly. The **NCCL Installer** installs the Google GPUDirect plugin.

```bash
# 1. Get the name of one of your worker pods (Prefill or Decode)
export WORKER_POD=$(kubectl get pods -n dynamo-cloud -l nvidia.com/dynamo-component=VllmDecodeWorker -o jsonpath="{.items[0].metadata.name}")

# 2. Check Model Downloader Logs
kubectl logs -f $WORKER_POD -c model-downloader

# 3. Check NCCL Installer Logs (Should be fast)
kubectl logs -f $WORKER_POD -c nccl-plugin-installer
```

#### 2.2 Verify Main Container Initialization

Once the pod enters the `Running` state, the vLLM engine starts. It needs to compile CUDA kernels ("DeepGemm"), which can take a few minutes before the service is ready.

```bash
# Check Decode Worker Logs for success signal
export DECODE_POD=$(kubectl get pods -n dynamo-cloud -l nvidia.com/dynamo-component=VllmDecodeWorker -o jsonpath="{.items[0].metadata.name}")
kubectl logs -f -n dynamo-cloud $DECODE_POD
```

**Success Signal:** You should see confirmation that the engine has initialized:

> `INFO main.setup_vllm_engine: VllmWorker for meta-llama/Meta-Llama-3.1-70B-Instruct has been initialized`

#### 2.3 Verify Frontend Registration

The Frontend acts as the router for all requests. Check its logs to ensure it has successfully discovered and registered the Prefill and Decode workers.

```bash
export FRONTEND_POD=$(kubectl get pods -n dynamo-cloud -l nvidia.com/dynamo-component-type=frontend -o jsonpath="{.items[0].metadata.name}")
kubectl logs -f -n dynamo-cloud $FRONTEND_POD
```

**Correct Output:** Look for messages like `Got model info...` followed by `Successfully added model and prefiller activation.`

-----

### 3\. Troubleshooting: Empty Model List

If all pods are `Running` and the logs look clean, but you still cannot query the model, you might encounter the "Empty Model List" symptom.

**Symptom:**

```bash
curl http://localhost:8000/v1/models
# Output: {"data":[]}
```

**Cause:**
The Dynamo Operator can sometimes fail to write the routing table to its Etcd store after a redeployment, meaning the Frontend finds an empty route list.

#### The Fix: Force Re-Synchronization

Follow these steps to force the Operator to re-reconcile and register the workers.

```bash
# 1. Force a Label Update on the deployment (This triggers the Operator)
kubectl label dynamographdeployment llama3-disagg -n dynamo-cloud "force-sync=$(date +%s)" --overwrite

# 2. Confirm Reconciliation in the Operator logs
export CONTROLLER_POD=$(kubectl get pods -n dynamo-cloud -l app.kubernetes.io/name=dynamo-operator -o jsonpath="{.items[0].metadata.name}")
kubectl logs -f -n dynamo-cloud $CONTROLLER_POD

# Wait for this message:
# INFO Reconciliation done {"controller": "dynamographdeployment", ...}
```

**Verification:** Run the `curl` command again. It should now immediately return the model ID.

-----
