# DafnyGym

DafnyGym is a benchmarking suite for evaluating the ability to generate single assertions.

Our benchmark is also available on [HuggingFace](https://huggingface.co/datasets/emugnier/DafnyGym).

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

## Content

Our benchmark contains assertions from these 3 repositories:
- [Cedar](https://github.com/cedar-policy/cedar-spec) commit 2b9a0cbd
- [Dafny-VMC](https://github.com/dafny-lang/Dafny-VMC)
commit b79a4c7
- [Libraries](https://github.com/dafny-lang/libraries)
commit ae8708c

## Citation

```
@misc{mugnier2024laurelgeneratingdafnyassertions,
      title={Laurel: Generating Dafny Assertions Using Large Language Models},
      author={Eric Mugnier and Emmanuel Anaya Gonzalez and Ranjit Jhala and Nadia Polikarpova and Yuanyuan Zhou},
      year={2024},
      eprint={2405.16792},
      archivePrefix={arXiv},
      primaryClass={cs.LO},
      url={https://arxiv.org/abs/2405.16792},
}
```