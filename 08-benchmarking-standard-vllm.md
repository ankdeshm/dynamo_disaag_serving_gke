
1. **Export your Hugging Face Token:** Required to access the gated Llama 3.1 tokenizer and configuration.
You must authenticate your session before the scripts attempt to download the model's tokenizer configuration. Replace the placeholder with your actual token.

```bash
export HF_TOKEN="your_hf_token_here"

```


2. **Install all Python Dependencies:** Resolves the ModuleNotFoundError issues.
The `python:3.10-slim` container is barebones. This single command installs the HTTP clients, data processing libraries (`numpy`, `pandas`), and Hugging Face utilities (`huggingface_hub`, `transformers`) required by the benchmark.

```bash
pip install requests tqdm aiohttp numpy pandas huggingface_hub transformers

```


3. **Download the vLLM Benchmark Scripts:**
Fetch the core serving benchmark script and its backend request functionality dependency directly from the vLLM GitHub repository.

```bash
python3 -c "import urllib.request; urllib.request.urlretrieve(\"https://raw.githubusercontent.com/vllm-project/vllm/v0.6.1/benchmarks/benchmark_serving.py\", \"benchmark_serving.py\")"

python3 -c "import urllib.request; urllib.request.urlretrieve(\"https://raw.githubusercontent.com/vllm-project/vllm/v0.6.1/benchmarks/backend_request_func.py\", \"backend_request_func.py\")"

```


4. **Execute the Benchmark:**
With the environment fully prepped, fire your stress test against the cluster.

```bash
python3 benchmark_serving.py \
  --backend vllm \
  --model "meta-llama/Meta-Llama-3.1-70B-Instruct" \
  --dataset-name random \
  --num-prompts 500 \
  --request-rate 15 \
  --random-input-len 8192 \
  --random-output-len 1024 \
  --host llama3-standard-service \
  --port 8000 \
  --trust-remote-code

```
