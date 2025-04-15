#!/bin/bash

# === vLLM CPU performance setup (Apple M2 optimized) ===
export VLLM_CPU_KVCACHE_SPACE=6
export VLLM_CPU_OMP_THREADS_BIND=0-7
export VLLM_CPU_MOE_PREPACK=0
export VLLM_WORKER_MULTIPROC_METHOD=spawn

# === Accept optional --log-path=... argument ===
LOG_PATH="output/vllm_log.csv"

for arg in "$@"; do
  if [[ $arg == --log-path=* ]]; then
    LOG_PATH="${arg#*=}"
  fi
done

export VLLM_LOG_PATH="$LOG_PATH"

# Create output directory if needed
mkdir -p "$(dirname "$LOG_PATH")"

# === Run passed command ===
exec "$@"