#!/bin/bash

# === Server Configuration ===
HOST="${BENCHMARK_HOST:-127.0.0.1}"
PORT="${BENCHMARK_PORT:-8000}"

# === Parse Arguments ===
IFS=' ' read -r -a MODELS <<< "${1:-facebook/opt-125m}"
IFS=' ' read -r -a RATES <<< "${2:-2}"
IFS=' ' read -r -a PROMPTS <<< "${3:-10}"
IFS=' ' read -r -a DATASETS <<< "${4:-random sharegpt}"
IFS=' ' read -r -a BURSTINESS_VALUES <<< "${5:-1.0}"
IFS=' ' read -r -a MAX_CONCURRENCY_VALUES <<< "${6:-10}"
IFS=' ' read -r -a IGNORE_EOS_VALUES <<< "${7:-False}"

OUTPUT_DIR="${BENCHMARK_OUTPUT_DIR:-output}"
mkdir -p "$OUTPUT_DIR/logs/serving"
mkdir -p "$OUTPUT_DIR/results/serving"

# === Run each configuration ===
for model in "${MODELS[@]}"; do
  short_model=$(echo "$model" | tr '/' '_')

  for burstiness in "${BURSTINESS_VALUES[@]}"; do
    for max_concurrency in "${MAX_CONCURRENCY_VALUES[@]}"; do
      for ignore_eos in "${IGNORE_EOS_VALUES[@]}"; do
        for dataset in "${DATASETS[@]}"; do
          for rate in "${RATES[@]}"; do
            for num in "${PROMPTS[@]}"; do

              exp_name="${short_model}_${dataset}_${rate}rps_${num}p_b${burstiness}_mc${max_concurrency}_eos${ignore_eos}"
              log_path="$OUTPUT_DIR/logs/serving/${exp_name}_serving.log"
              result_path="$OUTPUT_DIR/results/serving/${exp_name}_serving.json"

              echo "[INFO] Running benchmark: $exp_name"

              dataset_path=""
              if [[ "$dataset" == "sharegpt" ]]; then
                dataset_path="sharegpt.json"
              elif [[ "$dataset" == "burstgpt" ]]; then
                dataset_path="burstgpt.json"
              elif [[ "$dataset" == "sonnet" ]]; then
                dataset_path="sonnet.json"
              elif [[ "$dataset" == "hf" ]]; then
                dataset_path="${HF_DATASET_PATH:-}"
              fi

              if [[ -n "$dataset_path" && ! -f "$dataset_path" ]]; then
                echo "[SKIP] $dataset_path not found. Skipping $exp_name."
                continue
              fi

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

              export BENCHMARK_TYPE="serving"
              export BENCHMARK_MODEL="$model"
              export BENCHMARK_DATASET="$dataset"
              export BENCHMARK_RATE="$rate"
              export BENCHMARK_NUM_PROMPTS="$num"
              export BENCHMARK_BURSTINESS="$burstiness"
              export BENCHMARK_MAX_CONCURRENCY="$max_concurrency"
              export BENCHMARK_IGNORE_EOS="$ignore_eos"
              export BENCHMARK_GPU_COUNT=0
              export VLLM_STAT_LOG="$OUTPUT_DIR/vllm_stats_serving.csv"
              export VLLM_PROFILE_LOG="$OUTPUT_DIR/vllm_profile_serving.csv"
              export VLLM_DECODE_LOG="$OUTPUT_DIR/vllm_decode_serving.csv"

              for file in stats profile decode; do
                log_file="$OUTPUT_DIR/vllm_${file}_serving.csv"
                if [[ -f "$log_file" ]]; then
                  eval "pre_${file}_lines=\$(wc -l < \"$log_file\")"
                else
                  eval "pre_${file}_lines=0"
                fi
              done

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
                --result-dir "$OUTPUT_DIR/results/serving"
                --result-filename "$(basename "$result_path")"
              )

              if [[ "$ignore_eos" == "True" || "$ignore_eos" == "true" ]]; then
                CMD+=(--ignore-eos)
              fi

              if [[ -n "$dataset_path" ]]; then
                CMD+=(--dataset-path "$dataset_path")
              fi

              [[ "$dataset" == "hf" && -n "$HF_SUBSET" ]] && CMD+=(--hf-subset "$HF_SUBSET")
              [[ "$dataset" == "hf" && -n "$HF_SPLIT" ]] && CMD+=(--hf-split "$HF_SPLIT")
              [[ "$dataset" == "hf" && -n "$HF_OUTPUT_LEN" ]] && CMD+=(--hf-output-len "$HF_OUTPUT_LEN")

              echo "[INFO] Running: ${CMD[*]}"
              "${CMD[@]}" > "$log_path" 2>&1

              # === Append metadata to new rows ===
              for file in stats profile decode; do
                log_file="$OUTPUT_DIR/vllm_${file}_serving.csv"
                tmp_file=$(mktemp)
                enriched_header="exp_name,model,dataset,request_rate,num_prompts,burstiness,max_concurrency,ignore_eos"
                lines_before_var="pre_${file}_lines"
                lines_before=$(eval "echo \${$lines_before_var}")
                total_lines=$(wc -l < "$log_file")
                new_lines=$((total_lines - lines_before))

                # Save header
                header=$(head -n 1 "$log_file")

                # Copy old part as-is
                if (( lines_before > 1 )); then
                  head -n "$lines_before" "$log_file" > "$tmp_file"
                else
                  echo "$header" > "$tmp_file"
                fi

                # Append new rows with metadata
                tail -n "$new_lines" "$log_file" | awk -v OFS=',' \
                  -v name="$exp_name" -v model="$model" -v dataset="$dataset" \
                  -v rate="$rate" -v num="$num" -v burst="$burstiness" \
                  -v mc="$max_concurrency" -v eos="$ignore_eos" \
                  'NR==1 { print $0,"exp_name","model","dataset","request_rate","num_prompts","burstiness","max_concurrency","ignore_eos"; next }
                  { print $0, name, model, dataset, rate, num, burst, mc, eos }' >> "$tmp_file"

                mv "$tmp_file" "$log_file"
              done

              echo "-------------------------------------"

            done
          done
        done
      done
    done
  done
done

echo "[DONE] All structured benchmark experiments completed."
