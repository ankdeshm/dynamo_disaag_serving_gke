# Multi-Node NVIDIA Dynamo Disaggregated Benchmark Report (16 x NVIDIA B200 GPUs)

## 🎯 1. Executive Summary & Customer Expectations

This document presents the architecture, configuration, and empirical benchmark results for deploying **NVIDIA Dynamo Disaggregated Serving** on a multi-node cluster consisting of **16 NVIDIA B200 GPUs** (2 Nodes × 8 GPUs).

The benchmark workload directly models a heavy enterprise prefill profile (Workato POC profile) designed to evaluate disaggregated serving under extreme context lengths and extended decoding passes.

### Customer Workload Profile & Technical Requirements

* **Target Model:** `neuralmagic/Meta-Llama-3.1-70B-Instruct-FP8` (FP8 weights & FP8 KV cache).
* **Cluster Footprint:** 16 NVIDIA B200 GPUs across 2 GKE nodes connected via high-speed interconnects.
* **Heavy Prefill Requirement:** **80% of the LLM context window** dedicated to prompt prefilling ($32,768 \times 0.80 \approx \mathbf{26,000\text{ Input Tokens / ISL}}$).
* **Extended Decoding Requirement:** **500 to 1,000 output tokens** per request ($\approx \mathbf{984\text{ Output Tokens / OSL}}$).
* **User Streaming SLA:** Target output streaming speed of **30 to 60 tokens/sec/user** with minimal Inter-Token Latency (ITL) jitter.

---

## 🏗️ 2. Architectural Design & YAML Configuration

To handle 26,000-token prompt prefills without incurring $O(N^2)$ single-GPU attention computation bottlenecks, the 16 GPUs were split into dedicated, specialized prefill and decode worker pools across the 2 nodes.

```text
========================================================================================
16-GPU MULTI-NODE DYNAMO DISAGGREGATED TOPOLOGY (2x 8-GPU B200 Nodes)

NODE 1 (8 GPUs)                                NODE 2 (8 GPUs)
├── Prefill Worker 1: 4 GPUs (TP=4)            ├── Prefill Worker 3: 4 GPUs (TP=4)
└── Prefill Worker 2: 4 GPUs (TP=4)            └── Decode Worker 1:  4 GPUs (TP=4)
                                                       ▲
                                                       │ NIXL / GPUDirect KV Transfer
                                                       └───────────────────────────────
========================================================================================

```

### Resource Allocation

* **12 GPUs for Prefill (3 Replicas × `TP=4`):** Processing 26,000-token input sequences requires massive compute bandwidth. Running `TP=4` on prefill workers distributes the attention matrix calculation across 4 B200 GPUs per worker.
* **4 GPUs for Decode (1 Replica × `TP=4`):** Memory bandwidth is pooled across 4 GPUs to continuously stream output tokens for active requests without interruption.

### Key Configuration Parameters & Flags

* **`UCX_TLS=all`:** Forces high-speed NIXL/RDMA interconnect transport for transferring the massive 26,000-token KV caches between prefill nodes and decode nodes.
* **`NCCL_CROSS_NIC=1` & `NCCL_ALGO=Ring,Tree`:** Optimizes multi-node GPUDirect communication paths across physical node boundaries.
* **`--max-num-batched-tokens 32768`:** Expanded batch token capacity allowing workers to process large 26k prompt chunks in a single pass.
* **Dynamic Node-Local GPU Locking (`flock`):** A node-local file lock (`/ssd/locks/gpu_assign_tp4.lock`) dynamically partitions each 8-GPU node into two clean `TP=4` GPU slices (`0,1,2,3` and `4,5,6,7`), preventing CUDA memory collisions when two pods share a physical host.

> **Note:** The full deployment manifest is available in the repository as `llama3-disagg-16gpu.yaml`.

---

## 🚀 3. Deployment & Benchmarking Workflow

### Step 1: Deploy the 16-GPU Dynamo Manifest

```bash
kubectl apply -f llama3-disagg-16gpu.yaml

```

### Step 2: Verify Pod Status

```bash
kubectl get pods -n dynamo-cloud -w

```

*Ensure that 1 Frontend pod, 1 Decode worker pod (`TP=4`), and 3 Prefill worker pods (`3x TP4`) reach the `Running` state.*

### Step 3: Establish Port Forwarding

```bash
kubectl port-forward -n dynamo-cloud svc/llama3-disagg-frontend 8000:8000

```

### Step 4: Execute Benchmarks (`genai-perf`)

#### Concurrency 16 Benchmark (26k ISL / ~1k OSL)

```bash
export PATH="$HOME/.local/bin:$PATH"

genai-perf profile -m neuralmagic/Meta-Llama-3.1-70B-Instruct-FP8 \
  --tokenizer neuralmagic/Meta-Llama-3.1-70B-Instruct-FP8 \
  --endpoint-type chat \
  --endpoint v1/chat/completions \
  --url 127.0.0.1:8000 \
  --streaming \
  --concurrency 16 \
  --num-dataset-entries 650 \
  --warmup-request-count 16 \
  --request-count 300 \
  --synthetic-input-tokens-mean 26000 \
  --synthetic-input-tokens-stddev 0 \
  --output-tokens-mean 750 \
  --output-tokens-stddev 0 \
  --extra-inputs min_tokens:500 \
  --extra-inputs max_tokens:1000 \
  --extra-inputs ignore_eos:true \
  --random-seed 0 \
  --artifact-dir concurrency_16_dynamo_workato_26k \
  --profile-export-file profile_export_dynamo_workato_c16_26k.json \
  -- --max-threads 16

```

#### Concurrency 32 Benchmark (26k ISL / ~1k OSL)

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
  --warmup-request-count 32 \
  --request-count 300 \
  --synthetic-input-tokens-mean 26000 \
  --synthetic-input-tokens-stddev 0 \
  --output-tokens-mean 750 \
  --output-tokens-stddev 0 \
  --extra-inputs min_tokens:500 \
  --extra-inputs max_tokens:1000 \
  --extra-inputs ignore_eos:true \
  --random-seed 0 \
  --artifact-dir concurrency_32_dynamo_workato_26k \
  --profile-export-file profile_export_dynamo_workato_c32_26k.json \
  -- --max-threads 32

```

---

## 📊 4. Empirical Benchmark Results

Below are the empirical metrics collected from running 300 requests against the 16-GPU Dynamo deployment under Concurrency 16 and Concurrency 32.

| Metric / Statistic | Concurrency 16 | Concurrency 32 | Delta / Trend |
| --- | --- | --- | --- |
| **Input Sequence Length (ISL)** | 26,000.00 tokens | 26,000.00 tokens | Fixed 80% Context Window |
| **Output Sequence Length (OSL)** | 983.90 tokens | 983.10 tokens | Fixed ~1,000-token Decode Pass |
| **Mean Time To First Token (TTFT)** | **7,513.46 ms** (7.51s) | **13,144.97 ms** (13.14s) | $+1.75\times$ Queue wait time |
| **Mean Time To Second Token** | **758.48 ms** | **830.53 ms** | $+72.05\text{ ms}$ |
| **Mean Request Latency** | **22,611.73 ms** (22.61s) | **36,457.78 ms** (36.46s) | Total request execution time |
| **Inter-Token Latency (ITL / TPOT)** | **15.38 ms** | **23.79 ms** | $+8.41\text{ ms}$ (Maintains $<24\text{ms}$ stream) |
| **Output Speed Per User** | **68.73 tok/s/user** | **46.71 tok/s/user** | 🎯 Sits in optimal 30–60 SLA zone |
| **Total Output Token Throughput** | **688.28 tok/s** | **833.54 tok/s** | ⚡ **$+21.1\%$ Hardware Throughput** |
| **Request Throughput** | **0.70 req/s** | **0.85 req/s** | $+21.4\%$ Completion rate |

---

## 🎯 5. Customer Expectation vs. Measured Performance Alignment

This table explicitly evaluates whether the multi-node Dynamo disaggregated deployment met or exceeded every target metric specified in the customer POC workload profile.

| Workload Dimension | Customer POC Requirement | Measured Benchmark Result | SLA Alignment Status |
| --- | --- | --- | --- |
| **Prefill Context Length** | 80% of Context Window ($\approx 26,000$ tokens) | **26,000.00 tokens** | **MET** (Full 26k ingestion tested) |
| **Decode Pass Length** | 500 to 1,000 output tokens | **983.10 – 983.90 tokens** | **MET** (Full multi-paragraph decode) |
| **User Streaming SLA** | Target 30 to 60 tokens/sec/user | **46.71 tok/s/user** *(C=32)*<br>

<br>**68.73 tok/s/user** *(C=16)* | **EXCEEDED** (C=32 lands directly in the sweet spot; C=16 delivers ultra-fast streaming) |
| **Streaming Fluidness** | Low jitter / no screen stutters | **15.38 ms** *(C=16)*<br>

<br>**23.79 ms** *(C=32)* | **EXCEEDED** (ITL under 24ms guarantees instant visual streaming) |
| **Cluster Scalability** | Multi-node GKE endpoint stability | **300/300 successful requests** | **MET** (Zero connection drops or OOMs during cross-node KV cache transfers) |

---

## 💡 6. Technical Insights & Architectural Analysis

### 1. `TP=4` Prefill Solved the Long-Context Bottleneck

In earlier single-node benchmarks using single-GPU (`TP=1`) prefill workers, 8,000-token prompts saturated the prefill queue, capping cluster output at **94 tokens/sec**. By upgrading to **`3x TP4` prefill workers (12 GPUs)** on 26,000-token prompts (3.25x larger), total output throughput jumped to **833.54 tokens/sec**—a **$8.8\times$ performance increase** made possible by tensor-parallel attention math.

### 2. Operational Sweet Spot at Concurrency 32

While Concurrency 16 delivered faster per-user speeds (68.73 tok/s), it slightly over-delivered on streaming speed at the expense of GPU efficiency. Increasing to **Concurrency 32** brought output speed to **46.71 tok/s/user**—placing it directly in the center of the **30–60 tok/s human perceptual SLA**—while unlocking **21.1% higher total hardware throughput (833.54 tok/s)**.

### 3. Isolated Decode Generation

Because the `TP=4` Decode worker runs independently on Node 2, incoming 26,000-token prompt prefills on Node 1 do not preempt active token generation. This structural isolation maintained an Inter-Token Latency of **15.38ms to 23.79ms**, delivering smooth, stutter-free streaming to all active users.
