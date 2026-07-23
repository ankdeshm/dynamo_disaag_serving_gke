# Dynamo Disaggregated Serving: Llama 3.1 70B FP8 on NVIDIA B200s

This repository contains the Kubernetes deployment configurations (`llama3-disagg.yaml`) and benchmarking guidelines for serving **Llama 3.1 70B Instruct** using NVIDIA's **Dynamo** disaggregated serving framework on an 8x NVIDIA B200 node.

By disaggregating the **Prefill** (compute-bound) and **Decode** (memory-bandwidth-bound) phases into a **4:1 worker ratio**, this setup achieves significant throughput gains over monolithic serving for large input contexts.

---

## 🎯 Architectural Rationale & Design Choices

Disaggregated LLM serving separates context processing (Prefill) from token generation (Decode). To optimize performance on a single 8-GPU B200 node, the `llama3-disagg.yaml` was designed with four crucial configuration choices:

### 1. FP8 Model Precision (`neuralmagic/Meta-Llama-3.1-70B-Instruct-FP8`)
* **The Problem:** A full BF16 70B model requires ~140 GB of VRAM for weights alone. On a 180 GB GPU, this leaves only ~30 GB for activations and KV caches during large prefills, leading to CUDA Out-Of-Memory (OOM) errors.
* **The Solution:** Quantizing weights to FP8 cuts model memory in half (~70 GB), leaving over 100 GB of free VRAM per GPU for massive context processing and KV caches.

### 2. Asymmetric Worker Ratios & Tensor Parallelism
* **Prefill Workers (`TP=1`, 4 Replicas):** Prefill is compute-heavy. Running 4 independent workers at `TP=1` eliminates inter-GPU communication overhead, allowing 4 prompts to be processed concurrently across 4 separate GPUs.
* **Decode Worker (`TP=4`, 1 Replica):** Token generation is memory-bandwidth bound. Spreading the decode phase across 4 GPUs (`TP=4`) multiplies memory bandwidth, accelerating token streaming speed.

### 3. Dynamic GPU Fencing (`CUDA_VISIBLE_DEVICES`)
* When using `securityContext: privileged: true` (required by NCCL/gIB networking plugins), Kubernetes container GPU isolation is bypassed—all pods see all 8 GPUs on the host.
* To prevent GPU collisions on `cuda:0`, a shell script using file locking (`flock`) on a shared SSD mount is injected into container arguments:
  * **Decode Worker:** Directly claims GPUs `0, 1, 2, 3`.
  * **Prefill Workers:** Sequentially claim GPUs `4`, `5`, `6`, and `7`.

### 4. Explicit NIXL KV Transfer Configuration
* The flag `--kv-transfer-config '{"kv_connector":"NixlConnector","kv_role":"kv_both"}'` and `--disaggregation-mode` are explicitly passed to instruct vLLM to transmit generated KV caches from Prefill workers directly to the Decode worker via NIXL.


## 🚀 Deployment Steps

### 1. Apply the Kubernetes Deployment
Deploy the Dynamo Graph to your namespace:
```bash
kubectl apply -f llama31_70b_dynamo_a4-spot-prefill-4xtp1-decode-1xtp4.yaml

```

Verify that 1 Frontend pod, 1 Decode worker, and 4 Prefill workers reach the `1/1 Running` state:

```bash
kubectl get pods -n dynamo-cloud -w

```

### 2. Port-Forward the Frontend Service

Expose the OpenAI-compatible HTTP endpoint locally:

```bash
kubectl port-forward -n dynamo-cloud svc/llama3-disagg-frontend 8000:8000

```

---

## 🧪 Benchmarking with GenAI-Perf

We evaluate the system using NVIDIA's `genai-perf` tool to measure latency and throughput under high concurrency.

### 1. Environment Setup

Install `genai-perf` and export the user binary directory:

```bash
pip install genai-perf --break-system-packages
export PATH="$HOME/.local/bin:$PATH"

```

### 2. Run the Benchmark Command

Execute the load test with 32 concurrent requests, 3,000 input tokens, and 150 output tokens:

```bash
genai-perf profile -m neuralmagic/Meta-Llama-3.1-70B-Instruct-FP8 \
  --tokenizer neuralmagic/Meta-Llama-3.1-70B-Instruct-FP8 \
  --endpoint-type chat \
  --endpoint v1/chat/completions \
  --url 127.0.0.1:8000 \
  --streaming \
  --concurrency 32 \
  --num-dataset-entries 330 \
  --warmup-request-count 10 \
  --request-count 320 \
  --synthetic-input-tokens-mean 3000 \
  --synthetic-input-tokens-stddev 0 \
  --output-tokens-mean 150 \
  --output-tokens-stddev 0 \
  --extra-inputs min_tokens:150 \
  --extra-inputs max_tokens:150 \
  --extra-inputs ignore_eos:true \
  --random-seed 0 \
  --artifact-dir concurrency_32 \
  --profile-export-file profile_export_concurrency_32.json \
  -- --max-threads 32

```

### 📌 Argument Definitions

* `--concurrency 32`: Keeps 32 clients constantly sending requests in parallel.
* `--synthetic-input-tokens-mean 3000`: Generates synthetic prompts fixed at 3,000 tokens to stress the Prefill cluster.
* `--output-tokens-mean 150` & `ignore_eos:true`: Forces the model to generate exactly 150 tokens per prompt to eliminate sequence-length variance.
* `--warmup-request-count 10`: Executes 10 initial unmeasured requests to warm up PyTorch CUDA graphs and memory pools.

---

## 📊 Benchmark Results

Below are the empirical performance numbers captured on an 8x NVIDIA B200 setup running **4 Prefill (TP1) : 1 Decode (TP4)** disaggregation:

### NVIDIA GenAI-Perf Metric Summary

| Statistic / Metric | Avg | Min | Max | p75 | p90 | p99 |
| --- | --- | --- | --- | --- | --- | --- |
| **Time To First Token (ms)** | 1,454.36 | 381.13 | 2,635.16 | 2,022.29 | 2,394.76 | 2,632.52 |
| **Time To Second Token (ms)** | 107.34 | 1.30 | 221.38 | 204.80 | 208.88 | 220.67 |
| **Request Latency (ms)** | 3,998.87 | 2,445.61 | 4,259.88 | 4,103.26 | 4,183.14 | 4,256.84 |
| **Inter-Token Latency (ms)** | 17.08 | 8.41 | 24.69 | 20.90 | 23.10 | 24.38 |
| **Output Throughput Per User (tok/s/user)** | 63.14 | 40.51 | 118.91 | 74.98 | 90.40 | 115.16 |
| **Total Output Token Throughput** | **1,184.91 tok/s** | N/A | N/A | N/A | N/A | N/A |
| **Request Throughput** | **7.90 req/s** | N/A | N/A | N/A | N/A | N/A |

```

```
