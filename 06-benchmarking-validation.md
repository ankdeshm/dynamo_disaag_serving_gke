## Phase 6: Benchmarking & Validation

This phase validates the functionality of your Dynamo deployment and runs the performance benchmark to demonstrate the benefits of the Disaggregated Serving architecture, particularly in tail latency under mixed workloads.

### 1. End-to-End Inference Test

First, verify that the system is generating text correctly by sending a sample chat completion request to the Frontend service.

**Terminal 1 (Port Forwarding):** You must run this command in a separate terminal and keep it running for the entire testing phase.

```bash
kubectl port-forward svc/llama3-disagg-frontend -n dynamo-cloud 8000:8000
```

**Terminal 2 (Sending Request):**

```bash
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "meta-llama/Meta-Llama-3.1-70B-Instruct",
    "messages": [{"role": "user", "content": "Write a quick sort in Python."}],
    "max_tokens": 200,
    "temperature": 0.7
  }'
```

If you receive a streaming response with the Python code, your deployment is fully operational\!

### 2. Run the Performance Benchmark

To truly stress-test the disaggregated architecture and prove its value in a real-world scenario (like a RAG workload), we will run a specialized stress test directly from the Frontend pod.

The workload chosen here uses long inputs (8,192 tokens) and short outputs (200 tokens). This configuration is designed to cause Head-of-Line Blocking in a standard (monolithic) vLLM server, but the Dynamo Disaggregated architecture should keep the output stream smooth.


```bash
# 1. Get Frontend Pod Name
export FRONTEND_POD=$(kubectl get pods -n dynamo-cloud -l nvidia.com/dynamo-component-type=frontend -o jsonpath="{.items[0].metadata.name}")

# 2. Execute Benchmark (2000 Prompts | Input: 8,192 Tokens / Output: 200 Tokens)
# This simulates a "Noisy Neighbor" RAG-style workload where the disaggregated architecture shines.
kubectl exec -it -n dynamo-cloud $FRONTEND_POD -- /bin/bash -c '
  # Download tools (fixes "ModuleNotFoundError" if vLLM benchmarks are not pre-installed)
  python3 -c "import urllib.request; urllib.request.urlretrieve(\"https://raw.githubusercontent.com/vllm-project/vllm/v0.6.1/benchmarks/benchmark_serving.py\", \"benchmark_serving.py\")" 2>/dev/null || true
  python3 -c "import urllib.request; urllib.request.urlretrieve(\"https://raw.githubusercontent.com/vllm-project/vllm/v0.6.1/benchmarks/backend_request_func.py\", \"backend_request_func.py\")" 2>/dev/null || true

  # Run Stress Test with long inputs and short outputs (Test 2 configuration)
  python3 benchmark_serving.py \
    --backend vllm \
    --model "meta-llama/Meta-Llama-3.1-70B-Instruct" \
    --dataset-name random \
    --num-prompts 2000 \
    --random-input-len 8192 \
    --random-output-len 200 \
    --port 8000 \
    --trust-remote-code
'
```

-----
