#!/bin/bash

# === Server Configuration ===
HOST="${BENCHMARK_HOST:-127.0.0.1}"
PORT="${BENCHMARK_PORT:-8000}"

# === Parse Arguments ===
IFS=' ' read -r -a MODELS <<< "${1:-facebook/opt-125m}"
IFS=' ' read -r -a RATES <<< "${2:-2}"
IFS=' ' read -r -a PROMPTS <<< "${3:-10}"
IFS=' ' read -r -a DATASETS <<< "${4:-random sharegpt}"

mkdir -p output/logs
mkdir -p output/results

# === Run each configuration ===
for model in "${MODELS[@]}"; do
  short_model=$(echo "$model" | tr '/' '_')

  for dataset in "${DATASETS[@]}"; do
    for rate in "${RATES[@]}"; do
      for num in "${PROMPTS[@]}"; do

        exp_name="${short_model}_${dataset}_${rate}rps_${num}p"
        log_path="output/logs/${exp_name}.log"
        result_path="output/results/${exp_name}.json"

        echo "[INFO] Running benchmark: $exp_name"

        if [[ "$dataset" == "sharegpt" && ! -f sharegpt.json ]]; then
          echo "[SKIP] sharegpt.json not found. Skipping $exp_name."
          continue
        fi
        cat > output/vllm_benchmark_meta.json <<EOF
        {
          "model": "$model",
          "dataset": "$dataset",
          "request_rate": "$rate",
          "num_prompts": "$num"
        }
EOF

        # === Wait for server to come up ===
        echo "[INFO] Checking if server is ready at $HOST:$PORT..."
        for attempt in {1..10}; do
          if curl --silent --fail "http://$HOST:$PORT/v1/completions" > /dev/null; then
            echo "[INFO] Server is ready."
            break
          else
            echo "[WAIT] Server not ready yet... retry $attempt"
            sleep 2
          fi
        done

        # Export for CSV logging (optional)
        export BENCHMARK_DATASET="$dataset"
        export BENCHMARK_RATE="$rate"
        export BENCHMARK_PROMPTS="$num"
        export BENCHMARK_MODEL="$model"

        # === Build benchmark command ===
        CMD=(python benchmarks/benchmark_serving.py
          --host "$HOST"
          --port "$PORT"
          --model "$model"
          --dataset-name "$dataset"
          --num-prompts "$num"
          --request-rate "$rate"
          --save-result
          --result-dir output/results
          --result-filename "$(basename "$result_path")"
        )

        if [[ "$dataset" == "sharegpt" ]]; then
          CMD+=(--dataset-path sharegpt.json)
        fi

        echo "[INFO] Running: ${CMD[*]}"
        "${CMD[@]}" > "$log_path" 2>&1

        if [[ ! -s "$result_path" ]]; then
          echo "[ERROR] No results for $exp_name."
        else
          echo "[OK] $exp_name completed."
        fi

        echo "-------------------------------------"

      done
    done
  done
done

echo "[DONE] All structured benchmark experiments completed."
