#!/bin/bash
#SBATCH --job-name="2023-10-07_gbq_qr"
#SBATCH --ntasks=1 
#SBATCH -c 1 # Number of Cores per Task
#SBATCH --nodes=1 # Requested number of nodes
#SBATCH --output="output/arhdfa_logs/2023-10-07_gbq_qr.out" 
#SBATCH --error="output/arhdfa_logs/2023-10-07_gbq_qr.err" 
#SBATCH --partition small # Partition
#SBATCH --time 2:00:00 # Job time limit
conda activate flusionpython gbq.py --ref_date 2023-10-07 --model_name gbq_qr --short_run True