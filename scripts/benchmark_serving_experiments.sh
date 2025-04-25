#!/bin/bash

MODELS=("facebook/opt-125m")
RATES=(1)                          
PROMPTS=(1)
DATASETS=("random" "sharegpt")    
BURSTINESS_VALUES=(1.0)
MAX_CONCURRENCY_VALUES=(1)
IGNORE_EOS_VALUES=("False")

for model in "${MODELS[@]}"; do
  for rate in "${RATES[@]}"; do
    for num in "${PROMPTS[@]}"; do
      for dataset in "${DATASETS[@]}"; do
        for burst in "${BURSTINESS_VALUES[@]}"; do
          for mc in "${MAX_CONCURRENCY_VALUES[@]}"; do
            for eos in "${IGNORE_EOS_VALUES[@]}"; do
              ./scripts/serving_driver.sh "$model" "$rate" "$num" "$dataset" "$burst" "$mc" "$eos"
            done
          done
        done
      done
    done
  done
done
