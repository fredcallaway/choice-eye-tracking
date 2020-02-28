using Distributed
using Serialization
include("box.jl")
include("meta_mdp.jl")
include("bmps.jl")
include("optimize_bmps.jl")
include("ucb_bmps.jl")

include("pseudo_likelihood.jl")
include("pseudo_base.jl")


space = Box(
    :sample_time => 100,
    :α => (50, 200),
    :σ_obs => (1, 5),
    :sample_cost => (.001, .01),
    :switch_cost => (.01, .05),
)

args = Dict(
    "hist_bins" => 5,
    "propfix" => true,
    "fold" => "odd",
)

like_kws = (
    fit_ε = true,
    max_ε = 0.5,
    n_sim_hist = 10_000
)

x2prm(x) = x |> space |> namedtuple

function get_policies(n_item, prm; n_top=80)
    m = MetaMDP(n_item, prm.σ_obs, prm.sample_cost, prm.switch_cost)
    policies, μ, sem = ucb(m; N=8000, α=prm.α, n_iter=500, n_init=100, n_roll=100, n_top=n_top)
    return policies[partialsortperm(-μ, 1:n_top)]
end

function get_loss(policies, ds, β_µ)
    prm = (β_μ=β_μ, β_σ=1., σ_rating=NaN)
    logp, ε, baseline = likelihood(ds, policies, prm; parallel=false);
    logp / baseline
end

function sim_one(policy, μ, σ, v)
    sim = simulate(policy, (v .- μ) ./ σ; max_steps=MAX_STEPS)
    fixs, fix_times = parse_fixations(sim.samples, SAMPLE_TIME)
    (choice=sim.choice, value=v, fixations=fixs, fix_times=fix_times)
end

function simulate_test(policy::Policy, ds, β_μ::Float64)
    μ = β_μ * ds.μ_emp
    σ = ds.σ_emp
    map(ds.test_trials.value) do v
        sim_one(policy, μ, σ, v)
    end |> Table
end