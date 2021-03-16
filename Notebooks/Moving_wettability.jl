### A Pluto.jl notebook ###
# v0.12.21

using Markdown
using InteractiveUtils

# ╔═╡ f5c0cd40-59b8-11eb-1ade-234f67f7efab
using DataFrames, CSV, Plots, StatsPlots, HTTP, DataFramesMeta

# ╔═╡ 3a80dbae-59b8-11eb-11c8-1b4ed01e73f5
md"
# Switchable substrate with moving wettability

We analyze the interaction between an undulated thin film and a moving substrate pattern.
To put it simply what we mean with moving substrate pattern is nothing more than
```math
∂ₓθ(x,t) ≠ 0 \quad\text{and}\quad ∂ₜθ(x,t) ≠ 0.
```

Below the contact angle distribution for two different time steps is shown, brighter spots show a higher contact angle.

This, however does not mean that the substrate itself has a velocity.
We still require that the films velocity at the film solid interface has to vanish, such a **no-slip** boundary condition.
Any flow that is generated is therefor only due to the change of the pattern.
"

# ╔═╡ 1151bf70-865e-11eb-044e-6d28c3bfce41
html"""
<img src="https://jugit.fz-juelich.de/s.zitz/timedependent_wettability/-/raw/master/Figures/angle_early.png?inline=false" width="320" height="320" />
<img src="https://jugit.fz-juelich.de/s.zitz/timedependent_wettability/-/raw/master/Figures/angle_later.png?inline=false" width="320" height="320" />
"""

# ╔═╡ 11851990-8660-11eb-29a3-553867ba8c75
md"
## Dependencies

First some dependencies have to be loaded, [DataFrames](https://github.com/JuliaData/DataFrames.jl/tree/master) and [CSV](https://github.com/JuliaData/CSV.jl/tree/master) for the clean display of data, [Plots](https://github.com/JuliaPlots/Plots.jl) and [StatsPlots](https://github.com/JuliaPlots/StatsPlots.jl) for plotting, and [HTTP](https://github.com/JuliaWeb/HTTP.jl) for loading the data from web.
For the analysis of the our data we need some way to scan efficiently through the `DataFrames`, for this reason we include [DataFramesMeta](https://github.com/JuliaData/DataFramesMeta.jl) and make heavy use of the `@linq` macro.
"

# ╔═╡ 4ebc1620-865a-11eb-1e0d-cd2669b2acad
md"## Height tracking

One of the simpler measures is the difference between the maximum and the minimum of the thickness of the fluid film, 
```math
Δh = \max(h(x,t)) - \min(h(x,t)).
```

This brings us to the general structure of the data files.
The three main categories are *pattern velocity*, *wavelenght* (λ) and *pattern* (triangle- and sinewave).
Lastly there is usually a *time step* (Δt) associated with the data, in some cases it is already normalized with *t₀* which is a characteristic time of the system.

| Pattern | Wavelength | Velocity | Time  | 
|---      |----------  | ------   | ----  |
| sine    | 1          | 0        | 5000  |
| linear  | 2          | 0.1      | 10000 | 
|    -    | 3          | 1.0      | ...   |
|    -    | -          | 10.0     | 5*10^6|

### Actual data

Below a **CSV** file is loaded which contains the Δh information.
A quick sanity check is to count the number of lines in the file.
For every simulation we save 1000 columns of heigth data, therefore
```math
N = 1000 × Nₚ × Nᵩ × Nᵥ ≝ 24000,  
```
because we have 2 patterns, 3 wavelenghts (Nᵩ) and 4 velocities.

"

# ╔═╡ 12901690-8684-11eb-2978-3f4b6f0d0fc4
df_delta_h = CSV.File(HTTP.get("https://jugit.fz-juelich.de/s.zitz/timedependent_wettability/-/raw/master/Data_CSV/height_differences.csv?inline=false").body) |> DataFrame

# ╔═╡ 0ec47530-59b9-11eb-0c49-2b70d7e37d4d
md"""
### Rupture times

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
df_rup_times = CSV.File(HTTP.get("https://jugit.fz-juelich.de/s.zitz/timedependent_wettability/-/raw/master/Data_CSV/rupture_times_new_df.csv?inline=false").body) |> DataFrame

# ╔═╡ 57585d80-7b6e-11eb-18b3-339ab0f601af
md" ### Distribution of rupture times"

# ╔═╡ 83464630-7b6b-11eb-0611-2bffbe393b19
begin
	# We make use of this to get a logarithmic plot
	df_rup_times.velocities = df_rup_times.velocities .+ 0.0001
    # Plotting the data
    @df df_rup_times scatter(
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


Lastly we add as well the normalized time t/t₀ to the dataframe.
Since this already done, we just need to load it in from web like the others.
The definition of t₀ can be found below, it's computed mostly from simulation constants.
```math
t₀ = 3μ/γh₀³q₀⁴,
```
with q₀ being
```math
q₀² = Π'(h₀)/2,
```
where Π(h) is the disjoining pressure functional. 
"

# ╔═╡ 378cfcd0-8349-11eb-1ad0-8939849c2c1e
"""
	t0()
	
Defines a characteristic time value for a contact angle of 30 degs and other parameters.
"""
function t0(;hᵦ=0.07, γ=0.01, μ=1/6, θ=1/6)
		qsq = hᵦ * (1 - cospi(θ)) * (2 - 3 * hᵦ) 
		charT = 3 * μ / (γ * qsq^2)

		return charT
end

# ╔═╡ a13e4120-8641-11eb-0c7b-b366d42b115c
all_data = CSV.File(HTTP.get("https://jugit.fz-juelich.de/s.zitz/timedependent_wettability/-/raw/master/Data_CSV/Data_with_t0_Q_beta.csv?inline=false").body) |> DataFrame

# ╔═╡ f5076320-834b-11eb-3d3d-0380c1997163
md" Now there are two more columns, one is called `isoperi_ratio` and the other one `anisotro_ind` for the isoperimetric ratio and the anisotropy index respectively.

### Filtering

For convinience we need to filter the data, as we can only compare parts to the data.
Therefor we define a filtering function that is based on the macro `@linq` of the [DataFramesMeta](https://github.com/JuliaData/DataFramesMeta.jl) library.

**WIP** 
Turns out this is not trivial!

The first few columns contain more infromation than we need, especially $q_4$ to $q_8$ are not relevant right now. However $q_2$ is of much interest, as it helps to qunatize what is a rivulet and what is a droplet state.

#### Data $\lambda = 1$, $v_n = 0$, threshold=15, pattern=sine
Yes there are just 998 *datapoints*, this is due to some abiguity in papaya2 when it comes to time step **10** and time step **100**. Had no time to look into this yet.
"

# ╔═╡ 0ed0c180-834b-11eb-3f40-b1243e850675
begin
	lam = 1
	thresh = 15
	vel = 0.0
	vel_cont = 1.0
	pat = 1
	filtered = @linq all_data |>
		where(:threshold .== thresh) |>
		where(:lambda .== lam) |>
		where(:vel_norm .== vel) |>
		where(:pattern .== pat) |>
		select(:q2, :q3, :q4, :q5, :q6, :q7, :q8, :isoperi_ratio, :anisotro_ind, :t_norm)
	
	filtered2 = @linq all_data |>
		where(:threshold .== thresh) |>
		where(:lambda .== lam) |>
		where(:vel_norm .== vel_cont) |>
		where(:pattern .== pat) |>
		select(:q2, :q3, :q4, :q5, :q6, :q7, :q8, :isoperi_ratio, :anisotro_ind, :t_norm)
end

# ╔═╡ 56e7d3e2-859f-11eb-26ec-996629c4b3d1
begin
	step = 25
    scatter(filtered.t_norm[1:step:end],
        filtered.q2[1:step:end],
        m = (0.5, [:circle], 10),
        xlabel="t/t0",
        ylabel="Data",
        label="q2_0",
        legendfontsize = 10,
        tickfont = (12, "Arial"),
        guidefont = (18, "Arial"),
        legend = :bottomright,
        # bg = RGB(0.2, 0.2, 0.2),
    )
	scatter!(filtered2.t_norm[1:step:end],
        filtered2.q2[1:step:end],
        m = (0.5, [:circle], 10),
        xlabel="t/t0",
        ylabel="Data",
        label="q2_1",
        legendfontsize = 10,
        tickfont = (12, "Arial"),
        guidefont = (18, "Arial"),
        legend = :bottomright,
        # bg = RGB(0.2, 0.2, 0.2),
    )
	scatter!(filtered.t_norm[1:step:end],
        filtered.q4[1:step:end],
        m = (0.5, [:h], 10),
        xlabel="t/t0",
        ylabel="Data",
        label="q4_0",
        legendfontsize = 10,
        tickfont = (12, "Arial"),
        guidefont = (18, "Arial"),
        legend = :bottomright,
        # bg = RGB(0.2, 0.2, 0.2),
    )
	scatter!(filtered2.t_norm[1:step:end],
        filtered2.q4[1:step:end],
        m = (0.5, [:h], 10),
        xlabel="t/t0",
        ylabel="Data",
        label="q4_1",
        legendfontsize = 10,
        tickfont = (12, "Arial"),
        guidefont = (18, "Arial"),
        legend = :bottomright,
        # bg = RGB(0.2, 0.2, 0.2),
    )
	scatter!(filtered.t_norm[1:step:end],
        filtered.q6[1:step:end],
        m = (0.5, [:star5], 10),
        xlabel="t/t0",
        ylabel="Data",
        label="q6_0",
        legendfontsize = 10,
        tickfont = (12, "Arial"),
        guidefont = (18, "Arial"),
        legend = :bottomright,
        # bg = RGB(0.2, 0.2, 0.2),
    )
	scatter!(filtered2.t_norm[1:step:end],
        filtered2.q6[1:step:end],
        m = (0.5, [:star5], 10),
        xlabel="t/t0",
        ylabel="Data",
        label="q6_1",
        legendfontsize = 10,
        tickfont = (12, "Arial"),
        guidefont = (18, "Arial"),
        legend = :bottomright,
        # bg = RGB(0.2, 0.2, 0.2),
    )
	scatter!(filtered.t_norm[1:step:end],
        filtered.q8[1:step:end],
        m = (0.5, [:star7], 10),
        xlabel="t/t0",
        ylabel="Data",
        label="q8_0",
        legendfontsize = 10,
        tickfont = (12, "Arial"),
        guidefont = (18, "Arial"),
        legend = :bottomright,
        # bg = RGB(0.2, 0.2, 0.2),
    )
	scatter!(filtered2.t_norm[1:step:end],
        filtered2.q8[1:step:end],
        m = (0.5, [:star7], 10),
        xlabel="t/t0",
        ylabel="Data",
        label="q8_1",
        legendfontsize = 10,
        tickfont = (12, "Arial"),
        guidefont = (18, "Arial"),
        legend = :topright,
        # bg = RGB(0.2, 0.2, 0.2),
    )
	# scatter!(filtered.t_norm[1:step:end],
	# filtered.anisotro_ind[1:step:end],
	# m = (0.5, [:h], 10),
	# xlabel="t/t0",
	# ylabel="Data",
	# label="beta 02 1 0",
	# legendfontsize = 10,
	# tickfont = (12, "Arial"),
	# guidefont = (18, "Arial"),
	# legend = :bottomright,
	# # bg = RGB(0.2, 0.2, 0.2),
	# )
	# scatter!(filtered2.t_norm[1:step:end],
	# filtered2.anisotro_ind[1:step:end],
	# m = (0.5, [:h], 10),
	# xlabel="t/t0",
	# ylabel="Data",
	# label="beta 02 1 1",
	# legendfontsize = 10,
	# tickfont = (12, "Arial"),
	# guidefont = (18, "Arial"),
	# legend = :bottomright,
	# # bg = RGB(0.2, 0.2, 0.2),
	# )
	
end

# ╔═╡ 3de90bb0-8654-11eb-1d63-6324f3d13170
md"#### Simple moving average

To clean the noise of the data it is useful to take the moving average instead of just the data.
"
function SMA(arg; nums=5)
	moving_average = zeros(length(arg)÷nums)
	for i in 1:nums
		sum(arg[i*1:5])
end

# ╔═╡ edbffab0-85a2-11eb-1928-690f7101c1ff
begin
	scatter(filtered.t_norm[1:step:end],
		filtered.isoperi_ratio[1:step:end] ./ (512*512),
        m = (0.5, [:star5], 10),
        xlabel="t/t0",
        ylabel="Data",
        label="Q_0",
        legendfontsize = 10,
        tickfont = (12, "Arial"),
        guidefont = (18, "Arial"),
        legend = :bottomright,
        # bg = RGB(0.2, 0.2, 0.2),
    )
	scatter!(filtered2.t_norm[1:step:end],
		filtered2.isoperi_ratio[1:step:end] ./ (512*512),
        m = (0.5, [:star5], 10),
        xlabel="t/t0",
        ylabel="Data",
        label="Q_1",
        legendfontsize = 10,
        tickfont = (12, "Arial"),
        guidefont = (18, "Arial"),
        legend = :topright,
        # bg = RGB(0.2, 0.2, 0.2),
		ylim = (0, 0.02)
    )
end

# ╔═╡ e1feb1d0-85a7-11eb-0f66-dd1f03ccd405
begin
	scatter(filtered.t_norm[1:step:end],
		filtered.q3[1:step:end] ./ (512*512),
        m = (0.5, [:star5], 10),
        xlabel="t/t0",
        ylabel="Data",
        label="q3_0",
        legendfontsize = 10,
        tickfont = (12, "Arial"),
        guidefont = (18, "Arial"),
        legend = :bottomright,
        # bg = RGB(0.2, 0.2, 0.2),
    )
	scatter!(filtered2.t_norm[1:step:end],
		filtered2.q3[1:step:end] ./ (512*512),
        m = (0.5, [:star5], 10),
        xlabel="t/t0",
        ylabel="Data",
        label="q3_1",
        legendfontsize = 10,
        tickfont = (12, "Arial"),
        guidefont = (18, "Arial"),
        legend = :topright,
        # bg = RGB(0.2, 0.2, 0.2),
		# ylim = (0, 0.02)
    )
end

# ╔═╡ Cell order:
# ╟─3a80dbae-59b8-11eb-11c8-1b4ed01e73f5
# ╟─1151bf70-865e-11eb-044e-6d28c3bfce41
# ╟─11851990-8660-11eb-29a3-553867ba8c75
# ╠═f5c0cd40-59b8-11eb-1ade-234f67f7efab
# ╟─4ebc1620-865a-11eb-1e0d-cd2669b2acad
# ╠═12901690-8684-11eb-2978-3f4b6f0d0fc4
# ╠═0ec47530-59b9-11eb-0c49-2b70d7e37d4d
# ╠═3e139540-7b6b-11eb-0671-c5e4c87e6b21
# ╟─57585d80-7b6e-11eb-18b3-339ab0f601af
# ╠═83464630-7b6b-11eb-0611-2bffbe393b19
# ╠═77b24122-7b6b-11eb-2036-41d8d55f985a
# ╠═598d0cd2-59b9-11eb-0a8b-a1938e2c3c43
# ╟─751f6650-7ce1-11eb-3bfe-a1f01e765cf4
# ╠═d8a75470-7ce2-11eb-356d-63c3da69b9f0
# ╠═f6d13570-8281-11eb-0f64-771e22a6b27d
# ╟─268c8790-8284-11eb-0511-e367b9211e74
# ╠═378cfcd0-8349-11eb-1ad0-8939849c2c1e
# ╠═a13e4120-8641-11eb-0c7b-b366d42b115c
# ╟─f5076320-834b-11eb-3d3d-0380c1997163
# ╠═0ed0c180-834b-11eb-3f40-b1243e850675
# ╠═56e7d3e2-859f-11eb-26ec-996629c4b3d1
# ╠═3de90bb0-8654-11eb-1d63-6324f3d13170
# ╠═edbffab0-85a2-11eb-1928-690f7101c1ff
# ╠═e1feb1d0-85a7-11eb-0f66-dd1f03ccd405
