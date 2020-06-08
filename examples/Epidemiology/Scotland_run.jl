using Simulation
using Unitful
using Unitful.DefaultSymbols
using Simulation.Units
using Simulation.ClimatePref
using StatsBase
using Distributions

do_plot = false

# Read in population sizes for Scotland
scotpop = parse_hdf5(Simulation.path("test", "examples", "scrc_demographics.h5"), grid="10k")
# Sum up age categories and turn into simple matrix
total_pop = dropdims(sum(scotpop, dims=3), dims=3)

# Read number of age categories
age_categories = size(scotpop, 3)

# Set up simple gridded environment
area = 525_000.0km^2

# Set simulation parameters
numclasses = 7
numvirus = 1
birth_rates = fill(0.0/day, numclasses, age_categories)
death_rates = fill(0.0/day, numclasses, age_categories)
birth_rates[:, 2:4] .= uconvert(day^-1, 1/20years); death_rates[1:end-1, :] .= uconvert(day^-1, 1/100years)
virus_growth_asymp = virus_growth_symp = fill(0.1/day, age_categories)
virus_decay = 1.0/day
beta_force = fill(10.0/day, age_categories)
beta_env = fill(10.0/day, age_categories)
ageing = fill(0.0/day, age_categories - 1) # no ageing for now

# Prob of developing symptoms
p_s = fill(0.96, age_categories)
# Prob of hospitalisation
p_h = fill(0.2, age_categories)
# Case fatality ratio
cfr_home = cfr_hospital = fill(0.1, age_categories)
# Time exposed
T_lat = 5days
# Time asymptomatic
T_asym = 3days
# Time symptomatic
T_sym = 5days
# Time in hospital
T_hosp = 5days
# Time to recovery if symptomatic
T_rec = 11days

param = SEI2HRDGrowth(birth_rates, death_rates, ageing,
                      virus_growth_asymp, virus_growth_symp, virus_decay,
                      beta_force, beta_env, p_s, p_h, cfr_home, cfr_hospital,
                      T_lat, T_asym, T_sym, T_hosp, T_rec)
param = transition(param, age_categories)

epienv = simplehabitatAE(298.0K, area, NoControl(), total_pop)

# Set population to initially have no individuals
sus = ["Susceptible"]
inf = ["Asymptomatic", "Symptomatic"]
abun_h = (
    Susceptible = fill(0, age_categories),
    Exposed = fill(0, age_categories),
    Asymptomatic = fill(0, age_categories),
    Symptomatic = fill(0, age_categories),
    Hospitalised = fill(0, age_categories),
    Recovered = fill(0, age_categories),
    Dead = fill(0, age_categories),
    susceptibility = sus,
    infectious = inf
)
abun_v = (Virus = 0,)

# Dispersal kernels for virus and disease classes
dispersal_dists = fill(1.0km, numclasses * age_categories)
cat_idx = reshape(1:(numclasses * age_categories), age_categories, numclasses)
dispersal_dists[vcat(cat_idx[:, 3:4]...)] .= 20.0km
kernel = GaussianKernel.(dispersal_dists, 1e-10)
movement = AlwaysMovement(kernel)

# Traits for match to environment (turned off currently through param choice, i.e. virus matches environment perfectly)
traits = GaussTrait(fill(298.0K, numvirus), fill(0.1K, numvirus))
epilist = EpiList(traits, abun_v, abun_h, movement, param, age_categories)
rel = Gauss{eltype(epienv.habitat)}()

# Create epi system with all information
epi = EpiSystem(epilist, epienv, rel)

# Populate susceptibles according to actual population spread
reshaped_pop = reshape(scotpop, size(scotpop, 1) * size(scotpop, 2), size(scotpop, 3))'
epi.abundances.matrix[cat_idx[:, 1], :] = reshaped_pop

# Add in initial infections randomly (samples weighted by population size)
# Define generator for all pair age x cell
age_and_cells = Iterators.product(1:age_categories, 1:size(epi.abundances.matrix, 2))
# Take all susceptibles of each age per cell
pop_weights = epi.abundances.matrix[vcat(cat_idx[:, 1]...), :]
# It would be nice if it wasn't necessary to call collect here
samp = sample(collect(age_and_cells), weights(1.0 .* vec(pop_weights)), 100)
age_ids = getfield.(samp, 1)
cell_ids = getfield.(samp, 2)
epi.abundances.matrix[vcat(cat_idx[age_ids, 2]...), cell_ids] .= 10 # Add to exposed
epi.abundances.matrix[vcat(cat_idx[age_ids, 1]...), cell_ids] =
epi.abundances.matrix[vcat(cat_idx[age_ids, 1]...), cell_ids] .- 10 # Remove from susceptible

# Run simulation
abuns = zeros(Int64, size(epi.abundances.matrix, 1), N_cells, 366)
times = 1year; interval = 1day; timestep = 1day
@time simulate_record!(abuns, epi, times, interval, timestep)


if do_plot
    using Plots
    # View summed SIR dynamics for whole area
    category_map = (
        "Susceptible" => cat_idx[:, 1],
        "Exposed" => cat_idx[:, 2],
        "Asymptomatic" => cat_idx[:, 3],
        "Symptomatic" => cat_idx[:, 4],
        "Hospital" => cat_idx[:, 5],
        "Recovered" => cat_idx[:, 6],
        "Deaths" => cat_idx[:, 7],
    )
    display(plot_epidynamics(epi, abuns; category_map=category_map))
end
