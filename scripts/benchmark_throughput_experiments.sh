#!/bin/bash

IFS=' ' read -r -a MODELS <<< "${1:-facebook/opt-125m}"
IFS=' ' read -r -a BATCH_SIZES <<< "${2:-1 2}"
IFS=' ' read -r -a SEQ_LENS <<< "${3:-32 64}"

mkdir -p output/logs
mkdir -p output/results

for model in "${MODELS[@]}"; do
  short_model=$(echo "$model" | tr '/' '_')

  for bs in "${BATCH_SIZES[@]}"; do
    for len in "${SEQ_LENS[@]}"; do

      exp_name="${short_model}_bs${bs}_len${len}"
      log_path="output/logs/${exp_name}_throughput.log"
      result_path="output/results/${exp_name}_throughput.json"

      export BENCHMARK_TYPE="throughput"
      export BENCHMARK_MODEL="$model"
      export BENCHMARK_BATCH="$bs"
      export BENCHMARK_SEQ_LEN="$len"

      export VLLM_STAT_LOG="output/vllm_stats_throughput.csv"
      export VLLM_PROFILE_LOG="output/vllm_profile_throughput.csv"
      export VLLM_DECODE_LOG="output/vllm_decode_throughput.csv"

      CMD=(python benchmarks/benchmark_throughput.py
        --model "$model"
        --num-prompts "$bs"
        --input-len "$len"
        --output-len "$len"
       --output-json "$result_path"
      )

      echo "[INFO] Running: ${CMD[*]}"
      "${CMD[@]}" > "$log_path" 2>&1

      echo "[DONE] $exp_name completed."
      echo "-------------------------------------"

    done
  done
done

echo "[DONE] All throughput benchmarks completed."
