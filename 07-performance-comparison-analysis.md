# Performance Benchmarks: Dynamo Disaggregated Architecture

This document presents the results of benchmark tests evaluating the performance characteristics of the **Dynamo Disaggregated** server on a single A3 Ultra node. 

Disaggregated setups are inherently designed for scale and isolation, decoupling the compute-intensive prefill phase from the memory-bandwidth-bound decode phase.

---

## Test Environment and Hardware Setup

The following hardware and model configurations were used to establish the baseline for these isolated tests.

| Component | Configuration |
| :--- | :--- |
| **Hardware** | 1x A3 Ultra Node (Split 4x Prefill + 4x Decode H200 GPUs) |
| **Model** | Llama 3.1 70B Instruct (BF16) |
| **Deployment** | Dynamo Disaggregated |

---

## Benchmark 1: Balanced Chat Workload

This test evaluates the system using a workload with approximately equal input and output tokens, which is highly representative of a general conversational AI scenario.

**Workload Parameters:** 1100 Prompts (1000 Input Tokens / 1000 Output Tokens)

| Metric | Dynamo Disaggregated Result |
| :--- | :--- |
| **Request Throughput** | 3.51 req/s |
| **Token Throughput** | 1,461 tok/s |
| **Mean TTFT** (Start Time) | 121.35 s |
| **P99 TPOT** (Tail Latency) | 541.22 ms |

**Key Observation:** In this balanced test, the Dynamo architecture successfully processed the workload by maintaining its strict separation of **prefill** and **decode** tasks, providing predictable throughput.

---

## Benchmark 2: RAG and Noisy Neighbor Stress Test

This test simulates a **Retrieval-Augmented Generation (RAG)** or document summarization workload featuring extremely long inputs and short outputs. It is explicitly designed to test how well the architecture prevents **Head-of-Line Blocking** and maintains process isolation.

**Workload Parameters:** 2000 Prompts | Input: 8,192 Tokens (Long) | Output: 200 Tokens (Short)

| Metric | Dynamo Disaggregated Result |
| :--- | :--- |
| **Total Duration** | 40 min 49s (2449s) |
| **Request Throughput** | 0.82 req/s |
| **Mean TTFT** (Wait Time) | 1,036 sec |
| **P99 TPOT** (Tail Latency) | 100.46 ms |

---

## Architectural Analysis and Insights

The data from the stress test reveals the core strengths and scaling requirements of a disaggregated approach.

### 1. Latency Isolation and Smooth Streams

The highly impressive **P99 TPOT of 100.46 ms** demonstrates that text generation never paused or stuttered. The dedicated **Decode Worker** remained completely isolated from the **Prefill Worker's** massive compute load.

> **Pro-Tip:** This isolation ensures a silky-smooth reading experience for active users, even when the system is bombarded with massive concurrent document uploads.

### 2. Scaling Considerations and Compute Deficits

The mean TTFT and overall throughput reflect a **Compute Deficit** on the prefill side, as 4 GPUs were tasked with processing heavy 8K inputs, causing a queue buildup. 

- The intended solution in a production environment is to scale out the **Prefill** workers independently.
- Handling long prompt loads becomes a matter of adding prefill capacity without over-provisioning decode hardware.
- This creates a highly elastic infrastructure model.

---

## Ideal Use Cases for Dynamo Disaggregated

Based on the benchmark data, this architecture is highly recommended for specific operational profiles.

- **User Experience First:** Applications where you cannot tolerate active chat streams freezing when new requests arrive.
- **Mixed Workloads:** Environments where some users send massive documents for RAG while others ask short, rapid questions simultaneously.
- **Independent Scaling:** Infrastructure setups where you can independently scale prefill instances to match incoming prompt spikes, rather than being restricted to the fixed ratios of a monolithic node.
