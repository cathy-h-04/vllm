#!/bin/bash

# === Read Positional Arguments ===
IFS=' ' read -r -a MODELS <<< "${1:-facebook/opt-125m}"
IFS=' ' read -r -a INPUT_LENS <<< "${2:-32}"
IFS=' ' read -r -a OUTPUT_LENS <<< "${3:-64}"
IFS=' ' read -r -a WARMUPS <<< "${4:-5}"
IFS=' ' read -r -a ITERS <<< "${5:-30}"
IFS=' ' read -r -a BATCH_SIZES <<< "${6:-8}"
IFS=' ' read -r -a GPU_COUNTS <<< "${7:-1}"

# === Output Directory ===
OUTPUT_DIR="${BENCHMARK_OUTPUT_DIR:-output}"
mkdir -p "$OUTPUT_DIR/logs/latency"
mkdir -p "$OUTPUT_DIR/results/latency"

# === Loop over Configs ===
for model in "${MODELS[@]}"; do
  short_model=$(echo "$model" | tr '/' '_')

  for in_len in "${INPUT_LENS[@]}"; do
    for out_len in "${OUTPUT_LENS[@]}"; do
      for warmup in "${WARMUPS[@]}"; do
        for iters in "${ITERS[@]}"; do
          for bs in "${BATCH_SIZES[@]}"; do
            for gpu_count in "${GPU_COUNTS[@]}"; do

              # === Limit visible GPUs to simulate GPU sweep ===
              export CUDA_VISIBLE_DEVICES=$(seq -s, 0 $((gpu_count - 1)))

              exp_name="${short_model}_in${in_len}_out${out_len}_bs${bs}_w${warmup}_n${iters}_g${gpu_count}"
              log_path="$OUTPUT_DIR/logs/latency/${exp_name}_latency.log"
              result_path="$OUTPUT_DIR/results/latency/${exp_name}_latency.json"

              echo "[INFO] Running latency benchmark: $exp_name"
              echo "[INFO] Using GPUs: $CUDA_VISIBLE_DEVICES"

              # === Benchmark Metadata ===
              export BENCHMARK_TYPE="latency"
              export BENCHMARK_MODEL="$model"
              export BENCHMARK_INPUT_LEN="$in_len"
              export BENCHMARK_OUTPUT_LEN="$out_len"
              export BENCHMARK_BATCH_SIZE="$bs"
              export BENCHMARK_GPU_COUNT="$gpu_count"
              export BENCHMARK_DATASET="synthetic"

              export VLLM_STAT_LOG="output/vllm_stats_latency.csv"
              export VLLM_PROFILE_LOG="output/vllm_profile_latency.csv"
              export VLLM_DECODE_LOG="output/vllm_decode_latency.csv"

              # === Run Benchmark ===
              CMD=(python benchmarks/benchmark_latency.py
                --model "$model"
                --input-len "$in_len"
                --output-len "$out_len"
                --batch-size "$bs"
                --num-iters-warmup "$warmup"
                --num-iters "$iters"
                --output-json "$result_path"
              )

              echo "[INFO] Command: ${CMD[*]}"
              "${CMD[@]}" > "$log_path" 2>&1

              echo "[DONE] $exp_name completed."
              echo "-------------------------------------"

            done
          done
        done
      done
    done
  done
done

echo "[DONE] All latency benchmarks completed."
