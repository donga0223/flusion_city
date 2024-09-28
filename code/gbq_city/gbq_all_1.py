import os
import argparse
import pathlib
import time
import datetime

# c("2023-10-01", "2023-11-19", "2024-01-07", "2024-02-18", "2024-03-24")

def submit_jobs(test_run):
    shdir = 'output/flusion_sh'
    pathlib.Path(shdir).mkdir(parents=True, exist_ok=True)
    logdir = 'output/flusion_logs'

    if test_run:
        start_date = datetime.date(2023, 9, 30)
        end_date = datetime.date(2023, 10, 7)
        ref_dates = []

        # Generate dates by incrementing 7 days at a time
        current_date = start_date
        while current_date <= end_date:
            ref_dates.append(current_date)  # Append the current Saturday to the list
            current_date += datetime.timedelta(days=7)  # Move to the next Saturday
        model_names=['gbq_qr', 'gbq_qr_nhsn_only', 'gbq_qr_nhsn_city_only']

    else :
        # Start and end dates
        start_date = datetime.date(2023, 9, 30)
        end_date = datetime.date(2024, 3, 30)
        ref_dates = []

        # Generate dates by incrementing 7 days at a time
        current_date = start_date
        while current_date <= end_date:
            ref_dates.append(current_date)  # Append the current Saturday to the list
            current_date += datetime.timedelta(days=7)  # Move to the next Saturday

        model_names=['gbq_qr', 'gbq_qr_nhsn_only', 'gbq_qr_nhsn_city_only']


    for model_name in model_names:
        for ref_date in ref_dates:
            if test_run:
                cmd ="source ~/.bashrc\n" \
                    "conda activate flusion\n" \
                    f'python code/gbq_city/gbq.py --ref_date {ref_date} --model_name {model_name} --short_run'
            else:
                cmd = "source ~/.bashrc\n" \
                    "conda activate flusion\n" \
                    f'python code/gbq_city/gbq.py --ref_date {ref_date} --model_name {model_name}'
            print(f"Launching {ref_date}_{model_name}")

            #cmd = f'source ~/.bashrc' \
            #    f'conda activate flusion' \
            #    f'python gbq.py --ref_date {ref_date} model_name {model_name}'
            print(f"Launching {ref_date}_{model_name}")

            sh_contents = f'#!/bin/bash\n' \
                        f'#SBATCH --job-name="{ref_date}_{model_name}"\n' \
                        f'#SBATCH --ntasks=1 \n' \
                        f'#SBATCH -c 1 # Number of Cores per Task\n' \
                        f'#SBATCH --nodes=1 # Requested number of nodes\n' \
                        f'#SBATCH --output="{logdir}/{ref_date}_{model_name}.out" \n' \
                        f'#SBATCH --error="{logdir}/{ref_date}_{model_name}.err" \n' \
                        f'#SBATCH --partition small # Partition\n' \
                        f'#SBATCH -A  A-ib1       # Allocation name\n' \
                        f'#SBATCH --time 2:00:00 # Job time limit\n' + cmd
            
            shfile = pathlib.Path(shdir) / f'{ref_date}_{model_name}.sh'
            with open(shfile, 'w') as f:
                f.write(sh_contents)
            
            os.system(f'sbatch {shfile}')
            

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Run estimation for simulation study, multiple combinations of sample size, theta, condition, and replicate index')
    
    parser.add_argument('--test_run',
                        action=argparse.BooleanOptionalAction,
			help='Flag to do a short run; overrides model-default num_bags to 10 and uses 3 quantile levels')
    parser.set_defaults(test_run=False)
    
    args = parser.parse_args()
    
    submit_jobs(**vars(args))
    
