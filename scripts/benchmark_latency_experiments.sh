#!/bin/bash

MODELS=("facebook/opt-125m")
INPUT_LENS=(32)
OUTPUT_LENS=(64)
WARMUPS=(1 2)
ITERS=(3)
BATCH_SIZES=(1)
GPU_COUNTS=(1)

OUTPUT_DIR="${BENCHMARK_OUTPUT_DIR:-output}"
mkdir -p "$OUTPUT_DIR/csvs/latency"

for model in "${MODELS[@]}"; do
  for in_len in "${INPUT_LENS[@]}"; do
    for out_len in "${OUTPUT_LENS[@]}"; do
      for warmup in "${WARMUPS[@]}"; do
        for iters in "${ITERS[@]}"; do
          for bs in "${BATCH_SIZES[@]}"; do
            for gpu in "${GPU_COUNTS[@]}"; do

              export CUDA_VISIBLE_DEVICES=$(seq -s, 0 $((gpu - 1)))

              export BENCHMARK_TYPE="latency"
              export BENCHMARK_MODEL="$model"
              export BENCHMARK_INPUT_LEN="$in_len"
              export BENCHMARK_OUTPUT_LEN="$out_len"
              export BENCHMARK_BATCH_SIZE="$bs"
              export BENCHMARK_GPU_COUNT="$gpu"
              export BENCHMARK_DATASET="synthetic"

              short_model=$(echo "$model" | tr '/' '_')
              exp_name="${short_model}_in${in_len}_out${out_len}_bs${bs}_w${warmup}_n${iters}_g${gpu}"

              export VLLM_STAT_LOG="$OUTPUT_DIR/csvs/latency/${exp_name}_stats.csv"
              export VLLM_PROFILE_LOG="$OUTPUT_DIR/csvs/latency/${exp_name}_profile.csv"
              export VLLM_DECODE_LOG="$OUTPUT_DIR/csvs/latency/${exp_name}_decode.csv"

              ./scripts/run_one_latency.sh "$model" "$in_len" "$out_len" "$bs" "$warmup" "$iters"

            done
          done
        done
      done
    done
  done
done
