from vllm import LLM, SamplingParams

def main():
    # Load the model
    llm = LLM(model="facebook/opt-125m", disable_log_stats=False)

    # Batch of prompts — increase batch size to ensure multi-step execution
    prompts = [
        "The history of artificial intelligence is",
        "Once upon a time in a land far away, there lived",
        "The discovery of penicillin changed",
        "Quantum computing is expected to",
        "In ancient Rome, the role of a senator was",
        "The mitochondria is the powerhouse of the",
        "Machine learning models are trained using",
        "During the Industrial Revolution, factories",
        "The capital of France is",
        "Photosynthesis is a process by which plants",
        "The theory of relativity explains how",
        "The Cold War was a period of",
        "The purpose of education is to",
        "The Great Wall of China was built to",
        "Cloud computing allows users to",
        "The quick brown fox jumps over the lazy dog"
    ]

    # Make the model generate longer outputs
    sampling_params = SamplingParams(
        max_tokens=64,
        temperature=0.7,
        top_p=0.9
    )

    # Generate outputs
    outputs = llm.generate(prompts, sampling_params)

    # Print results
    for output in outputs:
        print(f"Prompt: {output.prompt!r}")
        print(f"Output: {output.outputs[0].text!r}")
        print("-" * 50)

if __name__ == "__main__":
    main()
