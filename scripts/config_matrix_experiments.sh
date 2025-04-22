#!/bin/bash

# === Parse Arguments (space-separated) ===
IFS=' ' read -r -a MODELS <<< "${1:-facebook/opt-125m}"
IFS=' ' read -r -a RATES <<< "${2:-2 5 10}"
IFS=' ' read -r -a PROMPTS <<< "${3:-10 50 100}"
DATASETS=("random" "sharegpt")

# === Output Setup ===
mkdir -p output/logs
mkdir -p output/results

# === Start vLLM API Server ===
MODEL_SERVER=${MODELS[0]}
echo "[INFO] Starting vLLM API server with: $MODEL_SERVER"
VLLM_LOG_PATH=output/vllm_stats_experiments.csv \
VLLM_PROFILE_LOG=output/vllm_profile_experiments.csv \
VLLM_DECODE_LOG=output/vllm_decode_experiments.csv \
python -m vllm.entrypoints.openai.api_server \
  --model "$MODEL_SERVER" \
  --device auto \
  --port 8000 > output/logs/server.log 2>&1 &

# === Wait Until Server is Ready ===
echo "[INFO] Waiting for API server to respond..."
for i in {1..60}; do
  if curl -s http://127.0.0.1:8000/v1/completions > /dev/null; then
    echo "[INFO] API server is ready!"
    break
  else
    echo "[WAIT] Server not ready yet... retry $i"
    sleep 2
  fi
done

# === Run All Experiments ===
for model in "${MODELS[@]}"; do
  short_model=$(echo "$model" | tr '/' '_')
  for dataset in "${DATASETS[@]}"; do
    for rate in "${RATES[@]}"; do
      for num in "${PROMPTS[@]}"; do

        exp_name="${short_model}_${dataset}_${rate}rps_${num}p"
        log_path="output/logs/${exp_name}.log"
        result_path="output/results/${exp_name}.json"

        echo "[INFO] Running: $exp_name"

        # Skip sharegpt if dataset file is missing
        if [[ "$dataset" == "sharegpt" && ! -f sharegpt.json ]]; then
          echo "[SKIP] Missing sharegpt.json. Skipping $exp_name."
          continue
        fi

        # Build command
        CMD=(python vllm/benchmarks/serve.py
          --model "$model"
          --dataset-name "$dataset"
          --num-prompts "$num"
          --request-rate "$rate"
          --host 127.0.0.1
          --port 8000
          --endpoint /v1/completions
          --save-result
          --result-dir output/results
          --result-filename "${exp_name}.json"
        )

        # Conditionally add --dataset-path for sharegpt
        if [[ "$dataset" == "sharegpt" ]]; then
          CMD+=(--dataset-path sharegpt.json)
        fi

        # Run and capture output
        "${CMD[@]}" > "$log_path" 2>&1

        # Check result file
        if [[ ! -s "$result_path" ]]; then
          echo "[ERROR] No result output for $exp_name."
        elif ! grep -q "Successful requests:" "$log_path"; then
          echo "[ERROR] No successful requests logged for $exp_name. Check $log_path"
        else
          echo "[OK] $exp_name completed."
        fi

      done
    done
  done
done

# === Stop Server ===
echo "[INFO] Stopping vLLM server..."
pkill -f api_server
echo "[DONE] All configuration matrix experiments completed."
