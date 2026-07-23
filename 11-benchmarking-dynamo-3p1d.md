
# Dynamo Disaggregated Serving: Llama 3.1 70B FP8 (4-GPU Topology)

This repository contains the deployment configurations (`llama31_70b_dynamo_a4_spot_3p1d.yaml`) and benchmarking guidelines for running **NVIDIA Dynamo Disaggregated Serving** on a **4-GPU footprint**. 

We use a **3:1 Prefill-to-Decode ratio** (3 Prefill Workers, 1 Decode Worker) to evaluate how disaggregation performs on a single half-node across multiple concurrency levels.

---

## 🎯 Architectural Rationale & YAML Design

To transition from an 8-GPU architecture down to a 4-GPU topology, several key adjustments were made to the deployment configuration:

### 1. FP8 Precision Enables TP=1 for 70B Model
* **The Change:** Reduced `tensor-parallel-size` from `4` to `1` across all prefill and decode workers.
* **The Reason:** With FP8 quantization (`neuralmagic/Meta-Llama-3.1-70B-Instruct-FP8`), model weights consume ~70 GB of VRAM. This comfortably fits inside a single 180 GB NVIDIA B200 GPU with over 100 GB remaining for activations and KV caches. Operating at `TP=1` completely eliminates inter-GPU Tensor Parallel communication overhead.

### 2. 3:1 Asymmetric Worker Allocation
* **Decode Worker:** 1 Replica requesting **1 GPU** (`TP=1`).
* **Prefill Workers:** 3 Replicas requesting **1 GPU each** (`TP=1`).
* **The Reason:** Prefill is compute-bound while Decode is memory-bandwidth bound. Dedicating 3 GPUs strictly for prefilling guarantees that incoming 3,000-token prompts are processed in parallel without pausing ongoing token generation on the decode GPU.

### 3. Dynamic GPU Fencing (`CUDA_VISIBLE_DEVICES`)
* **The Change:** Updated the entrypoint script to isolate GPUs `0..3`.
* **The Reason:** Because `securityContext: privileged: true` is required by GKE/gIB network plugins, all pods see all host devices. The Decode worker statically binds to `CUDA_VISIBLE_DEVICES="0"`, while the 3 Prefill workers use `flock` file-locking on `/ssd/locks` to sequentially claim GPUs `1`, `2`, and `3`.

---

## 🚀 Deployment Steps

### 1. Apply the Deployment
Ensure the cluster is free of previous deployments and apply the 4-GPU YAML:

```bash
kubectl apply -f llama31_70b_dynamo_a4_spot_3p1d.yaml

```

Verify that 1 Frontend, 1 Decode worker, and 3 Prefill workers reach the `1/1 Running` state:

```bash
kubectl get pods -n dynamo-cloud -w

```

### 2. Port-Forward the Service (Terminal 1)

Expose the OpenAI-compatible HTTP endpoint locally on port `8000`:

```bash
kubectl port-forward -n dynamo-cloud svc/llama3-disagg-frontend 8000:8000

```

---

## 🧪 Benchmarking Setup with GenAI-Perf

To capture sustained performance and eliminate cold-start noise, benchmarking uses elevated request counts:

* `--warmup-request-count 30`: Warms CUDA graphs and PyTorch allocators.
* `--request-count 600`: Evaluates sustained load across 600 total requests.
* Fixed Sequence Lengths: 3,000 input tokens, 150 output tokens.

### Run Benchmark (Terminal 2)

```bash
export PATH="$HOME/.local/bin:$PATH"

genai-perf profile -m neuralmagic/Meta-Llama-3.1-70B-Instruct-FP8 \
  --tokenizer neuralmagic/Meta-Llama-3.1-70B-Instruct-FP8 \
  --endpoint-type chat \
  --endpoint v1/chat/completions \
  --url 127.0.0.1:8000 \
  --streaming \
  --concurrency 32 \
  --num-dataset-entries 650 \
  --warmup-request-count 30 \
  --request-count 600 \
  --synthetic-input-tokens-mean 3000 \
  --synthetic-input-tokens-stddev 0 \
  --output-tokens-mean 150 \
  --output-tokens-stddev 0 \
  --extra-inputs min_tokens:150 \
  --extra-inputs max_tokens:150 \
  --extra-inputs ignore_eos:true \
  --random-seed 0 \
  --artifact-dir concurrency_32_dynamo_3p1d \
  --profile-export-file profile_export_3p1d_c32.json \
  -- --max-threads 32

```

---

## 📊 Benchmark Results: Concurrency 16 vs Concurrency 32

Below is the comparative evaluation of the 4-GPU Dynamo cluster (**3 Prefill TP1 : 1 Decode TP1**) under 16 vs. 32 concurrent requests:

| Metric / Statistic | Concurrency 16 | Concurrency 32 | Delta / Observation |
| --- | --- | --- | --- |
| **Total Output Token Throughput** | **414.88 tok/s** | **499.24 tok/s** | 🚀 **+20.3% Aggregate Output** |
| **Request Throughput** | **2.77 req/s** | **3.33 req/s** | 🚀 **+20.2% Request Completion** |
| **Output Throughput Per User** | **35.40 tok/s/user** | **27.94 tok/s/user** | 📉 -21.1% (Batch Saturation) |
| **Mean Time To First Token (TTFT)** | **1,342.80 ms** | **3,411.82 ms** | ⏳ Queueing Delay (+2.07s) |
| **Mean Time To Second Token** | **229.42 ms** | **403.73 ms** | +174.31 ms |
| **Mean Inter-Token Latency (ITL)** | **29.21 ms** | **39.66 ms** | +10.45 ms |
| **Mean Request Latency** | **5,694.92 ms** | **9,321.85 ms** | +3,626.93 ms |

---

## 🔍 Key Insights & Technical Takeaways

### 1. Decode Hardware Scaling & Per-GPU Efficiency

* Scaling down from 8 GPUs (`4 Prefill TP1 : 1 Decode TP4`) to 4 GPUs (`3 Prefill TP1 : 1 Decode TP1`) reduces available decode memory bandwidth by 75%.
* However, **per-GPU generation efficiency increases**. A single B200 GPU running `TP=1` generates **~415–499 tok/s**, compared to **~296 tok/s per GPU** when operating in a `TP=4` cluster, due to zero communication overhead.

### 2. Concurrency Trade-Offs (16 vs 32)

* **Concurrency 16 (Optimal Per-User Latency):** Delivers ideal streaming speed (**35.40 tok/s/user**) with low TTFT (**~1.34s**). The single Decode GPU handles incoming KV transfers cleanly without request backlog.
* **Concurrency 32 (Max Aggregate Throughput):** Pushes the single Decode GPU to max batch capacity, raising total output throughput to **~499 tok/s**. However, because 32 requests compete for 1 Decode worker, queueing delays increase TTFT to **~3.41s**.
