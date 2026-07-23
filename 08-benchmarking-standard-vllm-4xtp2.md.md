# Standard vLLM Baseline Serving: Llama 3.1 70B FP8 (2x TP4) on NVIDIA B200s

This repository contains the deployment guidelines and benchmarking procedures for running a **Standard monolithic vLLM baseline** serving **Llama 3.1 70B Instruct** across an 8x NVIDIA B200 GPU node using a **2x TP=4 configuration**.

This setup serves as an exact **apples-to-apples baseline** to compare monolithic serving against disaggregated serving architectures (such as NVIDIA Dynamo).

---

## 💻 Hardware & Model Specifications

* **Model:** `neuralmagic/Meta-Llama-3.1-70B-Instruct-FP8`
* **Accelerator Hardware:** 8x NVIDIA B200 GPUs (1 Single Node)
* **Serving Topology:** 2 Replicas × Tensor Parallelism 4 (`2x TP=4`)
* **Precision:** FP8 Weights (`CompressedTensorsW8A8Fp8`) with FP8 KV Cache

---

## 🎯 YAML Design & Apples-to-Apples Parity

To ensure a fair baseline comparison against disaggregated serving, the Kubernetes deployment configuration (`llama3-standard.yaml`) incorporates key structural design choices matching the disaggregated setup:

### 1. Model & Precision Parity
* Uses the exact same FP8 quantized model checkpoint (`neuralmagic/Meta-Llama-3.1-70B-Instruct-FP8`) and parameters (`--kv-cache-dtype fp8`, `--block-size 128`, `--max-model-len 32768`).
* FP8 precision cuts weight memory footprint to ~70 GB, ensuring plenty of headroom for massive context processing and KV cache allocation on 180 GB B200 GPUs.

### 2. Full Hardware Utilization (`2x TP=4`)
* The deployment runs **2 independent replicas**, each configured with `--tensor-parallel-size 4`.
* Together, both replicas occupy all **8 GPUs** on the host node, utilizing the exact same total compute capacity as the 8-GPU disaggregated graph (which uses 4 GPUs for prefill and 4 GPUs for decode).

### 3. Dynamic GPU Fencing (`CUDA_VISIBLE_DEVICES`)
* Because `securityContext: privileged: true` is required by standard GKE/gIB network plugins, container-level GPU isolation is bypassed, making all 8 GPUs visible to every container.
* To prevent the two replicas from colliding on `cuda:0`, a dynamic file-locking script (`flock`) on a shared `/ssd/locks` volume is embedded in the container entrypoint args:
  * **Replica 1:** Dynamically claims `CUDA_VISIBLE_DEVICES="0,1,2,3"`
  * **Replica 2:** Dynamically claims `CUDA_VISIBLE_DEVICES="4,5,6,7"`

---

## 🚀 Deployment Steps

### 1. Apply the Deployment
Deploy the standard vLLM manifest to your cluster:

```bash
kubectl apply -f llama31_70b_standard_vllm_a4_spot_2xtp4.yaml

```

Verify that both standard replicas reach the `1/1 Running` state:

```bash
kubectl get pods -n dynamo-cloud -w

```

### 2. Port-Forward the Service (Terminal 1)

Once application startup completes (`Application startup complete.` in pod logs), expose the OpenAI-compatible endpoint locally on port `8000`:

```bash
kubectl port-forward -n dynamo-cloud svc/llama3-standard-service 8000:8000

```

> *Leave this command active in Terminal 1 during benchmarking.*

---

## 🧪 Benchmarking with GenAI-Perf

We use NVIDIA's `genai-perf` tool to measure latency and throughput metrics under high concurrency.

### 1. Environment Setup (Terminal 2)

Export the user binary path to ensure `genai-perf` and `perf_analyzer` are accessible:

```bash
export PATH="$HOME/.local/bin:$PATH"

```

### 2. Run the Benchmark Command

Execute the load test with **identical configuration parameters** used for the disaggregated benchmark (32 concurrent clients, 3,000 input tokens, 150 output tokens, 320 requests):

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
  --artifact-dir concurrency_32_standard \
  --profile-export-file profile_export_standard_32.json \
  -- --max-threads 32

```

### 📌 Benchmark Argument Definitions

* `--concurrency 32`: Simulates 32 simultaneous clients sending parallel streaming requests.
* `--synthetic-input-tokens-mean 3000`: Generates synthetic prompts fixed at 3,000 tokens to stress context prefilling.
* `--output-tokens-mean 150` & `ignore_eos:true`: Guarantees exactly 150 output tokens generated per request.
* `--warmup-request-count 10`: Fires 10 unmeasured requests to warm up PyTorch allocations and CUDA graphs.

---

## 📊 Benchmark Results

Below are the empirical metrics collected from the standard monolithic vLLM (`2x TP=4`) run on 8x NVIDIA B200 GPUs:

### NVIDIA GenAI-Perf Metric Summary

| Statistic / Metric | Avg | Min | Max | p75 | p90 | p99 |
| --- | --- | --- | --- | --- | --- | --- |
| **Time To First Token (ms)** | 1,320.91 | 214.87 | 2,495.82 | 1,859.61 | 2,074.81 | 2,380.23 |
| **Time To Second Token (ms)** | 176.44 | 3.80 | 231.66 | 208.03 | 210.86 | 216.83 |
| **Request Latency (ms)** | 3,700.45 | 3,071.30 | 4,307.31 | 3,770.19 | 3,787.29 | 4,077.67 |
| **Inter-Token Latency (ms)** | 15.97 | 8.43 | 23.91 | 19.76 | 22.37 | 23.78 |
| **Output Token Throughput Per User (tok/s/user)** | 67.24 | 41.82 | 118.64 | 82.31 | 88.30 | 110.44 |
| **Total Output Token Throughput** | **1,295.28 tok/s** | N/A | N/A | N/A | N/A | N/A |
| **Request Throughput** | **8.64 req/s** | N/A | N/A | N/A | N/A | N/A |
| **Completed Request Count** | 320.00 | N/A | N/A | N/A | N/A | N/A |

```
