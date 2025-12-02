### 📊 Performance Comparison: Standard vLLM vs. Dynamo Disaggregated

This section presents the results of two benchmark tests comparing the performance characteristics of a monolithic vLLM server (8x H200 GPUs) against the Dynamo Disaggregated server (Split 4x Prefill + 4x Decode H200 GPUs) on a single A3 Ultra node.

> **For Reproducibility:** To compare against the monolithic (Standard) vLLM results shown here, you can use the corresponding deployment manifest. This manifest provisions vLLM directly on the same A3 Ultra cluster without the Dynamo operator or split architecture.
>
> ➡️ **Standard vLLM Deployment Manifest:** [llama31_70b_standard_vllm.yaml](llama31_70b_standard_vllm.yaml) 

#### Test Setup

| Detail | Configuration |
| :--- | :--- |
| **Hardware** | 1x A3 Ultra Node (8x H200 GPUs) |
| **Model** | Llama 3.1 70B Instruct (BF16) |

---


### Test 1: Balanced Workload

This test uses a workload with approximately equal input and output tokens, typical of a general chat scenario.

**Workload:** 1100 Prompts (1000 Input Tokens / 1000 Output Tokens)

| Metric | Standard vLLM (Monolithic 8-GPU) | Dynamo Disaggregated (Split 4+4 GPUs) | Winner |
| :--- | :--- | :--- | :--- |
| **Request Throughput** | 12.02 req/s | 3.51 req/s | Standard (3.4x faster) |
| **Token Throughput** | 5,500 tok/s | 1,461 tok/s | Standard (3.7x faster) |
| **Mean TTFT** (Start Time) | 21.57 s | 121.35 s | Standard (5.6x faster) |
| **P99 TPOT** (Tail Latency) | 590.71 ms | **541.22 ms** | Dynamo (8% better) |

**Insight:** In this balanced test, the brute force of 8 GPUs handling both prefill and decode in the Standard setup dominated. The long prompt processing wasn't heavy enough to trigger the stuttering issues Dynamo is designed to solve.

-----

### Test 2: RAG / "Noisy Neighbor" Stress Test

This test simulates a **RAG or document summarization workload** (long inputs, short outputs) which is designed to introduce **Head-of-Line Blocking** in the monolithic Standard vLLM server, proving Dynamo's isolation benefits.

**Workload:** 2000 Prompts | Input: 8,192 Tokens (Long) | Output: 200 Tokens (Short)

| Metric | Standard vLLM (Monolithic 8-GPU) | Dynamo Disaggregated (Split 4+4 GPUs) | Winner |
| :--- | :--- | :--- | :--- |
| **Total Duration** | 12 min 57s (777s) | 40 min 49s (2449s) | Standard (3x Faster) |
| **Request Throughput** | 2.57 req/s | 0.82 req/s | Standard (3x Higher) |
| **Mean TTFT** (Wait Time) | 325 sec | 1,036 sec | Standard (3x Faster) |
| **P99 TPOT** (Tail Latency) | **1,106.83 ms** | **100.46 ms** | **Dynamo (11x Smoother)** |

#### Analysis: Why Dynamo Won on Tail Latency

1.  **The Stutter (Where Standard vLLM Failed):**
    The **P99 TPOT of 1,106 ms** for Standard vLLM means active users watching the text stream experienced interruptions lasting over a full second, caused by new 8K-token requests arriving and blocking the GPU's generation work.
2.  **The Smooth Stream (Where Dynamo Shined):**
    The **P99 TPOT of 100 ms** for Dynamo shows the text generation never paused. The dedicated Decode Worker remained completely isolated from the Prefill Worker's massive input load, ensuring a silky-smooth experience for active users.
3.  **The Bottleneck (Why Dynamo was Slower Overall):**
    Dynamo's lower total throughput is due to a **Compute Deficit** on the Prefill side (4 GPUs vs. Standard's 8 GPUs for 8K inputs). This caused a massive queue buildup and the high TTFT. The solution in a production environment would be to scale out the **Prefill** workers independently to handle the long prompt load while keeping the **Decode** workers streamlined.

### Dynamo or No Dynamo?

| Choose Dynamo if... | Choose Standard vLLM if... |
| :--- | :--- |
| **User Experience is King:** You cannot tolerate chat application "freezing" for new requests. | **Throughput is King:** You are focused on offline batch processing (e.g., analyzing documents overnight) and don't care about "stuttering." |
| **Mixed Workloads:** You expect users to send long documents (RAG) while others ask short questions simultaneously. | **Hardware is Limited:** You only have 1 node and cannot add more Prefill workers to balance the load. |

-----
