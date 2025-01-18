import json
import sys

def calculate_accuracy(results):
    correct_count = sum(1 for result in results if result["result"] == "Correct")
    total_count = len(results)
    accuracy = correct_count / total_count if total_count > 0 else 0
    return accuracy

def main():
    # Read the whole file from stdin
    input_data = sys.stdin.read()
    print(input_data)
    results = json.loads(input_data)
    
    accuracy = calculate_accuracy(results)
    print(f"Accuracy: {accuracy:.2%}")

if __name__ == "__main__":
    main()