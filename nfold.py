import argparse
import os
import  pandas as pd
from sklearn.model_selection import KFold


# Define the argument parser
parser = argparse.ArgumentParser(description='Process some dataset.')
parser.add_argument('--dataset', type=str, required=True, help='Name of the dataset')
parser.add_argument('--k', type=int, required=False, help='number of splits')

# Parse the arguments
args = parser.parse_args()

# Use the dataset argument
dataset = args.dataset

benchmarks = {}
df = pd.read_csv(f"./{dataset}.csv")

# remove duplicates
df.drop_duplicates(subset=["Original Method", "Assertion"], inplace=True)

if args.k is None:
    k = len(df)
else:
    k = args.k

kf = KFold(n_splits=k)

training_sets = []
testing_sets = []

for train_index, test_index in kf.split(df):
    training = df.iloc[train_index]
    testing = df.iloc[test_index]
    training_sets.append(training)
    testing_sets.append(testing)
if not os.path.exists(f"./tmp_{dataset}"):
    os.makedirs(f"./tmp_{dataset}")
for i, (training, testing) in enumerate(zip(training_sets, testing_sets)):
    training_file = f"./tmp_{dataset}/training_{dataset}_k{k}_{i}.csv"
    testing_file = f"./tmp_{dataset}/testing_{dataset}_k{k}_{i}.csv"
    training.to_csv(training_file, index=False)
    testing.to_csv(testing_file, index=False)
