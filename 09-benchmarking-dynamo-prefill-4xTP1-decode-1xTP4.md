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

---

## 🚀 Deployment Steps

### 1. Apply the Kubernetes Deployment
Deploy the Dynamo Graph to your namespace:
```bash
kubectl apply -f llama31_70b_dynamo_a4-spot-prefill-4xtp1-decode-1xtp4.yaml
