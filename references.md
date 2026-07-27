# References & Community Insights

This repository's architectural decisions and benchmark configurations were heavily shaped by active community discussions surrounding Dynamo's performance compared to monolithic serving engines like standard vLLM and SGLang. 

Below are the key GitHub issues that guided our tuning for disaggregated serving:

### 1. [Dynamo Issue #387: Lower overall throughput compared to vLLM/SGLang](https://github.com/ai-dynamo/dynamo/issues/387)
**Why we referenced it:** Users frequently observed that Dynamo's raw aggregate throughput appeared lower than monolithic alternatives out of the box. 
**How it shaped our experiments:** This thread helped us understand that Dynamo's primary value proposition is strict SLA protection and lower Inter-Token Latency (ITL), not unconstrained throughput. It shifted our benchmarking strategy to focus heavily on the "Time to Second Token" and "Tokens/sec/User" metrics to prove streaming stability under heavy load.

### 2. [Dynamo Issue #402 (Comment 2769181444): KV Cache Transfer Bottlenecks & TTFT Spikes](https://github.com/ai-dynamo/dynamo/issues/402#issuecomment-2769181444)
**Why we referenced it:** Early disaggregated setups were suffering from massive Time-To-First-Token (TTFT) delays due to the system falling back to slow PCIe lanes during prefill-to-decode KV cache transfers.
**How it shaped our experiments:** This specific comment provided the exact environment variables (`UCX_TLS=all`, `NCCL_CROSS_NIC=1`) required to force high-speed NVLink/NIXL interconnects. It also highlighted the need for dynamic GPU device locking (`flock`) to prevent memory collisions when scheduling multiple workers on the same host.

### 3. [Dynamo Issue #2552: Prefill Queue Saturation on Long Contexts](https://github.com/ai-dynamo/dynamo/issues/2552)
**Why we referenced it:** The community identified that Dynamo's total throughput degrades severely when processing extremely long context prompts (e.g., 8k+ input tokens) with single-GPU prefill workers.
**How it shaped our experiments:** This issue taught us about the $O(N^2)$ attention compute bottleneck on isolated GPUs. It directly informed our multi-node architecture sizing, leading us to abandon `TP=1` prefill workers and instead allocate `TP=4` clusters for prefill to handle the heavy 26,000 ISL Workato POC effectively.
