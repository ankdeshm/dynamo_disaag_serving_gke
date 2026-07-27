
# Multi-Node NVIDIA Dynamo Disaggregated Benchmark: DeepSeek-R1 (16x B200 GPUs)

This document presents the setup, commands, test results, and performance analysis for serving the **DeepSeek-R1 (671B parameter FP8)** model using NVIDIA Dynamo Disaggregated Serving on a 2-node (16x B200 GPU) GKE cluster.

---

## 1. Context and Test Objectives

The primary goal was to test DeepSeek-R1 against the customer's production workload profile (the Workato profile):

* **Input Sequence Length (ISL):** ~26,000 input tokens (80% of the context window)


* **Output Sequence Length (OSL):** ~1,000 output tokens


* **Target User SLA:** 30–60 tokens/second per user streaming output


* **Cluster Hardware:** 2x GKE Nodes (16x NVIDIA B200 GPUs total)



### Why We Adjusted the Test Profiles

When we ran the full 26k ISL test on this 2-node cluster, there were no system errors or crashes. However, the benchmark took an extremely long time to run.

Because DeepSeek-R1 is a massive 671B parameter Mixture-of-Experts (MoE) model, running 26k input tokens at concurrency 16 completely saturated the memory and compute bandwidth of the single 8-GPU prefill node. To understand how the system performs as prompt lengths increase, we ran smaller test profiles: **3k ISL**, **8k ISL**, and **16k ISL**, each tested at **Concurrency 16** and **Concurrency 32**.

---

## 2. Architecture Configuration

Unlike smaller models, DeepSeek-R1 requires roughly 700GB of VRAM just to load the model weights in FP8. Because of this footprint, a single 4-GPU worker slice was not enough.

We reconfigured the deployment to a **1P:1D disaggregated topology**:

* **Prefill Worker (Node 1):** Spans all 8 GPUs on Node 1 (`TP=8`).


* **Decode Worker (Node 2):** Spans all 8 GPUs on Node 2 (`TP=8`).



### Key Settings Applied

* `tensor-parallel-size: 8` and `--enable-expert-parallel` enabled to distribute the MoE layers across 8 GPUs per node.


* Static node assignment (`CUDA_VISIBLE_DEVICES="0,1,2,3,4,5,6,7"`) to give each worker full access to an entire 8-GPU node.


* FlashInfer Multi-Level Attention (MLA) enabled.



---

## 3. Benchmarking Commands

All tests were executed using `genai-perf` against the Dynamo frontend service.
The deployment code can be found in `workato_deepseekr1_dynamo_2nodes.yaml` file

### 3k ISL Commands

```bash
# Concurrency 16
genai-perf profile -m deepseek-ai/DeepSeek-R1 \
  --tokenizer deepseek-ai/DeepSeek-R1 \
  --endpoint-type chat \
  --endpoint v1/chat/completions \
  --url 127.0.0.1:8000 \
  --streaming \
  --concurrency 16 \
  --num-dataset-entries 650 \
  --warmup-request-count 16 \
  --request-count 100 \
  --synthetic-input-tokens-mean 3000 \
  --synthetic-input-tokens-stddev 0 \
  --output-tokens-mean 750 \
  --output-tokens-stddev 0 \
  --extra-inputs min_tokens:500 \
  --extra-inputs max_tokens:1000 \
  --extra-inputs ignore_eos:true \
  --random-seed 0 \
  --artifact-dir concurrency_16_dynamo_workato_deepseek_3k \
  --profile-export-file profile_export_dynamo_workato_deepseek_c16_3k.json \
  -- --max-threads 16

# Concurrency 32
genai-perf profile -m deepseek-ai/DeepSeek-R1 \
  --tokenizer deepseek-ai/DeepSeek-R1 \
  --endpoint-type chat \
  --endpoint v1/chat/completions \
  --url 127.0.0.1:8000 \
  --streaming \
  --concurrency 32 \
  --num-dataset-entries 650 \
  --warmup-request-count 32 \
  --request-count 100 \
  --synthetic-input-tokens-mean 3000 \
  --synthetic-input-tokens-stddev 0 \
  --output-tokens-mean 750 \
  --output-tokens-stddev 0 \
  --extra-inputs min_tokens:500 \
  --extra-inputs max_tokens:1000 \
  --extra-inputs ignore_eos:true \
  --random-seed 0 \
  --artifact-dir concurrency_32_dynamo_workato_deepseek_3k \
  --profile-export-file profile_export_dynamo_workato_deepseek_c32_3k.json \
  -- --max-threads 32

```

### 8k ISL Commands

```bash
# Concurrency 16
genai-perf profile -m deepseek-ai/DeepSeek-R1 \
  --tokenizer deepseek-ai/DeepSeek-R1 \
  --endpoint-type chat \
  --endpoint v1/chat/completions \
  --url 127.0.0.1:8000 \
  --streaming \
  --concurrency 16 \
  --num-dataset-entries 650 \
  --warmup-request-count 16 \
  --request-count 100 \
  --synthetic-input-tokens-mean 8000 \
  --synthetic-input-tokens-stddev 0 \
  --output-tokens-mean 750 \
  --output-tokens-stddev 0 \
  --extra-inputs min_tokens:500 \
  --extra-inputs max_tokens:1000 \
  --extra-inputs ignore_eos:true \
  --random-seed 0 \
  --artifact-dir concurrency_16_dynamo_workato_deepseek_8k \
  --profile-export-file profile_export_dynamo_workato_deepseek_c16_8k.json \
  -- --max-threads 16

# Concurrency 32
genai-perf profile -m deepseek-ai/DeepSeek-R1 \
  --tokenizer deepseek-ai/DeepSeek-R1 \
  --endpoint-type chat \
  --endpoint v1/chat/completions \
  --url 127.0.0.1:8000 \
  --streaming \
  --concurrency 32 \
  --num-dataset-entries 650 \
  --warmup-request-count 32 \
  --request-count 100 \
  --synthetic-input-tokens-mean 8000 \
  --synthetic-input-tokens-stddev 0 \
  --output-tokens-mean 750 \
  --output-tokens-stddev 0 \
  --extra-inputs min_tokens:500 \
  --extra-inputs max_tokens:1000 \
  --extra-inputs ignore_eos:true \
  --random-seed 0 \
  --artifact-dir concurrency_32_dynamo_workato_deepseek_8k \
  --profile-export-file profile_export_dynamo_workato_deepseek_c32_8k.json \
  -- --max-threads 32

```

### 16k ISL Commands

```bash
# Concurrency 16
genai-perf profile -m deepseek-ai/DeepSeek-R1 \
  --tokenizer deepseek-ai/DeepSeek-R1 \
  --endpoint-type chat \
  --endpoint v1/chat/completions \
  --url 127.0.0.1:8000 \
  --streaming \
  --concurrency 16 \
  --num-dataset-entries 650 \
  --warmup-request-count 16 \
  --request-count 100 \
  --synthetic-input-tokens-mean 16000 \
  --synthetic-input-tokens-stddev 0 \
  --output-tokens-mean 750 \
  --output-tokens-stddev 0 \
  --extra-inputs min_tokens:500 \
  --extra-inputs max_tokens:1000 \
  --extra-inputs ignore_eos:true \
  --random-seed 0 \
  --artifact-dir concurrency_16_dynamo_workato_deepseek_16k \
  --profile-export-file profile_export_dynamo_workato_deepseek_c16_16k.json \
  -- --max-threads 16

# Concurrency 32
genai-perf profile -m deepseek-ai/DeepSeek-R1 \
  --tokenizer deepseek-ai/DeepSeek-R1 \
  --endpoint-type chat \
  --endpoint v1/chat/completions \
  --url 127.0.0.1:8000 \
  --streaming \
  --concurrency 32 \
  --num-dataset-entries 650 \
  --warmup-request-count 32 \
  --request-count 100 \
  --synthetic-input-tokens-mean 16000 \
  --synthetic-input-tokens-stddev 0 \
  --output-tokens-mean 750 \
  --output-tokens-stddev 0 \
  --extra-inputs min_tokens:500 \
  --extra-inputs max_tokens:1000 \
  --extra-inputs ignore_eos:true \
  --random-seed 0 \
  --artifact-dir concurrency_32_dynamo_workato_deepseek_16k \
  --profile-export-file profile_export_dynamo_workato_deepseek_c32_16k.json \
  -- --max-threads 32

```

---

## 4. Empirical Results Table

Below are the metric results collected across all six test runs on the 16-GPU cluster.

| Metric / Statistic | 3k ISL (C16) | 3k ISL (C32) | 8k ISL (C16) | 8k ISL (C32) | 16k ISL (C16) | 16k ISL (C32) |
| --- | --- | --- | --- | --- | --- | --- |
| **Input Sequence Length (ISL)** | 3,000 | 3,000 | 8,000 | 8,000 | 16,000 | 16,000 |
| **Output Sequence Length (OSL)** | 999.02 | 999.04 | 998.95 | 998.90 | 998.88 | 998.90 |
| **Time To First Token (TTFT)** | **1.36 s** | **2.18 s** | **2.32 s** | **89.87 s** | **65.19 s** | **137.14 s** |
| **Inter-Token Latency (ITL)** | **16.22 ms** | **19.22 ms** | **17.96 ms** | **20.54 ms** | **19.09 ms** | **25.47 ms** |
| **Output Speed Per User** | **62.06 tok/s** | **52.63 tok/s** | **56.08 tok/s** | **50.38 tok/s** | **54.60 tok/s** | **42.15 tok/s** |
| **Total Output Token Throughput** | **839.30 tok/s** | **1,306.87 tok/s** | **733.47 tok/s** | **266.27 tok/s** | **184.11 tok/s** | **185.84 tok/s** |
| **Request Throughput** | **0.84 req/s** | **1.31 req/s** | **0.73 req/s** | **0.27 req/s** | **0.18 req/s** | **0.19 req/s** |
| **Mean Request Latency** | **17.55 s** | **21.37 s** | **20.25 s** | **110.37 s** | **84.24 s** | **162.56 s** |

---

## 5. Performance Analysis

### 1. Per-User Streaming Speed Remains Solid

Across almost every single run, the output generation speed per user stayed between **42.15 and 62.06 tokens/second/user**, and the Inter-Token Latency stayed close to 16–25 ms.

* This shows that once a prompt finishes prefilling and moves to the decode stage, the decode node generates tokens smoothly and reliably.
* The streaming output speed easily met the target **30–60 tok/s per user SLA** across all configurations.



### 2. Prefill Worker Becomes the Main Bottleneck

While decoding was steady, prompt processing time (Time To First Token) increased sharply as sequence length and concurrency grew:

* At **3k ISL**, TTFT stayed very low (1.36s at C16, 2.18s at C32).
* At **8k ISL**, TTFT was good at C16 (2.32s), but jumped to **89.87s** at C32.
* At **16k ISL**, TTFT was **65.19s** at C16 and **137.14s** at C32.

This shows that a single 8-GPU prefill worker gets queued up quickly when handling long inputs or high concurrency. The prefill worker simply cannot process long context prompts fast enough to keep up with incoming requests.

### 3. Clear Benefit of Disaggregation

Even when the prefill node was heavily queued (e.g., 16k C32 with a 137-second TTFT), the decode node kept streaming tokens at **42.15 tok/s per user**. This confirms that separating prefill and decode onto different nodes works as intended: prefill delays do not slow down active token generation once it starts.

---

## 6. Comparison with Llama 3 70B & Next Recommendations

### Comparison with Llama 3 70B

When we ran this same 2-node (16 GPU) setup for **Llama 3 70B**, it handled the full 26k ISL workload easily.

However, **DeepSeek-R1 is a 671B model**. Even though MoE only activates ~37B parameters per token during decoding, the entire prompt prefill phase requires far more memory and matrix computation than a 70B model. Because of this, a 2-node cluster (`1P:1D`) works well for DeepSeek-R1 up to **8k ISL**, but cannot comfortably handle 26k ISL prompts.

### Next Steps & Recommendation

To support the customer's target **26,000 ISL production workload** at Concurrency 16+ without long prefill waiting times, we recommend moving to a **4-node cluster setup (32x B200 GPUs total)**.

* **Recommended Topology:** **3P:1D** (3 Prefill Nodes running `TP=8` and 1 Decode Node running `TP=8`).


* **Why:** Tripling the prefill capacity will remove the prompt ingestion bottleneck, bringing Time To First Token back down to acceptable levels for 26k context inputs.
