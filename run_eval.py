import json
import sys
import yaml

from utils.dafny_utils import replace_method
from utils.logger_config import configure_logger
from utils.Method import Method
import os
import subprocess

DAFNY_CONFIG = "/DafnyGym/dafny_configs.yaml"
RESULTS_DIR = "/DafnyGym/results"
RESULT_FILE = "results.json"

def main():
    logger = configure_logger()
    # Read the whole file from stdin
    input_data = sys.stdin.read()
    predictions = json.loads(input_data)

    with open(DAFNY_CONFIG, 'r') as file:
        configs = yaml.safe_load(file)
    
    results = []

    for prediction in predictions:
        logger.info(f"Processing prediction {prediction['index']}")
        os.chdir(configs[prediction["benchmark_name"]]["location"])
        with open(prediction["method_filename"], "r") as file:
            file_content = file.read()
        replace_method(file_content, prediction["method_name"], prediction["method_content"])
        
        method_to_verify = Method(prediction["method_filename"], prediction["method_name"], index=prediction["index"])
        result = method_to_verify.run_verification(RESULTS_DIR, additionnal_args=configs[prediction["benchmark_name"]]["dafny_args"])

        result = subprocess.run(["git", "checkout", "."], capture_output=True, text=True)

        prediction_results = {
            "index": prediction["index"],
            "method_name": prediction["method_name"],
            "benchmark_name": prediction["benchmark_name"],
            "result": method_to_verify.verification_result,
            "error_message": method_to_verify.error_message
        }
        results.append(prediction_results)

    with open(os.path.join(RESULTS_DIR, RESULT_FILE), "w") as file:
        json.dump(results, file, indent=4)
        print(json.dumps(results, indent=4))


if __name__ == "__main__":
    main()