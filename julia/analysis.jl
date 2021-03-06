# %% ==================== Set up ====================

using StatsBase
using DataStructures: OrderedDict
using Lazy: @as

include("utils.jl")
include("meta_mdp.jl")
include("data.jl")
mkpath("results")

IVS = [:sigma, :alpha, :cost]
version = "1.0"
all_trials = load_trials(version);
all_sims = mapreduce(vcat, 1:50) do i
    deserialize("tmp/sims/$i")
end

# %% --------
length(all_sims)
json(all_sims[1])
t = all_sims[1]

open("all_sims.json", "w") do f
    JSON.print(f, all_sims)
end

# %% ==================== Define strategies ====================

C = reshape(1:24, 4, 6)  # matrix of cell numbers
STRATEGIES = [:rand, :wadd, :ttb, :sat_ttb, :unknown]

function classify(t::Trial)
    # no clicking => rand
    length(t.uncovered) == 0 && return :rand
    # full clicking => wadd
    length(t.uncovered) == length(C) && return :wadd
    
    # click whole maximal weight row => ttb
    ttb_row = argmax(t.weights)
    Set(t.uncovered) == Set(C[ttb_row, :]) && return :ttb
    
    # click subest of maximal weight row AND last revealed is unique maximum => sat_ttb
    Set(t.uncovered) < Set(C[ttb_row, :]) && 
        argmax(t.values[t.uncovered]) == length(t.uncovered) && return :sat_ttb

    return :unknown
end


# %% ==================== Descriptive statistics ====================

term_reward(t::Trial) = term_reward(get_data(t)[end].b)

function describe(t::Trial)
    (
        sigma=t.sigma, alpha=t.alpha, cost=t.cost, 
        # t=t,
        strategy = classify(t), 
        n_revealed = length(t.uncovered),
        term_reward = term_reward(t),
    ) 
end

human = describe.(all_trials) |> DataFrame
model = describe.(all_sims) |> DataFrame

groupmean(X, dvs) = combine(groupby(X, IVS), dvs .=> mean .=> dvs)
groupmean(human, [:term_reward, :n_revealed]) |> CSV.write("results/reward_revealed.csv")
groupmean(model, [:term_reward, :n_revealed]) |> CSV.write("results/reward_revealed_model.csv")

# %% ==================== Strategy frequencies ====================

function strategy_frequency_by_condition(T::DataFrame)
    S = @as x T.strategy begin
        x .== reshape(STRATEGIES, 1, :)
        DataFrame(x, STRATEGIES)
        hcat(T[IVS], x)
        groupby(x, IVS)
        combine(x, STRATEGIES .=> sum)
        rename(col->replace(col, "_sum" => ""), x)
        sort!
    end
    S[4:end] = S[4:end] ./ sum.(eachrow(S[4:end]))
    S
end


SH = strategy_frequency_by_condition(human)
SM = strategy_frequency_by_condition(model)

CSV.write("results/strategy_frequencies.csv", SH)
CSV.write("results/strategy_frequencies_model.csv", SM)


# %% ==================== Breakdowns ====================
S = SH
combine(S, STRATEGIES .=> mean)
combine(groupby(S, :sigma), STRATEGIES .=> mean)
combine(groupby(S, :alpha), STRATEGIES .=> mean)
combine(groupby(S, :cost), STRATEGIES .=> mean)
