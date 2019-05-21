using Distributed
@everywhere begin
    cd("/usr/people/flc2/juke/choice-eye-tracking/julia/")
    include("model.jl")
    include("job.jl")
    include("human.jl")
    include("simulations.jl")
    include("loss.jl")
end

using Plots
plot([1,2])

# %% ====================  ====================
using Glob
files = glob("runs/rando1000/jobs/*")
jobs = Job.(files)

all_losses = map(jobs) do job
    exists(job, :losses) ? deserialize(job, :losses) : missing
end
drop = ismissing.(all_losses)
jobs = jobs[.!drop]
all_losses = all_losses[.!drop]

# %% ====================  ====================
loss_names = [
    :value_choice,
    :fixation_bias,
    :value_bias,
    :fourth_rank,
    :first_fixation_duration,
    :last_fixation_duration,
    :difference_time,
    :difference_nfix,
    :fixation_times,
    :last_fix_bias,
    :gaze_cascade,
    :fixate_on_best,
]

function choose(use)
    (best, prior_idx), job_idx = map(all_losses) do prior_losses
        map(prior_losses) do losses
            sum(losses[[l in use for l in loss_names]])
        end |> findmin
    end |> findmin
    x = deserialize(jobs[job_idx], :simulations)[prior_idx]
    jobs[job_idx], x.prior, x.sim
end
use = [
    :value_choice,
    # :fourth_rank,
    :fixation_times,
    # :difference_nfix,
    # :difference_time,
    # :value_bias,
    # :fixate_on_best,
    # :gaze_cascade,
    # :last_fix_bias
]
μs = 0:0.1:μ_emp

job, prior, sim = choose(use)
mdp = MetaMDP(job)
println(mdp)
println(prior)
policy = Policy(mdp, deserialize(job, :optim).θ1)
sim = simulate_experiment(policy, prior)

job_idx = argmax(jobs .== [job])
prior_idx = argmax(prior[1] .== μs)

all_losses[job_idx][prior_idx][[l in use for l in loss_names]]
make_loss(fixation_times)(sim)

# %% ====================  ====================
pyplot()
Plots.scalefontsizes()
Plots.scalefontsizes(1.5)
const N_BOOT = 1000
using Bootstrap
using Printf
using Plots: px
estimator = mean
ci = 0.95

function ci_err(estimator, y)
    bs = bootstrap(estimator, y, BalancedSampling(N_BOOT))
    c = confint(bs, BasicConfInt(ci))[1]
    abs.(c[2:3] .- c[1])
end

# function plot_human(bins, x, y)
#     vals = bin_by(bins, x, y)
#     bar(mids(bins), estimator.(vals), yerr=ci_err.(estimator, vals),
#        fill=:white, color=:black, label="")
# end
function plot_human(bins, x, y, type=:line)
    vals = bin_by(bins, x, y)
    if type == :line
        plot(mids(bins), estimator.(vals), yerr=ci_err.(estimator, vals),
              grid=:none,
              color=:black,
              label="",)
    elseif type == :discrete
        Plots.bar(mids(bins), estimator.(vals), yerr=ci_err.(estimator, vals),
              grid=:none,
              fill=:white,
              color=:black,
              label="",)
  else
      error("Bad plot type : $type")
  end
end

function plot_model!(bins, x, y, type=:line)
    if type == :line
        plot!(mids(bins), estimator.(bin_by(bins, x, y)),
              line=(:red, :dash),
              label="",)
    elseif type == :discrete
        scatter!(mids(bins), estimator.(bin_by(bins, x, y)),
              grid=:none,
              marker=(5, :diamond, :red, stroke(0)),
              label="",)
    else
        error("Bad plot type : $type")
    end
end

function cross!(x, y)
    vline!([x], line=(:grey, 0.7), label="")
    hline!([y], line=(:grey, 0.7), label="")
end

function plot_comparison(feature, sim, bins=nothing, type=:line)
    hx, hy = feature(trials)
    mx, my = feature(sim)
    bins = make_bins(bins, hx)
    plot_human(bins, hx, hy, type)
    plot_model!(bins, mx, my, type)
    # title!(@sprintf "Loss = %.3f" make_loss(feature, bins)(sim))
end

function fig(f, name)
    _fig = f()
    savefig("figs/$name.pdf")
    _fig
end

# quantile(trials.rt, 0.05:0.1:0.95)
# %% ====================  ====================
fig("value_choice") do
    plot_comparison(value_choice, sim)
    xlabel!("Relative item value")
    ylabel!("Probability of choice")
end

fig("fixation_bias") do
    plot_comparison(fixation_bias, sim)
    cross!(0, 1/3)
    xlabel!("Relative fixation time")
    ylabel!("Probability of choice")
end

fig("value_bias") do
    plot_comparison(value_bias, sim)
    xlabel!("Relative item value")
    ylabel!("Proportion fixation time")
end

fig("fourth_rank") do
    plot_comparison(fourth_rank, sim, :integer, :discrete)
    xlabel!("Value rank of fourth-fixated item")
    ylabel!("Proportion")
    xticks!(1:3, ["best", "middle", "worst"])
end

fig("first_fixation_duration") do
    plot_comparison(first_fixation_duration, sim)
    xlabel!("Duration of first fixation")
    ylabel!("Probability of choice")
end

fig("last_fixation_duration") do
    plot_comparison(last_fixation_duration, sim)
    xlabel!("Chosen item time advantage\nbefore last fixation")
    ylabel!("Last fixation duration")
end

fig("difference_time") do
    plot_comparison(difference_time, sim)
    xlabel!("Maximum relative item value")
    ylabel!("Total fixation time")
end

fig("difference_nfix") do
    plot_comparison(difference_nfix, sim)
    xlabel!("Maxium relative item value")
    ylabel!("Number of fixations")
end

fig("fixation_times") do
    plot_comparison(fixation_times, sim, :integer, :discrete)
    xticks!(1:4, ["first", "second", "middle", "last"])
    xlabel!("Fixation type")
    ylabel!("Fixation duration")
end

fig("last_fix_bias") do
    plot_comparison(last_fix_bias, sim)
    cross!(0, 1/3)
    xlabel!("Last fixated item relative value")
    ylabel!("Probability of choosing\nlast fixated item")
end

fig("gaze_cascade") do
    plot_comparison(gaze_cascade, sim, :integer)
    xlabel!("Fixation number (aligned to choice)")
    ylabel!("Proportion of fixations\nto chosen item")
end

fig("fixate_on_best") do
    plot_comparison(fixate_on_best, sim, Binning(0:CUTOFF/7:CUTOFF))
    xlabel!("Time (ms)")
    ylabel!("Probability of fixating\non highest-value item")
end

# argmin(L[4, :])
# sim1 = simulate_experiment(policies[71],  (μ_emp, σ_emp), 10)


# %% ====================  ====================
function fig3b(trials)
    map(trials) do t
        last = t.fixations[end]
        # last != t.choice && return missing
        tft = total_fix_time(t)
        tft[last] -= t.fix_times[end]
        adv = 2 * tft[t.choice] - sum(tft)
        # adv = tft[t.choice] - mean(tft)
        (t.fix_times[end], adv)
    end |> skipmissing |> collect |> invert
end
fig("3b") do
    plot_comparison(fig3b, sim, Binning(-200:400:1400))
    xlabel!("Last fixation duration")
    ylabel!("Chosen item time advantage\nbefore last fixation")
    xticks!(0:400:1200)
end

# %% ====================  ====================


# my_losses = pmap(all_sims) do sim1
#     myloss = make_loss(fixation_times, :integer)
#     ismissing(sim1) ? Inf : myloss(sim1)
# end

# %% ====================  ====================
function neg_fixation_bias(trials)
    mapmany(trials) do t
        ft = total_fix_time(t)
        # invert((ft ./ sum(ft), t.choice .== 1:3))
        invert((ft .- mean(ft), t.choice .== 1:3))[t.value .< 2]
    end |> Vector{Tuple{Float64, Bool}} |> invert
end
plot_comparison(neg_fixation_bias, sim)

# %% ====================  ====================
using StatPlots

function fixate_probs(trials; k=6)
    X = zeros(Int, k, 3)
    for t in trials
        # length(t.fixations) < k && continue
        length(unique(t.value)) != length(t.value) && continue
        ranks = sortperm(-t.value)
        for i in 1:min(k, length(t.fixations))
            r = ranks[t.fixations[i]]
            X[i, r] += 1
        end
    end
    X ./ sum(X, dims=2)
end
Xh = fixate_probs(trials)
Xm = fixate_probs(sim)

fig("4a") do
    groupedbar(Xh, bar_position=:stack, label=["best" "middle" "worst"])
    scatter!(cumsum(Xm; dims=2)[:, 1:2], color=:black, label="")
    xlabel!("Fixation number")
    ylabel!("Proportion of fixations")
end

fig("4a_alt") do
    plot(Xh[:, [1,3]], color=:black, label=["best" "worst"], ls=[:solid :dash])
    plot!(Xm[:, [1,3]], color=:red, label="", ls=[:solid :dash])
    xlabel!("Fixation number")
    ylabel!("Proportion of fixations")
end
# %% ====================  ====================
Xh .- Xm

# %% ====================  ====================
function fixate_probs_from_end(trials; k=6)
    X = zeros(Int, k, 3)
    for t in trials
        # length(t.fixations) < k && continue
        length(unique(t.value)) != length(t.value) && continue
        ranks = sortperm(-t.value)
        nfix = length(t.fixations)
        for i in 1:min(k, nfix)
            r = ranks[t.fixations[end+1-i]]
            X[i, r] += 1
        end
    end
    reverse(X ./ sum(X, dims=2); dims=1)
end
Xh = fixate_probs_from_end(trials)
Xm = fixate_probs_from_end(sim)

fig("4b") do
    groupedbar(Xh, bar_position=:stack, label=["best" "middle" "worst"])
    scatter!(cumsum(Xm; dims=2)[:, 1:2], color=:black, label="")
    xticks!(1:6, string.(-5:0))
    xlabel!("Fixation number")
    ylabel!("Proportion of fixations")
end

fig("4b_alt") do
    plot(Xh[:, [1,3]], color=:black, label=["best" "worst"], ls=[:solid :dash])
    plot!(Xm[:, [1,3]], color=:red, label="", ls=[:solid :dash])
    xticks!(1:6, string.(-5:0))
    xlabel!("Fixation number")
    ylabel!("Proportion of fixations")
end

# %% ====================  ====================
function last_fix_bias(trials)
    map(trials) do t
        last = t.fixations[end]
        if t.value[last] > μ_emp
            return missing
        end
        return (t.value[last] - mean(t.value), t.choice == last)
    end |> skipmissing |> collect |> invert
end

plot_comparison(last_fix_bias, sim)
cross!(0, 1/3)
xlabel!("Last fixated item relative value")
ylabel!("Probability of choosing\nlast fixated item")


# %% ====================  ====================

function best_vs_middle(trials)
    # x, y = [], []
    map(trials) do t
        ft = total_fix_time(t)
        best, middle, worst = sortperm(-t.value)
        t.value[best] == t.value[middle] && return missing
        t.choice == worst && return missing
        ft[best] - ft[middle], t.choice == best
    end |> skipmissing |> collect |> invert
end

fig("best_vs_middle") do
    plot_comparison(best_vs_middle, sim)
    xlabel!("Fixation time on best vs. middle")
    ylabel!("Probability choose best")
end

# %% ====================  ====================

function not_worst(trials)
    # x, y = [], []
    map(trials) do t
        ft = total_fix_time(t)
        best, middle, worst = sortperm(-t.value)
        t.value[middle] == t.value[worst] && return missing
        # t.choice == worst && return missing
        ft[best] + ft[middle] - ft[worst], t.choice != worst
    end |> skipmissing |> collect |> invert
end

fig("not_worst") do
    plot_comparison(not_worst, sim)
    xlabel!("Fixation time on best or middle vs. worst")
    ylabel!("Probability choose best or middle  ")
end

# # %% ====================  ====================
# @everywhere function fixate_on_best(trials; k=6)
#     denom = zeros(Int, k)
#     num = zeros(Int, k)
#     for t in trials
#         x = t.fixations .== argmin(t.value)
#         for i in 1:min(k, length(x))
#             denom[i] += 1
#             num[i] += x[i]
#         end
#     end
#     1:k, num ./ denom
# end
# plot_comparison(fixate_on_best, sim, :integer)

# %% ====================  ====================
@everywhere myloss = make_loss(fixate_on_best, Binning(0:CUTOFF/7:CUTOFF))
my_losses = pmap(all_sims) do sim1
    ismissing(sim1) ? Inf : myloss(sim1)
end
my_best = argmin(my_losses)
sim1 = all_sims[my_best]
plot_comparison(fixate_on_best, sim1, Binning(0:CUTOFF/7:CUTOFF))

# plot_comparison(fixation_value, sim, Binning(0:3970/20:3970))

# %% ====================  ====================

histogram(length.(sim.fixations))

sim
# %% ====================  ====================
map(sim) do t
    t.choice == argmax(t.value)
end |> mean

# %% ====================  ====================
function nth_rank(n)
    return trials -> begin
        x = Int[]
        for t in trials
            if length(t.fixations) >= n
                ranks = sortperm(sortperm(-t.value))
                push!(x, ranks[t.fixations[n]])
            end
        end
        if length(x) == 0
            return missing
        end
        cx = counts(x, 3)
        1:3, cx / sum(cx)
    end
end
plot_comparison(nth_rank(3), sim, :integer, :discrete)

# %% ====================  ====================
x = Bool[]
for t in sim
    if unique_values(t)
        ranks = sortperm(sortperm(-t.value))
        push!(x, ranks[t.fixations[1]] == 1)
    end
end
# %% ====================  ====================
success, n = sum(x), length(x)
success/n
using RCall
R"binom.test($success, $n, 1/3)"

# %% ====================  ====================

@everywhere function nfix_by_time(trials)
    x, y = Float64[], Int[]
    for t in trials
        for (i, ft) in enumerate(cumsum(t.fix_times))
            push!(x, ft)
            push!(y, i)
        end
    end
    x, y
end

@everywhere myloss = make_loss(nfix_by_time, Binning(0:100:3000))
my_losses = pmap(all_sims) do sim1
    ismissing(sim1) ? Inf : myloss(sim1)
end
nbt_best = argmin(my_losses)

jobs[nbt_best]
# %% ====================  ====================
fig("nfix_by_time") do
    plot_comparison(nfix_by_time, all_sims[nbt_best], Binning(0:100:3000))
    xlabel!("Time (ms)")
    ylabel!("Number of fixations")
end

# %% ====================  ====================

# myloss = make_loss(fixation_value, Binning(0:3970/20:3970))
# my_losses = pmap(all_sims) do sim1
#     ismissing(sim1) ? Inf : myloss(sim1)
# end
# my_best = argmin(my_losses)
# sim1 = all_sims[my_best]

# plot_comparison(fixation_value, sim, Binning(0:3970/20:3970))
# fig("fixation_series") do
#     plot_comparison(fixation_value, sim, Binning(0:3970/20:3970))
#     xlabel!("Time (ms)")
#     ylabel!("Ave")
# end

# %% ====================  ====================



# %% ====================  ====================
function wow(trials)
    x, y, z = [], [], []
    for t in trials
        tft = total_fix_time(t)
        rv = t.value .- mean(t.value)
        c = t.choice .== 1:3
        for i in 1:3
            push!(x, tft[i]))
            push!(y, rv[i]))
            push!(z, c[i]))
    end
end
# %% ====================  ====================
function bang(trials)
    map(trials) do t
        tft = total_fix_time(t)
        rv = t.value .- mean(t.value)
        c = t.choice
        tft[c], rv[c]
    end |> invert
end

bang(trials)

# %% ====================  ====================



# %% ====================  ====================
# priors, losses = map(jobs) do job
#     try
#         deserialize(job, :optimized_prior)
#     catch
#         (missing, Inf)
#     end
# end |> invert
#
# best = argmin(new_losses)
# job = jobs[best]
# policy = optimized_policy(job)
# prior = priors[best]
# sim = simulate_experiment(policy, prior)
# # @time sim = simulate_experiment(optimized_policy(job), prior, 10)
# %% ====================  ====================
