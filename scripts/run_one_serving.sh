#!/bin/bash
set -e

HOST="${BENCHMARK_HOST:-127.0.0.1}"
PORT="${BENCHMARK_PORT:-8000}"

model="$1"
rate="$2"
num="$3"
dataset="$4"
burstiness="$5"
max_concurrency="$6"
ignore_eos="$7"

short_model=$(echo "$model" | tr '/' '_')
exp_name="${short_model}_${dataset}_${rate}rps_${num}p_b${burstiness}_mc${max_concurrency}_eos${ignore_eos}"

OUTPUT_DIR="${BENCHMARK_OUTPUT_DIR:-output}"
mkdir -p "$OUTPUT_DIR/logs/serving"
mkdir -p "$OUTPUT_DIR/jsons/serving"

log_path="$OUTPUT_DIR/logs/serving/${exp_name}_serving.log"
result_path="$OUTPUT_DIR/jsons/serving/${exp_name}_serving.json"

dataset_path=""
case "$dataset" in
  sharegpt) dataset_path="sharegpt.json" ;;
  burstgpt) dataset_path="burstgpt.json" ;;
  sonnet) dataset_path="sonnet.json" ;;
  hf) dataset_path="$HF_DATASET_PATH" ;;
esac

if [[ -n "$dataset_path" && ! -f "$dataset_path" ]]; then
  echo "[SKIP] $dataset_path not found. Skipping $exp_name."
  exit 1
fi

export BENCHMARK_TYPE="serving"
export BENCHMARK_MODEL="$model"
export BENCHMARK_DATASET="$dataset"
export BENCHMARK_RATE="$rate"
export BENCHMARK_NUM_PROMPTS="$num"
export BENCHMARK_BURSTINESS="$burstiness"
export BENCHMARK_MAX_CONCURRENCY="$max_concurrency"
export BENCHMARK_IGNORE_EOS="$ignore_eos"
export VLLM_STAT_LOG="$OUTPUT_DIR/logs/serving/${exp_name}_stats.csv"
export VLLM_PROFILE_LOG="$OUTPUT_DIR/logs/serving/${exp_name}_profile.csv"
export VLLM_DECODE_LOG="$OUTPUT_DIR/logs/serving/${exp_name}_decode.csv"

if command -v nvidia-smi &> /dev/null; then
  export BENCHMARK_GPU_COUNT=$(nvidia-smi --query-gpu=name --format=csv,noheader | wc -l)
else
  export BENCHMARK_GPU_COUNT=0
fi

CMD=(python benchmarks/benchmark_serving.py
  --host "$HOST"
  --port "$PORT"
  --model "$model"
  --dataset-name "$dataset"
  --num-prompts "$num"
  --request-rate "$rate"
  --burstiness "$burstiness"
  --max-concurrency "$max_concurrency"
  --save-result
  --result-dir "$OUTPUT_DIR/jsons/serving"
  --result-filename "$(basename "$result_path")"
)

[[ "$ignore_eos" =~ [Tt]rue ]] && CMD+=(--ignore-eos)
[[ -n "$dataset_path" ]] && CMD+=(--dataset-path "$dataset_path")
[[ "$dataset" == "hf" && -n "$HF_SUBSET" ]] && CMD+=(--hf-subset "$HF_SUBSET")
[[ "$dataset" == "hf" && -n "$HF_SPLIT" ]] && CMD+=(--hf-split "$HF_SPLIT")
[[ "$dataset" == "hf" && -n "$HF_OUTPUT_LEN" ]] && CMD+=(--hf-output-len "$HF_OUTPUT_LEN")

echo "[INFO] Running benchmark: $exp_name"
echo "[INFO] Command: ${CMD[*]}"
"${CMD[@]}" > "$log_path" 2>&1

if [[ ! -s "$result_path" ]]; then
  echo "[ERROR] No results for $exp_name."
  exit 1
else
  echo "[OK] $exp_name completed."
fi
