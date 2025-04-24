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
              case "$dataset" in
                sharegpt) dataset_path="sharegpt.json" ;;
                burstgpt) dataset_path="burstgpt.json" ;;
                sonnet) dataset_path="sonnet.json" ;;
                hf) dataset_path="$HF_DATASET_PATH" ;;
              esac

              if [[ -n "$dataset_path" && ! -f "$dataset_path" ]]; then
                echo "[SKIP] $dataset_path not found. Skipping $exp_name."
                continue
              fi

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
              export VLLM_STAT_LOG="$OUTPUT_DIR/vllm_stats_serving.csv"
              export VLLM_PROFILE_LOG="$OUTPUT_DIR/vllm_profile_serving.csv"
              export VLLM_DECODE_LOG="$OUTPUT_DIR/vllm_decode_serving.csv"

              if command -v nvidia-smi &> /dev/null; then
                export BENCHMARK_GPU_COUNT=$(nvidia-smi --query-gpu=name --format=csv,noheader | wc -l)
              else
                export BENCHMARK_GPU_COUNT=0
              fi

              # Track line counts BEFORE experiment
              stat_lines_before=0
              profile_lines_before=0
              decode_lines_before=0
              [[ -f "$OUTPUT_DIR/vllm_stats_serving.csv" ]] && stat_lines_before=$(wc -l < "$OUTPUT_DIR/vllm_stats_serving.csv")
              [[ -f "$OUTPUT_DIR/vllm_profile_serving.csv" ]] && profile_lines_before=$(wc -l < "$OUTPUT_DIR/vllm_profile_serving.csv")
              [[ -f "$OUTPUT_DIR/vllm_decode_serving.csv" ]] && decode_lines_before=$(wc -l < "$OUTPUT_DIR/vllm_decode_serving.csv")

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

              [[ "$ignore_eos" =~ [Tt]rue ]] && CMD+=(--ignore-eos)
              [[ -n "$dataset_path" ]] && CMD+=(--dataset-path "$dataset_path")
              [[ "$dataset" == "hf" && -n "$HF_SUBSET" ]] && CMD+=(--hf-subset "$HF_SUBSET")
              [[ "$dataset" == "hf" && -n "$HF_SPLIT" ]] && CMD+=(--hf-split "$HF_SPLIT")
              [[ "$dataset" == "hf" && -n "$HF_OUTPUT_LEN" ]] && CMD+=(--hf-output-len "$HF_OUTPUT_LEN")

              echo "[INFO] Running: ${CMD[*]}"
              "${CMD[@]}" > "$log_path" 2>&1

              # Annotate newly added rows in each CSV
             # Annotate newly added rows in each CSV
              for file in stats profile decode; do
                log_file="$OUTPUT_DIR/vllm_${file}_serving.csv"
                case "$file" in
                  stats)
                    line_before=$stat_lines_before
                    base_header="step,prefill_time,decode_time,e2e_time,prompt_tokens,gen_tokens,total_requests,num_tokens_iter,avg_ttft,avg_token_latency,queue_time,model_forward_time,throughput_tokens_per_s,data_parallel,pipeline_parallel,tensor_parallel"
                    ;;
                  profile)
                    line_before=$profile_lines_before
                    base_header="step_id,profiling_time_ms,cpu_profile_pct,mem_profile_gb,data_parallel,pipeline_parallel,tensor_parallel"
                    ;;
                  decode)
                    line_before=$decode_lines_before
                    base_header="step_id,decode_time_ms,cpu_decode_pct,mem_decode_gb,data_parallel,pipeline_parallel,tensor_parallel" 
                    ;;
                esac

                meta_header="exp_name,model,dataset,rate,num_prompts,burstiness,max_concurrency,ignore_eos"
                full_header="$base_header,$meta_header"

                if [[ ! -f "$log_file" ]]; then
                  continue
                fi

                line_after=$(wc -l < "$log_file")
                if (( line_after > line_before )); then
                  tmp_file=$(mktemp)

                  if (( line_before > 0 )); then
                    head -n "$line_before" "$log_file" > "$tmp_file"
                  else
                    first_col=$(head -n 1 "$log_file" | cut -d',' -f1)
                    if [[ "$first_col" == "step" || "$first_col" == "step_id" ]]; then
                      echo "$full_header" > "$tmp_file"
                      tail -n +2 "$log_file" | awk -F',' -v OFS=',' \
                        -v name="$exp_name" -v model="$model" -v dataset="$dataset" -v rate="$rate" \
                        -v num="$num" -v burst="$burstiness" -v mc="$max_concurrency" -v eos="$ignore_eos" \
                        '$1 != "step" && $1 != "step_id" {
                          gsub(/\r/, ""); gsub(/\n/, "\\n");
                          print $0, name, model, dataset, rate, num, burst, mc, eos
                        }' >> "$tmp_file"
                      mv "$tmp_file" "$log_file"
                      continue
                    else
                      echo "$full_header" > "$tmp_file"
                    fi
                  fi

                  tail -n +"$((line_before + 1))" "$log_file" | awk -F',' -v OFS=',' \
                    -v name="$exp_name" -v model="$model" -v dataset="$dataset" -v rate="$rate" \
                    -v num="$num" -v burst="$burstiness" -v mc="$max_concurrency" -v eos="$ignore_eos" \
                    '$1 != "step" && $1 != "step_id" {
                      gsub(/\r/, ""); gsub(/\n/, "\\n");
                      print $0, name, model, dataset, rate, num, burst, mc, eos
                    }' >> "$tmp_file"

                  mv "$tmp_file" "$log_file"
                fi
              done

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
    done
  done
done

echo "[DONE] All structured benchmark experiments completed."
