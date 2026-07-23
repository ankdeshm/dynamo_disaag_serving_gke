
# Standard vLLM Baseline Serving: Llama 3.1 70B FP8 (4-GPU Topology: 4x TP1)

This repository contains the deployment configurations (`llama3-standard-4xtp1.yaml`) and benchmarking guidelines for running a **Standard Monolithic vLLM Baseline** across a **4-GPU footprint** (4 Replicas × Tensor Parallelism 1).

This setup serves as an exact **4-GPU apples-to-apples baseline** to compare standard monolithic vLLM serving against **NVIDIA Dynamo Disaggregated Serving** (`3 Prefill TP1 : 1 Decode TP1`).

---

## 🎯 Architectural Rationale & YAML Design

To perform an isolated, 4-GPU comparative benchmark against Dynamo's 3:1 disaggregated layout, the deployment manifest incorporates specific architectural choices:

### 1. 4x Independent Replicas (`TP=1`)
* **The Configuration:** `replicas: 4` with `--tensor-parallel-size 1`.
* **The Reason:** Because we use the FP8 quantized Llama 3.1 70B model (`neuralmagic/Meta-Llama-3.1-70B-Instruct-FP8`), model weights consume ~70 GB of VRAM, fitting comfortably on a single 180 GB NVIDIA B200 GPU. Running 4 independent `TP=1` workers eliminates Tensor Parallel communication overhead completely.
* **Dynamic Prefill/Decode:** Unlike disaggregated serving, each standard vLLM instance processes both context prefill and token generation dynamically on the same GPU.

### 2. Equal Hardware Allocation
* **Resource Allocation:** Each replica requests `gpu: 1`, `cpu: 16`, and `memory: 150Gi`.
* **Total Cluster Footprint:** 4 GPUs total across 4 pods, perfectly matching the 4 GPUs allocated to the Dynamo `3 Prefill : 1 Decode` experiment.
* **Load Balancing:** A Kubernetes ClusterIP service (`llama3-standard-service`) automatically balances incoming HTTP requests evenly across all 4 running workers.

### 3. Dynamic GPU Isolation (`CUDA_VISIBLE_DEVICES`)
* **The Mechanism:** A file-locking script (`flock`) on a shared `/ssd/locks` volume executes during container startup.
* **The Reason:** Standard GKE/gIB network plugins require `securityContext: privileged: true`, which bypasses container-level GPU isolation. The script forces sequential device assignment so each replica pod exclusively claims one physical GPU (`0`, `1`, `2`, or `3`) without device index collision.

### 4. Key vLLM Configuration Parameters
* `--model` & `--tokenizer`: `neuralmagic/Meta-Llama-3.1-70B-Instruct-FP8`
* `--kv-cache-dtype fp8` & `--block-size 128`: Maximizes KV cache capacity and aligns block sizing with Dynamo.
* `--max-model-len 32768`: Supports up to 32k context lengths.
* `--gpu-memory-utilization 0.90`: Reserves 90% of GPU memory for weights and KV cache.

---

## 🚀 Deployment Steps

### 1. Apply the Deployment
Ensure previous standard or Dynamo deployments are removed from the cluster, then apply the 4x TP1 manifest:

```bash
kubectl apply -f llama31_70b_standard_vllm_a4_spot_4xtp1.yaml

```

Verify all 4 replica pods reach the `1/1 Running` state:

```bash
kubectl get pods -n dynamo-cloud -w

```

### 2. Verify Application Startup

Check the pod logs to ensure model weights are loaded and the server is listening:

```bash
kubectl logs -n dynamo-cloud -l app=llama3-standard --tail=15

```

> **Important:** Proceed to port forwarding only after seeing `INFO: Application startup complete.` in the logs.

### 3. Port-Forward the Service (Terminal 1)

Expose the OpenAI-compatible service endpoint on local port `8000`:

```bash
kubectl port-forward -n dynamo-cloud svc/llama3-standard-service 8000:8000

```

*(Keep this terminal window active throughout the benchmarking run).*

---

## 🧪 Benchmarking Setup with GenAI-Perf

To capture sustained performance and remain consistent with the 4-GPU Dynamo benchmark:

* **Elevated Warmup:** `--warmup-request-count 30` to stabilize CUDA graphs and PyTorch allocators.
* **High Sample Count:** `--request-count 600` across 650 dataset entries.
* **Fixed Token Counts:** 3,000 input prompt tokens, 150 generated output tokens (`ignore_eos: true`).

### Run Concurrency 16 Benchmark (Terminal 2)

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
  --artifact-dir concurrency_16_standard_4tp1 \
  --profile-export-file profile_export_standard_4tp1_c16.json \
  -- --max-threads 16

```

### Run Concurrency 32 Benchmark (Terminal 2)

```bash
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
  --artifact-dir concurrency_32_standard_4tp1 \
  --profile-export-file profile_export_standard_4tp1_c32.json \
  -- --max-threads 32

```

---

## 📊 Benchmark Results: Standard vLLM (4x TP1)

Below is the performance summary for Standard vLLM (`4x TP=1` Replicas) across Concurrency 16 and Concurrency 32 load tests:

| Metric / Statistic | Concurrency 16 | Concurrency 32 | Delta / Observation |
| --- | --- | --- | --- |
| **Total Output Token Throughput** | **446.01 tok/s** | **560.56 tok/s** | 🚀 **+25.7% Aggregate Output** |
| **Request Throughput** | **2.97 req/s** | **3.74 req/s** | 🚀 **+25.9% Completion Rate** |
| **Output Throughput Per User** | **46.27 tok/s/user** | **26.85 tok/s/user** | 📉 -42.0% (Batch Saturation) |
| **Mean Time To First Token (TTFT)** | **1,894.44 ms** | **2,562.52 ms** | +668.08 ms |
| **Mean Time To Second Token** | **388.52 ms** | **449.03 ms** | +60.51 ms |
| **Mean Inter-Token Latency (ITL)** | **23.05 ms** | **39.71 ms** | +16.66 ms |
| **Mean Request Latency** | **5,328.76 ms** | **8,479.68 ms** | +3,150.92 ms |

---

## 🔬 Cross-Architecture Comparison: Standard vLLM (4x TP1) vs. Dynamo Disaggregated (3P:1D TP1)

To evaluate the impact of Disaggregated Serving on a 4-GPU cluster footprint, we compare Standard vLLM against NVIDIA Dynamo serving under identical request parameters (3,000 input tokens, 150 output tokens, 600 requests):

### 1. Concurrency 16 Comparison

| Metric / Statistic | Dynamo Disaggregated<br>

<br>*(3 Prefill TP1 : 1 Decode TP1)* | Standard vLLM<br>

<br>*(4 Replicas TP1)* | Winner / Key Delta |
| --- | --- | --- | --- |
| **Mean Time To First Token (TTFT)** | **1,342.80 ms** | **1,894.44 ms** | ⚡ **Dynamo** (551.64 ms / **29.1% Faster**) |
| **Mean Time To Second Token** | **229.42 ms** | **388.52 ms** | ⚡ **Dynamo** (159.10 ms / **40.9% Faster**) |
| **Total Output Token Throughput** | **414.88 tok/s** | **446.01 tok/s** | **Standard vLLM** (+7.5%) |
| **Request Throughput** | **2.77 req/s** | **2.97 req/s** | **Standard vLLM** (+7.2%) |
| **Output Throughput Per User** | **35.40 tok/s/user** | **46.27 tok/s/user** | **Standard vLLM** (+30.7%) |
| **Mean Inter-Token Latency (ITL)** | **29.21 ms** | **23.05 ms** | **Standard vLLM** (-6.16 ms) |
| **Mean Request Latency** | **5,694.92 ms** | **5,328.76 ms** | **Standard vLLM** (-366.16 ms) |

---

### 2. Concurrency 32 Comparison

| Metric / Statistic | Dynamo Disaggregated<br>

<br>*(3 Prefill TP1 : 1 Decode TP1)* | Standard vLLM<br>

<br>*(4 Replicas TP1)* | Winner / Key Delta |
| --- | --- | --- | --- |
| **Mean Time To First Token (TTFT)** | **3,411.82 ms** | **2,562.52 ms** | **Standard vLLM** (849.30 ms / **24.9% Faster**) |
| **Mean Time To Second Token** | **403.73 ms** | **449.03 ms** | ⚡ **Dynamo** (45.30 ms / **10.1% Faster**) |
| **Total Output Token Throughput** | **499.24 tok/s** | **560.56 tok/s** | **Standard vLLM** (+12.3%) |
| **Request Throughput** | **3.33 req/s** | **3.74 req/s** | **Standard vLLM** (+12.3%) |
| **Output Throughput Per User** | **27.94 tok/s/user** | **26.85 tok/s/user** | ⚡ **Dynamo** (+4.1%) |
| **Mean Inter-Token Latency (ITL)** | **39.66 ms** | **39.71 ms** | **Parity** (~39.7 ms) |
| **Mean Request Latency** | **9,321.85 ms** | **8,479.68 ms** | **Standard vLLM** (-842.17 ms) |

---

## 🔑 Key Technical Insights & Takeaways

### 1. Responsiveness & Initial Latency (Time to First & Second Token)

* **At Concurrency 16:** Dynamo disaggregated serving dramatically outperforms standard vLLM in responsiveness, reducing TTFT by **29.1%** (1.34s vs 1.89s) and Time to 2nd Token by **40.9%** (229ms vs 388ms). Offloading heavy 3,000-token prefills to 3 dedicated workers eliminates prefill preemption on the generation engine.
* **At Concurrency 32 Bottlenecking:** Having only **1 Decode worker** in the 3P:1D allocation creates a queueing bottleneck under 32 concurrent streams, increasing TTFT for Dynamo to 3.41s. Meanwhile, standard vLLM's 4 dynamic workers share the decode load across 4 GPUs, keeping TTFT lower (2.56s).

### 2. Aggregate Throughput vs. Resource Allocation

* Standard vLLM allocates 100% of all 4 GPUs dynamically to both prefill and decode tasks, resulting in higher overall generation throughput (**446 tok/s at c=16**, **560 tok/s at c=32**) compared to Dynamo reserving 3 out of 4 GPUs strictly for prefilling.
* **Optimal Use Case:** Disaggregation with a `3:1` ratio is ideal for low-latency responsiveness and interactive streaming at lower-to-medium concurrency levels, whereas high aggregate throughput on 4 GPUs favors uniform monolithic allocation or allocating a `2:2` / `TP>1` ratio on larger GPU clusters.
