# DafnyGym

DafnyGym is a benchmarking suite for evaluating the ability to generate single assertions.

## Set-Up

First build the docker image using:
```sh
docker buildx build -t dgym .
```

Then you can evaluate your predictions using the following command:
```
cat perfect_predictions.json | docker run -i dgym python3 run_eval.py | python3 analysis_results.py
```
where `perfect_predictions.json` is your prediction file.

***This script might take a while since it is verifying all the different case of DafnyGym.***