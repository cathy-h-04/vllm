#!/bin/bash
set -e

model="$1"
dataset="$2"
input_len="$3"
output_len="$4"
num_prompts="$5"
backend="$6"
n="$7"

short_model=$(echo "$model" | tr '/' '_')
exp_name="${short_model}_${dataset}_in${input_len}_out${output_len}_n${n}_p${num_prompts}_${backend}_g${BENCHMARK_GPU_COUNT}"

OUTPUT_DIR="${BENCHMARK_OUTPUT_DIR:-output}"
mkdir -p "$OUTPUT_DIR/logs/throughput"
mkdir -p "$OUTPUT_DIR/jsons/throughput"

log_path="$OUTPUT_DIR/logs/throughput/${exp_name}_throughput.log"
result_path="$OUTPUT_DIR/jsons/throughput/${exp_name}_throughput.json"

CMD=(python benchmarks/benchmark_throughput.py
  --model "$model"
  --dataset-name "$dataset"
  --input-len "$input_len"
  --output-len "$output_len"
  --num-prompts "$num_prompts"
  --backend "$backend"
  --n "$n"
  --output-json "$result_path"
)

[[ "$BENCHMARK_DISABLE_DETOKENIZE" == "True" ]] && CMD+=(--disable-detokenize)
[[ "$BENCHMARK_ASYNC_ENGINE" == "True" ]] && CMD+=(--async-engine)
[[ "$BENCHMARK_DISABLE_MP" == "True" ]] && CMD+=(--disable-frontend-multiprocessing)

echo "[INFO] Running throughput benchmark: $exp_name"
echo "[INFO] Command: ${CMD[*]}"
"${CMD[@]}" > "$log_path" 2>&1

if [[ ! -s "$result_path" ]]; then
  echo "[ERROR] No results written to $result_path"
  exit 1
else
  echo "[OK] $exp_name completed."
fi
