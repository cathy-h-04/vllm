#!/bin/bash

MODELS=("facebook/opt-125m")
DATASETS=("hf" "sharegpt")
INPUT_LENS=(32 64)
OUTPUT_LENS=(64)
NUM_PROMPTS=(10)
BACKENDS=("vllm")
NS=(1)
GPU_COUNTS=(1)
HF_DATASET_PATH="likaixin/InstructCoder"
SHAREGPT_JSON_PATH="sharegpt.json"

OUTPUT_DIR="${BENCHMARK_OUTPUT_DIR:-output}"
mkdir -p "$OUTPUT_DIR/csvs/throughput"

for model in "${MODELS[@]}"; do
  for dataset in "${DATASETS[@]}"; do
    for in_len in "${INPUT_LENS[@]}"; do
      for out_len in "${OUTPUT_LENS[@]}"; do
        for num in "${NUM_PROMPTS[@]}"; do
          for backend in "${BACKENDS[@]}"; do
            for n in "${NS[@]}"; do
              for gpu in "${GPU_COUNTS[@]}"; do

                export CUDA_VISIBLE_DEVICES=$(seq -s, 0 $((gpu - 1)))

                export BENCHMARK_TYPE="throughput"
                export BENCHMARK_MODEL="$model"
                export BENCHMARK_DATASET="$dataset"
                export BENCHMARK_INPUT_LEN="$in_len"
                export BENCHMARK_OUTPUT_LEN="$out_len"
                export BENCHMARK_NUM_PROMPTS="$num"
                export BENCHMARK_GPU_COUNT="$gpu"
                export BENCHMARK_BACKEND="$backend"
                export BENCHMARK_N="$n"

                export BENCHMARK_DISABLE_DETOKENIZE="False"
                export BENCHMARK_DISABLE_MP="False"
                export BENCHMARK_ASYNC_ENGINE="False"

                dataset_path=""
                if [[ "$dataset" == "hf" ]]; then
                  export HF_SUBSET=""
                  export HF_SPLIT="train"
                  dataset_path="$HF_DATASET_PATH"
                elif [[ "$dataset" == "sharegpt" ]]; then
                  dataset_path="$SHAREGPT_JSON_PATH"
                fi

                short_model=$(echo "$model" | tr '/' '_')
                exp_name="${short_model}_${dataset}_in${in_len}_out${out_len}_n${n}_p${num}_${backend}_g${gpu}"

                export VLLM_STAT_LOG="$OUTPUT_DIR/csvs/throughput/${exp_name}_stats.csv"
                export VLLM_PROFILE_LOG="$OUTPUT_DIR/csvs/throughput/${exp_name}_profile.csv"
                export VLLM_DECODE_LOG="$OUTPUT_DIR/csvs/throughput/${exp_name}_decode.csv"

                ./scripts/run_one_throughput.sh "$model" "$dataset" "$in_len" "$out_len" "$num" "$backend" "$n" "$dataset_path"

              done
            done
          done
        done
      done
    done
  done
done
