#!/bin/bash
set -e

model="$1"
input_len="$2"
output_len="$3"
batch_size="$4"
warmup_iters="$5"
benchmark_iters="$6"

short_model=$(echo "$model" | tr '/' '_')
exp_name="${short_model}_in${input_len}_out${output_len}_bs${batch_size}_w${warmup_iters}_n${benchmark_iters}_g${BENCHMARK_GPU_COUNT}"

OUTPUT_DIR="${BENCHMARK_OUTPUT_DIR:-output}"
mkdir -p "$OUTPUT_DIR/logs/latency"
mkdir -p "$OUTPUT_DIR/jsons/latency"

log_path="$OUTPUT_DIR/logs/latency/${exp_name}_latency.log"
result_path="$OUTPUT_DIR/jsons/latency/${exp_name}_latency.json"

CMD=(python benchmarks/benchmark_latency.py
  --model "$model"
  --input-len "$input_len"
  --output-len "$output_len"
  --batch-size "$batch_size"
  --num-iters-warmup "$warmup_iters"
  --num-iters "$benchmark_iters"
  --output-json "$result_path"
)

echo "[INFO] Running latency benchmark: $exp_name"
echo "[INFO] Command: ${CMD[*]}"
"${CMD[@]}" > "$log_path" 2>&1

if [[ ! -s "$result_path" ]]; then
  echo "[ERROR] JSON result not created: $result_path"
  exit 1
else
  echo "[OK] $exp_name completed."
fi
