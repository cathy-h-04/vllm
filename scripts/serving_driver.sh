#!/bin/bash
set -e
pkill -f "vllm.entrypoints.openai.api_server" 2>/dev/null || true

MODEL="$1"
RATE="$2"
NUM="$3"
DATASET="$4"
BURSTINESS="$5"
MAX_CONCURRENCY="$6"
IGNORE_EOS="$7"
HF_DATASET_PATH="$8"  # Optional


# Export metadata
export BENCHMARK_TYPE="serving"
export BENCHMARK_MODEL="$MODEL"
export BENCHMARK_RATE="$RATE"
export BENCHMARK_NUM_PROMPTS="$NUM"
export BENCHMARK_DATASET="$DATASET"
export BENCHMARK_BURSTINESS="$BURSTINESS"
export BENCHMARK_MAX_CONCURRENCY="$MAX_CONCURRENCY"
export BENCHMARK_IGNORE_EOS="$IGNORE_EOS"
export BENCHMARK_GPU_COUNT=$(nvidia-smi --query-gpu=name --format=csv,noheader | wc -l)

# Optional HF args
export HF_SUBSET=""
export HF_SPLIT="train"
export HF_OUTPUT_LEN=128

EXP_NAME="${MODEL//\//_}_${DATASET}_${RATE}rps_${NUM}p_b${BURSTINESS}_mc${MAX_CONCURRENCY}_eos${IGNORE_EOS}"

echo "[SERVER DEBUG] Dataset name: $DATASET"
echo "[SERVER DEBUG] Dataset path: $HF_DATASET_PATH"
echo "[SERVER DEBUG] Final EXP_NAME: $EXP_NAME"


OUTPUT_DIR="${BENCHMARK_OUTPUT_DIR:-output}"
mkdir -p "$OUTPUT_DIR/csvs/serving"

export VLLM_STAT_LOG="$OUTPUT_DIR/csvs/serving/${EXP_NAME}_stats.csv"
export VLLM_PROFILE_LOG="$OUTPUT_DIR/csvs/serving/${EXP_NAME}_profile.csv"
export VLLM_DECODE_LOG="$OUTPUT_DIR/csvs/serving/${EXP_NAME}_decode.csv"

# Start server
echo "[INFO] Starting server for $EXP_NAME"
python -m vllm.entrypoints.openai.api_server \
  --model "$MODEL" \
  --port 8000 \
  --disable-log-requests \
  --trust-remote-code &

SERVER_PID=$!
sleep 10

# Run experiment with optional dataset path
./scripts/run_one_serving.sh "$MODEL" "$RATE" "$NUM" "$DATASET" "$BURSTINESS" "$MAX_CONCURRENCY" "$IGNORE_EOS" "$HF_DATASET_PATH"

kill $SERVER_PID
wait $SERVER_PID 2>/dev/null || true
