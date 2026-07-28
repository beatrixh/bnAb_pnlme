import numpy as np
import pandas as pd
import stan
import pickle
import json
import sys

MODEL_DIR = sys.argv[1]
N_SAMPLES = sys.argv[2]
N_CHAINS = sys.argv[3]

print(N_CHAINS)

def main():
    global MODEL_DIR, N_CHAINS
    if MODEL_DIR[-1]!="/":
        MODEL_DIR += "/"

    with open(MODEL_DIR + "init_conditions.json", "r") as f:
        my_init = json.load(f)

    with open(MODEL_DIR + "my_data.json", "r") as f:
        my_data = json.load(f)

    with open(MODEL_DIR + "my_model.stan", "r") as f:
        my_model = f.read()

    my_model = my_model + "\n// force rebuild"
    posterior = stan.build(my_model, data=my_data, random_seed=1234)
    N_CHAINS = int(N_CHAINS)
    init_list = [my_init.copy() for _ in range(N_CHAINS)]
    fit = posterior.sample(num_chains=int(N_CHAINS), num_samples=int(N_SAMPLES), init=init_list)

    with open(MODEL_DIR + f'model_fit.pkl', 'wb') as f:
        pickle.dump(fit, f)

if __name__=="__main__":
    main()
