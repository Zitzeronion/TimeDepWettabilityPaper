### A Pluto.jl notebook ###
# v0.12.21

using Markdown
using InteractiveUtils

# ╔═╡ f5c0cd40-59b8-11eb-1ade-234f67f7efab
using DataFrames, CSV, Plots, StatsPlots, HTTP, DataFramesMeta

# ╔═╡ 3a80dbae-59b8-11eb-11c8-1b4ed01e73f5
md"""
# Switchable substrate with moving wettability

We analyze the interaction between an undulated thin film and a moving substrate pattern.

First some dependencies have to be loaded, [DataFrames](https://github.com/JuliaData/DataFrames.jl/tree/master) and [CSV](https://github.com/JuliaData/CSV.jl/tree/master) for the clean display of data, [Plots](https://github.com/JuliaPlots/Plots.jl) and [StatsPlots](https://github.com/JuliaPlots/StatsPlots.jl) for plotting, and [HTTP](https://github.com/JuliaWeb/HTTP.jl) for loading the data from web. 
"""

# ╔═╡ 0ec47530-59b9-11eb-0c49-2b70d7e37d4d
md"""
## Rupture times

First we take a look at the rupture times $\tau_r$.
For this we have to load a '.csv' file and import as a dataframe.

The file contains:

| Pattern | Wavelength | Velocity | Rt |
|---      |----------  | ------| ------|
| sine      | 1 | 1 | 1.6
| sine      | 2       |  0.1 | 1.9
| linear      | 1  | 10 | 2.2

The substrate pattern type the wavelength which is 512 for 1, 256 for 2 and 171 for 3, the pattern velocity $v_{\theta}$ and the rupture times $\tau_r$.

"""

# ╔═╡ 3e139540-7b6b-11eb-0671-c5e4c87e6b21
begin
	data="E:\\JuliaStuff\\Data_PhD\\Moving_wet_time\\rupture_times_new_df.csv"
	Rupture_frame = DataFrame(CSV.File(data)) 
end

# ╔═╡ 57585d80-7b6e-11eb-18b3-339ab0f601af
md" ### Distribution of rupture times"

# ╔═╡ 83464630-7b6b-11eb-0611-2bffbe393b19
begin
	# We make use of this to get a logarithmic plot
	Rupture_frame.velocities = Rupture_frame.velocities .+ 0.0001
    # Plotting the data
    @df Rupture_frame scatter(
        :velocities,
        :rupture_times,
        group = :lambda,
        m = (0.5, [:h :star7 :circle], 10),
        xlabel="v/v0",
        ylabel="t/t0",
        axis=:log,
        legendfontsize = 10,
        tickfont = (12, "Arial"),
        guidefont = (18, "Arial"),
        legend = :bottomright,
        # bg = RGB(0.2, 0.2, 0.2),
    )
end

# ╔═╡ 77b24122-7b6b-11eb-2036-41d8d55f985a
md"""
## Morphology with [Papaya2](https://github.com/morphometry/papaya2) 

First we need to load the data, which are mainly csv files with space seperators.
These files contain the output from papaya2 `imganalysis`.
That said `imganalysis` is one every time step for every wavelength and velocity.

An example file can be found below:
"""

# ╔═╡ 598d0cd2-59b9-11eb-0a8b-a1938e2c3c43
df_one_time_step = CSV.File(HTTP.get("https://jugit.fz-juelich.de/s.zitz/timedependent_wettability/-/raw/master/Data_CSV/sine_1_dia_0_0001.csv?inline=false").body, delim=" ") |> DataFrame

# ╔═╡ 751f6650-7ce1-11eb-3bfe-a1f01e765cf4
md"""
### All the data in the world
With a sweep through all our simulations we created two `.csv` files. One for the sine wave pattern and one for the triangle wave pattern. 

Both files are uploaded to the `jugit` repository of the time dependent wettability paper.
"""


# ╔═╡ d8a75470-7ce2-11eb-356d-63c3da69b9f0
Sine_data = CSV.File(HTTP.get("https://jugit.fz-juelich.de/s.zitz/timedependent_wettability/-/raw/master/Data_CSV/Sine_waves_data.csv?inline=false").body) |> DataFrame

# ╔═╡ f6d13570-8281-11eb-0f64-771e22a6b27d
Triangle_data = CSV.File(HTTP.get("https://jugit.fz-juelich.de/s.zitz/timedependent_wettability/-/raw/master/Data_CSV/Linear_waves_data.csv?inline=false").body) |> DataFrame

# ╔═╡ e4e0cb50-8574-11eb-1038-89de80870697
md"### Two for one
Now out of those two we make just a single one, they can be differentiated with their column `pattern` which is **1 in case of sine** and **2 in case of linear**
"

# ╔═╡ 322eae40-8575-11eb-2e84-291311788da2
begin
	all_data = DataFrame()
	all_data = vcat(all_data, Sine_data)
	all_data = vcat(all_data, Triangle_data)
end

# ╔═╡ 268c8790-8284-11eb-0511-e367b9211e74
md"
#### 1.01 Analysis of data 😵

The data inside the `DataFrames` contain the Irreducible Minkowski Tensors (IMTs) analysis from papaya2 `imganalysis`. The first column is the threshold value I set to indentify the rupture. Further columns are best explained [here](https://morphometry.org/theory/anisotropy-analysis-by-imt/)

To five most right columns are added to distinguish the varios parameters of the simulation, e.g. the wavelength $\lambda$.

On top of what there is already two more columns will be added in the following.
First being 
```math
\beta^{0,2}_1 = \frac{1-q_2}{1+q_2}\qquad \text{... anisotropy index},
```

and
```math
Q = \frac{4\pi A}{P^2} \qquad\text{... isoperimetric ratio}.
```
Both will help us understanding what actually happens and give us an effective measure to seperate the rivulet states from droplet states 💦.
"

# ╔═╡ 378cfcd0-8349-11eb-1ad0-8939849c2c1e
begin
	# Isoperimetric ratio
	all_data[!, "isoperi_ratio"] .= 4π .* all_data.area ./ all_data.perim
	
	# Anisotropy index
	all_data[!, "anisotro_ind"] .= (1 .- all_data.q2) ./ (1 .+ all_data.q2)
end

# ╔═╡ f5076320-834b-11eb-3d3d-0380c1997163
md" Now there are two more columns, one is called `isoperi_ratio` and the other one `anisotro_ind` for the isoperimetric ratio and the anisotropy index respectively.

### Filtering

For convinience we need to filter the data, as we can only compare parts to the data.
Therefor we define a filtering function that is based on the macro `@linq` of the [DataFramesMeta](https://github.com/JuliaData/DataFramesMeta.jl) library.


"

# ╔═╡ 0ed0c180-834b-11eb-3f40-b1243e850675
@linq all_data |>
	where(:threshold .< 20) |>
    where(:lambda .== 2) |>
    select(q2=:q2, :isoperi_ratio, :anisotro_ind)

# ╔═╡ Cell order:
# ╟─3a80dbae-59b8-11eb-11c8-1b4ed01e73f5
# ╠═f5c0cd40-59b8-11eb-1ade-234f67f7efab
# ╟─0ec47530-59b9-11eb-0c49-2b70d7e37d4d
# ╠═3e139540-7b6b-11eb-0671-c5e4c87e6b21
# ╟─57585d80-7b6e-11eb-18b3-339ab0f601af
# ╠═83464630-7b6b-11eb-0611-2bffbe393b19
# ╟─77b24122-7b6b-11eb-2036-41d8d55f985a
# ╠═598d0cd2-59b9-11eb-0a8b-a1938e2c3c43
# ╟─751f6650-7ce1-11eb-3bfe-a1f01e765cf4
# ╠═d8a75470-7ce2-11eb-356d-63c3da69b9f0
# ╠═f6d13570-8281-11eb-0f64-771e22a6b27d
# ╟─e4e0cb50-8574-11eb-1038-89de80870697
# ╠═322eae40-8575-11eb-2e84-291311788da2
# ╟─268c8790-8284-11eb-0511-e367b9211e74
# ╠═378cfcd0-8349-11eb-1ad0-8939849c2c1e
# ╠═f5076320-834b-11eb-3d3d-0380c1997163
# ╠═0ed0c180-834b-11eb-3f40-b1243e850675
