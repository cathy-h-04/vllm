#!/bin/bash

MODELS=("facebook/opt-125m")
RATES=(1)
PROMPTS=(1)
DATASETS=("hf" "sharegpt")
BURSTINESS_VALUES=(1.0)
MAX_CONCURRENCY_VALUES=(1)
IGNORE_EOS_VALUES=("False")

HF_DATASET_PATH="likaixin/InstructCoder"  # default for hf
SHAREGPT_JSON_PATH="sharegpt.json"        # must exist locally

for model in "${MODELS[@]}"; do
  for rate in "${RATES[@]}"; do
    for num in "${PROMPTS[@]}"; do
      for dataset in "${DATASETS[@]}"; do
        for burst in "${BURSTINESS_VALUES[@]}"; do
          for mc in "${MAX_CONCURRENCY_VALUES[@]}"; do
            for eos in "${IGNORE_EOS_VALUES[@]}"; do

              dataset_arg=""
              if [[ "$dataset" == "hf" ]]; then
                dataset_arg="$HF_DATASET_PATH"
              elif [[ "$dataset" == "sharegpt" ]]; then
                dataset_arg="$SHAREGPT_JSON_PATH"
              fi

              ./scripts/serving_driver.sh "$model" "$rate" "$num" "$dataset" "$burst" "$mc" "$eos" "$dataset_arg"

            done
          done
        done
      done
    done
  done
done
