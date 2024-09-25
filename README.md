# flusion_city

This is a modified version of the Flusion model (https://github.com/reichlab/flusion) adapted for city-level forecasting.

[code](https://github.com/donga0223/flusion_city/tree/master/code) contains python code for forecasting. See the readme in that folder for further information. 

[data-raw](https://github.com/donga0223/flusion_city/tree/master/data-raw) raw data measuring influenza activity, pulled from various sources. See the readme in that folder for further information.

[output](https://github.com/donga0223/flusion_city/tree/master/output) a folder for output and summary code for forecast visualization.


## Environment setup
I ran everything on the TACC cluster (UT Austin cluster) and needed to install Miniconda in your directory.

1. Download and install Miniconda:

```
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash Miniconda3-latest-Linux-x86_64.sh
source ~/.bashrc
```

2. After installing conda, initialize it in your directory:

```
~/miniconda3
~/miniconda3/bin/conda init
source ~/.bashrc
conda
```

3.Now you can create the Flusion environment:

```
conda env create -f environment.yml
```

4. Once the environment is set up, activate it and run the test:

```
idev -N 1 -n 1 -t 02:00:00 -p development -A A-ib1  ## getting on a development node first
conda activate flusion
python code/gbq_city/gbq_all.py --test_run
```

The `--test_run` option will perform a very short test run for two reference dates and three different source settings. Without `--test_run`, you will submit all cases, which will result in around 100 jobs. So, please run the test first before submitting everything.

5. To fit a single reference date and a single source condition, run a command like: `python code/gbq_city/gbq.py --ref_date '2023-09-30 --model_name gbq_qr` 

Alternatively, to submit all jobs, run: `python code/gbq_city/gbq_all.py`
The script `code/gbq_city/gbq_all.py` generates `.sh` files for job submission and submits them.

