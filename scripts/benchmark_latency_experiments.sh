#!/bin/bash

# === Read Positional Arguments ===
IFS=' ' read -r -a MODELS <<< "${1:-facebook/opt-125m}"
IFS=' ' read -r -a INPUT_LENS <<< "${2:-32}"
IFS=' ' read -r -a OUTPUT_LENS <<< "${3:-64}"

# === Optional Parameters (defaults) ===
export BATCH_SIZE="${BATCH_SIZE:-8}"
export NUM_ITERS_WARMUP="${NUM_ITERS_WARMUP:-5}"
export NUM_ITERS="${NUM_ITERS:-30}"

# === Output Directory ===
OUTPUT_DIR="${BENCHMARK_OUTPUT_DIR:-output}"
mkdir -p "$OUTPUT_DIR/logs/latency"
mkdir -p "$OUTPUT_DIR/results/latency"

# === Loop over Configs ===
for model in "${MODELS[@]}"; do
  short_model=$(echo "$model" | tr '/' '_')

  for in_len in "${INPUT_LENS[@]}"; do
    for out_len in "${OUTPUT_LENS[@]}"; do

      exp_name="${short_model}_in${in_len}_out${out_len}_bs${BATCH_SIZE}_n${NUM_ITERS}"
      log_path="$OUTPUT_DIR/logs/latency/${exp_name}_latency.log"
      result_path="$OUTPUT_DIR/results/latency/${exp_name}_latency.json"

      echo "[INFO] Running latency benchmark: $exp_name"

      # === Benchmark Metadata ===
      export BENCHMARK_TYPE="latency"
      export BENCHMARK_MODEL="$model"
      export BENCHMARK_INPUT_LEN="$in_len"
      export BENCHMARK_OUTPUT_LEN="$out_len"
      export BENCHMARK_DATASET="synthetic"

      if command -v nvidia-smi &> /dev/null; then
        export BENCHMARK_GPU_COUNT=$(nvidia-smi --query-gpu=name --format=csv,noheader | wc -l)
      else
        export BENCHMARK_GPU_COUNT=0
      fi

      export VLLM_STAT_LOG="output/vllm_stats_latency.csv"
      export VLLM_PROFILE_LOG="output/vllm_profile_latency.csv"
      export VLLM_DECODE_LOG="output/vllm_decode_latency.csv"

      # === Run Benchmark ===
      CMD=(python benchmarks/benchmark_latency.py
        --model "$model"
        --input-len "$in_len"
        --output-len "$out_len"
        --batch-size "$BATCH_SIZE"
        --num-iters-warmup "$NUM_ITERS_WARMUP"
        --num-iters "$NUM_ITERS"
        --output-json "$result_path"
      )

      echo "[INFO] Command: ${CMD[*]}"
      "${CMD[@]}" > "$log_path" 2>&1

      echo "[DONE] $exp_name completed."
      echo "-------------------------------------"

    done
  done
done

echo "[DONE] All latency benchmarks completed."