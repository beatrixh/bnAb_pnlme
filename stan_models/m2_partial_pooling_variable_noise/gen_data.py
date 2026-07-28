import numpy as np
import pandas as pd
import os
import json
import re

initial_conditions = {
    'm': 0.7,
    'c': 1.0,
    'sigma_m': 0.5,
    'sigma_c': 0.5,
    'sigma_U': 0.5,
    'sigma_alpha_m': 0.5,
    'sigma_alpha_c': 0.5,
    'sigma_alpha_U': 0.5,
    'sigma':0.84406193,
}

data_path = '/mnt/c/Users/bhaddock/repos/stan/nab_curves/input_data/single_clinical_all_mAbs_named_viruses_with_outliering_09_24_2025.csv'
df = pd.read_csv(data_path)

df.concentration *= 78125

data = []
log_concentration = []
for i, row in df[['virus_col','mab']].drop_duplicates().iterrows():
    sub = df.loc[(df.virus_col==row.virus_col) & (df.mab==row.mab)]
    data += [sub.pct_neutralization.tolist()]
    log_concentration += [np.log(sub.concentration).tolist()]

group_sizes = [int(len(i)) for i in data]

my_data = {
    'N':int(sum(group_sizes)),
    'K':len(data),
    'x_flat':np.concatenate([np.array(sub) for sub in log_concentration]).tolist(),
    'y_flat':np.concatenate([np.array(sub) for sub in data]).tolist(),
    'group_sizes':group_sizes,
}

if os.path.exists("my_data.json"):
    os.remove("my_data.json")
with open("my_data.json", "w") as f:
    json.dump(my_data, f, indent=2)


## save initial conditions -------------------------------------------------- ##
def extract_parameters_block(stan_code: str) -> str:
    """
    Extracts the text inside the 'parameters { ... }' block
    from a Stan program string.
    """
    # This pattern is lazy (non-greedy) and spans multiple lines
    match = re.search(r'parameters\s*\{(.*?)\}', stan_code, re.S)
    if match:
        return match.group(1).strip()
    else:
        return None

def parse_parameters_block(params_text: str) -> dict:
    """
    Parse a Stan 'parameters { ... }' block (without the braces)
    and return {parameter_name: type_string}.
    """
    param_dict = {}
    # Split into lines and clean
    lines = [line.strip() for line in params_text.splitlines() if line.strip() and not line.strip().startswith('//')]
    for line in lines:
        # get rid of lower bounds
        line = line.replace("<lower=0>","")
        # remove trailing comments
        line = re.sub(r'//.*', '', line).strip()
        if not line.endswith(';'):
            continue
        line = line.rstrip(';').strip()
        # pattern: type stuff name (optionally multiple names)
        # e.g. 'vector<lower=0>[K] m'
        m = re.match(r'([A-Za-z0-9_<>\[\]]+\s*(?:\[[^\]]*\])?)\s+([A-Za-z0-9_]+)', line)
        if m:
            type_str = m.group(1).strip()
            name = m.group(2).strip()
            param_dict[name] = type_str
    return param_dict

with open('my_model.stan', 'r') as f:
    my_model = f.read()

params_text = extract_parameters_block(my_model)
param_shapes = parse_parameters_block(params_text)

my_init = {}
for i in initial_conditions:
    if param_shapes[i] == 'real':
        my_init[i] = initial_conditions[i]
    elif param_shapes[i] == 'vector[K]':
        my_init[i] = [initial_conditions[i]]*my_data['K']
    else:
        print(f"don't recognize {param_shapes[i]}")

with open("init_conditions.json", "w") as f:
    json.dump(my_init, f, indent=2)
