
# Standard vLLM Deployment & Benchmarking Runbook

This runbook covers applying the standard vllm deloyment manifest, verifying pod initialization logs, configuring the client environment, and running the 40 QPS comparison benchmark on standard vLLM.

---

## Phase 1: Apply the Deployment Manifest


```bash
kubectl apply -f llama31_70b_standard_vllm_a4_spot.yaml -n dynamo-cloud

```

---

## Phase 2: Monitor Pod Startup and Verify Readiness

Because Llama 3.1 70B requires downloading ~140 GB of weights on first launch, initialization typically takes 3 to 7 minutes depending on local SSD cache state.

### 1. Watch Pod Status

Monitor all pods in the `dynamo-cloud` namespace until all containers report `1/1 Running`.

```bash
kubectl get pods -n dynamo-cloud -w

```

## Phase 3: Prepare the Benchmark Client Environment

Once all pods are in the `Running` state, enter the `benchmark-client` pod to set up required scripts and dependencies.

### 1. Exec into the Benchmark Client Pod

```bash
kubectl exec -it -n dynamo-cloud deployment/benchmark-client -- /bin/bash

```

---

### 2. Configure Environment & Dependencies

Execute this block inside the client container to export your token, install missing libraries, and download the vLLM benchmark scripts:

```bash
# 1. Export Hugging Face Access Token
export HF_TOKEN="your_hf_token_here"

# 2. Install required Python packages
pip install requests tqdm aiohttp numpy pandas huggingface_hub transformers

# 3. Fetch benchmark execution scripts
python3 -c "import urllib.request; urllib.request.urlretrieve(\"https://raw.githubusercontent.com/vllm-project/vllm/v0.6.1/benchmarks/benchmark_serving.py\", \"benchmark_serving.py\")"
python3 -c "import urllib.request; urllib.request.urlretrieve(\"https://raw.githubusercontent.com/vllm-project/vllm/v0.6.1/benchmarks/backend_request_func.py\", \"backend_request_func.py\")"

```

---

## Phase 4: Execute the Benchmark

Run the 40 QPS test matching the exact configuration used during the standard monolithic vLLM run (1000 prompts | 3000 input tokens | 150 output tokens).

> **Note on Service Endpoint:** Ensure `--host` points to the Dynamo Frontend service name created by the deployment operator (typically `<deployment-name>-frontend` or as defined in your K8s services).

```bash
python3 benchmark_serving.py \
  --backend vllm \
  --model "meta-llama/Meta-Llama-3.1-70B-Instruct" \
  --dataset-name random \
  --num-prompts 1000 \
  --request-rate 40 \
  --random-input-len 3000 \
  --random-output-len 150 \
  --host llama3-standard-service \
  --port 8000 \
  --trust-remote-code

```

---

## Phase 5: Metrics Comparison Matrix

When the benchmark completes, record the output table for standard vLLM baseline:

============ Serving Benchmark Result ============

Successful requests:                     1000      
Benchmark duration (s):                  37.77     
Total input tokens:                      3000000   
Total generated tokens:                  113205    
Request throughput (req/s):              26.47     
Output token throughput (tok/s):         2996.96   
Total Token throughput (tok/s):          82418.15  
---------------Time to First Token----------------
Mean TTFT (ms):                          2280.40   
Median TTFT (ms):                        1657.01   
P99 TTFT (ms):                           8365.61   
-----Time per Output Token (excl. 1st token)------
Mean TPOT (ms):                          98.47     
Median TPOT (ms):                        85.38     
P99 TPOT (ms):                           310.03    
---------------Inter-token Latency----------------
Mean ITL (ms):                           99.95     
Median ITL (ms):                         22.24     
P99 ITL (ms):                            394.83   

==================================================  

==================================================


