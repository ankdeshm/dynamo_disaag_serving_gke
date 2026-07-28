#!/bin/bash
export PATH="$HOME/.local/bin:$PATH"

echo "================================================================="
echo " STARTING 4-NODE DEEPSEEK-R1 BENCHMARK SUITE (3P:1D TOPOLOGY)"
echo "================================================================="

# --- 1. 3k ISL @ Concurrency 16 ---
echo ""
echo "[1/7] Running 3k ISL @ Concurrency 16..."
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
  --artifact-dir concurrency_16_dynamo_workato_deepseek_3k_4node \
  --profile-export-file profile_export_dynamo_workato_deepseek_c16_3k_4node.json \
  -- --max-threads 16

echo "Waiting 15 seconds for queues to clear..."
sleep 15

# --- 2. 3k ISL @ Concurrency 32 ---
echo ""
echo "[2/7] Running 3k ISL @ Concurrency 32..."
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
  --artifact-dir concurrency_32_dynamo_workato_deepseek_3k_4node \
  --profile-export-file profile_export_dynamo_workato_deepseek_c32_3k_4node.json \
  -- --max-threads 32

echo "Waiting 15 seconds for queues to clear..."
sleep 15

# --- 3. 8k ISL @ Concurrency 16 ---
echo ""
echo "[3/7] Running 8k ISL @ Concurrency 16..."
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
  --artifact-dir concurrency_16_dynamo_workato_deepseek_8k_4node \
  --profile-export-file profile_export_dynamo_workato_deepseek_c16_8k_4node.json \
  -- --max-threads 16

echo "Waiting 15 seconds for queues to clear..."
sleep 15

# --- 4. 8k ISL @ Concurrency 32 ---
echo ""
echo "[4/7] Running 8k ISL @ Concurrency 32..."
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
  --artifact-dir concurrency_32_dynamo_workato_deepseek_8k_4node \
  --profile-export-file profile_export_dynamo_workato_deepseek_c32_8k_4node.json \
  -- --max-threads 32

echo "Waiting 15 seconds for queues to clear..."
sleep 15

# --- 5. 16k ISL @ Concurrency 16 ---
echo ""
echo "[5/7] Running 16k ISL @ Concurrency 16..."
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
  --artifact-dir concurrency_16_dynamo_workato_deepseek_16k_4node \
  --profile-export-file profile_export_dynamo_workato_deepseek_c16_16k_4node.json \
  -- --max-threads 16

echo "Waiting 15 seconds for queues to clear..."
sleep 15

# --- 6. 16k ISL @ Concurrency 32 ---
echo ""
echo "[6/7] Running 16k ISL @ Concurrency 32..."
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
  --artifact-dir concurrency_32_dynamo_workato_deepseek_16k_4node \
  --profile-export-file profile_export_dynamo_workato_deepseek_c32_16k_4node.json \
  -- --max-threads 32

echo "Waiting 15 seconds for queues to clear..."
sleep 15

# --- 7. 26k ISL @ Concurrency 8 ---
echo ""
echo "[7/7] Running 26k ISL @ Concurrency 8..."
genai-perf profile -m deepseek-ai/DeepSeek-R1 \
  --tokenizer deepseek-ai/DeepSeek-R1 \
  --endpoint-type chat \
  --endpoint v1/chat/completions \
  --url 127.0.0.1:8000 \
  --streaming \
  --concurrency 8 \
  --num-dataset-entries 650 \
  --warmup-request-count 8 \
  --request-count 100 \
  --synthetic-input-tokens-mean 26000 \
  --synthetic-input-tokens-stddev 0 \
  --output-tokens-mean 750 \
  --output-tokens-stddev 0 \
  --extra-inputs min_tokens:500 \
  --extra-inputs max_tokens:1000 \
  --extra-inputs ignore_eos:true \
  --random-seed 0 \
  --artifact-dir concurrency_8_dynamo_workato_deepseek_26k_4node \
  --profile-export-file profile_export_dynamo_workato_deepseek_c8_26k_4node.json \
  -- --max-threads 8

echo ""
echo "================================================================="
echo " ALL 7 BENCHMARKS COMPLETED SUCCESSFULLY!"
echo "================================================================="
