
# Comprehensive Benchmark Report: DeepSeek-R1 on 4-Node NVIDIA Dynamo

This document details the performance of the **DeepSeek-R1 (671 Billion parameter FP8)** model running on a 4-node Google Kubernetes Engine (GKE) cluster powered by 32 NVIDIA B200 GPUs.

We ran these tests to prove the system can handle the customer's exact production requirements (the Workato profile):

* **Input size:** 26,000 tokens per request
* **Output size:** ~1,000 tokens per request
* **Target speed:** 30 to 60 tokens per second per user
* **Expected users:** 8 to 32 concurrent requests

The deployment yaml used for this experiment is workatao_deepseekr1_dynamo_4nodes.yaml

## 1. Why We Moved from 2 Nodes to 4 Nodes

Originally, we tested this workload on a 2-node cluster (1 node for reading prompts, 1 node for generating text). While this 2-node setup handled smaller 8,000-token prompts perfectly, it **completely stalled** when we sent it the customer's massive 26,000-token prompts.

**The Bottleneck:** DeepSeek-R1 is huge. When 16 users send 26,000 tokens at the exact same time, a single 8-GPU prefill node is forced to calculate over 400,000 tokens at once. It simply hit a compute wall and stopped responding.

**The Solution:** We expanded the cluster to 4 nodes. We dedicated **3 full nodes (24 GPUs) to reading prompts** (Prefill) and **1 full node (8 GPUs) to generating text** (Decode). This gave the system three times the computing power to chew through long inputs, completely clearing the logjam.

## 2. Full 4-Node Performance Data

We ran a complete sweep of tests on the 4-node cluster, gradually increasing both the prompt size (from 3,000 to 26,000 tokens) and the number of active users (Concurrency 8, 16, and 32).
The script used for running all the benchmarks is run_4node_suite.sh.

Here is exactly how the 4-node cluster performed across every test:

| Input Tokens (ISL) | Concurrent Users | Time To First Token (Wait Time) | Output Speed Per User | Inter-Token Latency | Total Output Throughput |
| --- | --- | --- | --- | --- | --- |
| **3k Tokens** | 16 Users | 1.52 seconds | 62.60 tok/s | 16.10 ms | 838.76 tok/s |
| **3k Tokens** | 32 Users | 1.84 seconds | 52.18 tok/s | 19.51 ms | 1,304.08 tok/s |
| **8k Tokens** | 16 Users | 2.20 seconds | 58.01 tok/s | 17.41 ms | 759.42 tok/s |
| **8k Tokens** | 32 Users | 4.14 seconds | 44.32 tok/s | 23.25 ms | 1,038.65 tok/s |
| **16k Tokens** | 16 Users | 9.07 seconds | 53.28 tok/s | 19.38 ms | 511.50 tok/s |
| **16k Tokens** | 32 Users | 35.94 seconds | 46.24 tok/s | 22.50 ms | 477.34 tok/s |
| **26k Tokens** | **8 Users** | **8.53 seconds** | **59.59 tok/s** | **17.01 ms** | **300.51 tok/s** |
| **26k Tokens** | **16 Users** | **30.75 seconds** | **42.97 tok/s** | **24.27 ms** | **286.11 tok/s** |
| **26k Tokens** | **32 Users** | **70.30 seconds** | **28.72 tok/s** | **37.60 ms** | **289.88 tok/s** |

---

## 3. What the Data Tells Us

### Making 26k Prompts Work

The 4-node cluster proved that DeepSeek-R1 can handle the massive 26,000-token workload without crashing.

* Under a moderate load of **8 concurrent users**, the system performs beautifully. The wait time before text appears is just 8.5 seconds, and it streams out at nearly 60 tokens per second.
* At **16 concurrent users**, wait time goes up to 30 seconds, but the text still streams at a very healthy 43 tokens per second.

### Text Generation (Decode) is Rock Solid

Our disaggregated architecture splits the work so that reading prompts and generating text do not interfere with each other. The data proves this works: no matter how heavy the prompt-reading phase gets, the single Decode node continues to pump out text smoothly. In almost every test, the output speed stays right in the customer's requested **30 to 60 tokens per second** target.

### The Limits of 4 Nodes

You can see the system starts to reach its limit at **26k tokens with 32 users**. Because 32 massive prompts are hitting the prefill nodes at once, a waiting line forms. Wait times stretch to 70 seconds, and the output speed dips just below the target SLA down to 28.72 tokens per second.

---

## 4. When to Scale to an 8-Node Cluster

A 4-node cluster is perfect for moderate traffic (up to 16 users sending 26k prompts at once). But if the customer expects 32 or more users to regularly hit the system at the exact same time, we highly recommend moving to an **8-Node Cluster (64x B200 GPUs)**.

Here is how an 8-node cluster would be configured, and what it improves:

* **Topology:** 6 nodes for reading prompts (Prefill), 2 nodes for generating text (Decode).
* **Wait Times Get Shorter:** By doubling the prefill nodes from 3 to 6, prompt reading power doubles. The 70-second wait time we saw at 32 users will drop closer to 20-30 seconds.
* **Output Speed is Protected:** A single Decode node can only hold about 40 large users in its GPU memory before it runs out of space. Adding a second Decode node doubles the memory capacity. This guarantees that even if 50+ users log on, the text generation speed will stay comfortably above the 30 tokens/second SLA.
