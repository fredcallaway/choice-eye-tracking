BASE_DIR = "results/final"
SEARCH_STRATEGY = :sobol
GRID_SIZE = -1
FIT_PRIOR = false

SPACE = Box(
    :α => (100, 350),
    :σ_obs => (1, 5),
    :sample_cost => (.001, .01),
    :switch_cost => (.003, .03),
)

UCB_PARAMS = (
    N = 20^3,
    n_iter=500,
    n_init=50,
    n_roll=50,
    n_top=80
)
LIKELIHOOD_PARAMS = (
    fit_ε = true,
    max_ε = 0.5,
    n_sim_hist = 10_000,
    test_fold = "odd",
    hist_bins = 5
)