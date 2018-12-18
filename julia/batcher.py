#!/usr/bin/env python3
import itertools
import os
import click

def dict_product(d):
    """All possible combinations of values in lists in `d`"""
    for k, v in d.items():
        if not isinstance(v, list):
            d[k] = [v]

    for v in list(itertools.product(*d.values())):
        yield dict(zip(d.keys(), v))


SBATCH_SCRIPT = '''
#!/usr/bin/env bash
#SBATCH --job-name={job_name}
#SBATCH --output=runs/{job_name}/out/%A_%a
#SBATCH --array=1-{n_job}
#SBATCH --time={max_time}
#SBATCH --mem-per-cpu={mem_per_cpu}
#SBATCH --cpus-per-task={cpus_per_task}

module load julia
julia -L optimize.jl -e "main(\\"runs/{job_name}/jobs/$SLURM_ARRAY_TASK_ID.json\\")"
'''.strip()


def params(quick):
    return dict_product({
        'n_arm': 2,
        'n_iter': 2 if quick else 200,
        'n_roll': 2 if quick else 1000,
        'n_sim': 2 if quick else 10000,
        'obs_sigma': [5],
        'sample_cost': [0.002],
        'switch_cost': [1, 8],
        'seed': 0 if quick else [1,2]
    })


@click.command()
@click.argument('job-name')
@click.argument('max-time')
@click.option('--quick', is_flag=True)
@click.option('--mem-per-cpu', default=5000)
@click.option('--cpus-per-task', default=8)
def main(job_name, quick, **slurm_args):
    os.makedirs(f'runs/{job_name}/jobs', exist_ok=True)
    os.makedirs(f'runs/{job_name}/out', exist_ok=True)
    import json
    for i, prm in enumerate(params(quick), start=1):
        prm['job_name'] = job_name
        with open(f'runs/{job_name}/jobs/{i}.json', 'w+') as f:
            json.dump(prm, f)

    with open('run.sbatch', 'w+') as f:
        f.write(SBATCH_SCRIPT.format(n_job=i, job_name=job_name, **slurm_args))

    print(f'Wrote JSON and run.sbatch with {i} jobs.')

if __name__ == '__main__':
    main()
