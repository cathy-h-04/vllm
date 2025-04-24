import json
import csv
import sys
from pathlib import Path

def extract_metrics(json_file):
    with open(json_file, "r") as f:
        data = json.load(f)

    metrics = {
        "date": data.get("date"),
        "model_id": data.get("model_id"),
        "dataset_name": data.get("dataset_name"),
        "request_rate": data.get("request_rate"),
        "num_prompts": data.get("num_prompts"),
        "duration": data.get("duration"),
        "completed": data.get("completed"),
        "total_input_tokens": data.get("total_input_tokens"),
        "total_output_tokens": data.get("total_output_tokens"),
        "request_throughput": data.get("request_throughput"),
        "output_throughput": data.get("output_throughput"),
        "total_token_throughput": data.get("total_token_throughput"),
        "mean_ttft_ms": data.get("mean_ttft_ms"),
        "median_ttft_ms": data.get("median_ttft_ms"),
        "p99_ttft_ms": data.get("p99_ttft_ms"),
        "std_ttft_ms": data.get("std_ttft_ms"),
        "mean_tpot_ms": data.get("mean_tpot_ms"),
        "median_tpot_ms": data.get("median_tpot_ms"),
        "p99_tpot_ms": data.get("p99_tpot_ms"),
        "std_tpot_ms": data.get("std_tpot_ms"),
        "mean_itl_ms": data.get("mean_itl_ms"),
        "median_itl_ms": data.get("median_itl_ms"),
        "p99_itl_ms": data.get("p99_itl_ms"),
        "std_itl_ms": data.get("std_itl_ms"),
    }

    return metrics

def main():
    if len(sys.argv) < 2:
        print("Usage: python extract_serving_metrics.py <input_json>")
        sys.exit(1)

    input_path = Path(sys.argv[1])
    if not input_path.exists():
        print(f"Error: {input_path} does not exist.")
        sys.exit(1)

    metrics = extract_metrics(input_path)
    output_path = input_path.with_suffix(".csv")

    fieldnames = list(metrics.keys())
    with open(output_path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerow(metrics)

    print(f"[INFO] Extracted metrics saved to: {output_path}")

if __name__ == "__main__":
    main()
