#!/bin/bash

#SBATCH -J flusion_city                     # Job name
#SBATCH -o flusion_city.%j.o                # Name of stdout output file (%j expands to jobId)
#SBATCH -e flusion_city.%j.e                # Name of stderr output file (%j expands to jobId)
#SBATCH -p small                            # Queue name, small is for <=2 nodes, normal 3+
#SBATCH -N 1                  	            # Total number of nodes requested
#SBATCH -n 5                                # Total number of tasks to run 56 cores/node (28 per socket)
#SBATCH -t 00:02:00            	            # Run time (hh:mm:ss)
#SBATCH -A A-ib1                            # Allocation name
#SBATCH --mail-user=dongah.kim@utexas.edu   # Email for notifications
#SBATCH --mail-type=all                     # Type of notifications, begin, end, fail, all

#conda activate flusion
module load python

# Load launcher
module load launcher

# Configure launcher
EXECUTABLE=$TACC_LAUNCHER_DIR/init_launcher
PRUN=$TACC_LAUNCHER_DIR/paramrun
CONTROL_FILE=commands_flusion_city_model.txt
export LAUNCHER_JOB_FILE=commands_flusion_city_model.txt
export LAUNCHER_WORKDIR=`pwd`
export LAUNCHER_SCHED=interleaved

# Start launcher
$PRUN $EXECUTABLE $CONTROL_FILE
