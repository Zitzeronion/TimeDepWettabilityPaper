### A Pluto.jl notebook ###
# v0.17.0

using Markdown
using InteractiveUtils

# ╔═╡ f5c0cd40-59b8-11eb-1ade-234f67f7efab
using DataFrames, CSV, Plots, HTTP, DataFramesMeta, Query

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

# ╔═╡ dc6948b9-7769-45c3-aed2-c5cc5e47ca1e
begin
	# Plots default fonts and font sizes, could add colors as well
	leg_size = 12
	tick_size = 14
	label_size = 18
	# And surface tension
	γ = 0.01
end

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

Below a **CSV** file is loaded which contains the Δh information and stored in DataFrame formate as `df_delta_h`.
A quick sanity check is to count the number of lines in the file.
For every simulation we save 1000 columns of heigth data, therefore
```math
N = 1000 × Nₚ × Nᵩ × Nᵥ ≝ 24000,  
```
because we have 2 patterns, 3 wavelenghts (Nᵩ) and 4 velocities.

A second csv file is loaded as well to get the data for the clusters.
Clusters in this sense are droplets or isolated regions of liquid.
This can be found in `df_clusters` where *N_clusters* is the number of disconncted fluid regions and *A_clusters* is a list that stores the respective area of the cluster. 
In the first row *N_clusters* = 1 which means the fluid is simply connected. 
The *A_clusters* column measures the dry phase as first element followed by the area of the disjoint clusters.
Since there is just one cluster and no dry phase *A_clusters* = [0, 512²].
"

# ╔═╡ 12901690-8684-11eb-2978-3f4b6f0d0fc4
df_delta_h = CSV.File(HTTP.get("https://jugit.fz-juelich.de/s.zitz/timedependent_wettability/-/raw/master/Data_CSV/height_differences.csv?inline=false").body) |> DataFrame

# ╔═╡ 61793e10-8e47-11eb-3bf4-cd92fdcc2a1d
df_clusters = CSV.File(HTTP.get("https://jugit.fz-juelich.de/s.zitz/timedependent_wettability/-/raw/master/Data_CSV/Clusters.csv?inline=false").body) |> DataFrame

# ╔═╡ e4395f40-870a-11eb-3c7f-435231c70f87
md"Okay the file got 24000 entries, which is consistent with our enumeration.

Now we want to dig into the data.
First thing we can easily access is the influence of the **wavelenght** λₜ (we use subscript t because it renders while θ does not) of the pattern.

Below we plot the **Δh** and **Nᵨ** the number of clusters for the three wavelengths 512, 256 & 171. 
As expected the stability (sharp jump in Δh) will reduce with decreasing wavelenght.
"

# ╔═╡ 9f546962-2798-4452-befa-883326271887
@recipe function f(::Type{Val{:samplemarkers}}, x, y, z; step = 10)
    n = length(y)
    sx, sy = x[1:step:n], y[1:step:n]
    # add an empty series with the correct type for legend markers
    @series begin
        seriestype := :path
        markershape --> :auto
        x := [Inf]
        y := [Inf]
    end
    # add a series for the line
    @series begin
        primary := false # no legend entry
        markershape := :none # ensure no markers
        seriestype := :path
        seriescolor := get(plotattributes, :seriescolor, :auto)
        x := x
        y := y
    end
    # return  a series for the sampled markers
    primary := false
    seriestype := :scatter
    markershape --> :auto
    x := sx
    y := sy
end

# ╔═╡ b6b8f109-ab0b-4a9e-a82e-7f510f1c8974
md"
### No Pattern velocity

Concerning the plot above we can learn that the maximal height difference is corrolated with the pattern.
If the wavelength is similar to the full pattern we generate **two** droplets in the region of minimal contact angle.
The same idea applies to the other wavelengths. 
If there are **eight** contact angle minimia we create eight stabel droplets.
With the shortest wavelenght we observe **eighteen** stabel droplets.

To put this in math, we know that the droplets will be of spherical cap shape.
By measuring the maximal height *hₘ* as well as the base area  of the cap (the area of the clusters) we can compute all other relevant parameters, e.g. the contact angle θ at the three phase contact line or the volume of the droplet.
The equations are as follows
```math
r = \sqrt{\frac{A_{\text{base}}}{\pi}},
```
where we approximate the base as a circle.
The volume of a droplet can than be computed using the height *hₘ* and *r* as
```math
V = \frac{1}{6}\pi h (3r^2 + h^2).
```

The surface area of the cap can be computed using
```math
A = \pi(r^2 + h^2).
```
Another helpful relation links the sphere radius $R$ with the cap radius $r$ as
```math
R = \frac{r^2 + h^2}{2h}.
```
This helps finding the contact angle which can be compute according to
```math
\theta = \cos^{-1}\left(1 - \frac{A}{2\pi R^2}\right),
```
upon inserting $A$ and $R$ we find a relation for θ that only depends on $r$ and $h$ 
```math
\theta = \cos^{-1}\left(1 - \frac{2h^2}{r^2 + h^2}\right).
```

Below we take just a small section of the full data and consider only **λ=512** with **sine pattern** and no pattern velocity **vₜ=0** .
There we take a look a the height difference Δh and the base area to calculate the droplets contact angle.

"

# ╔═╡ 3be4828d-01f7-4450-8133-a429bb59ed62
h_lam1_sine_v0 = @linq df_delta_h |>
	where(:velocities .== 0.0) |>
	where(:lambda .== 3) |>
	where(:pattern .== "sine") |>
	select(:h_mins, :h_max, :dh)

# ╔═╡ 5eb88736-3ea8-458e-8091-58319ad37dc1
clust_lam1_sine_v0 = @linq df_clusters |>
		where(:velocities .== 0.0) |>
		where(:lambda .== 1) |>
		where(:pattern .== "sine") |>
		select(:N_clusters, :A_clusters)

# ╔═╡ 6e719113-62d9-4119-a2aa-160b8854134a
md"
The function below computes the droplets surface area, volume and contact angle based on the wetted area and Δh.
"

# ╔═╡ 081746e8-25b1-4c55-99ce-fd7e38dd9fe4
"""
	drop_stats(area, height)

Function to compute the droplet volume, surface area and contact angle.

Based on the height and the base surface area the spherical caps volume, surface area and contact angle are computed.
"""
function drop_stats(area, height)
	rad = sqrt(area/π)
	R = (rad^2 + height^2)/(2*height)
	vol = 1/6*π*height*(3*rad^2 + height^2)
	
	s_area = π*(rad^2 + height^2)
	
	angle = acos(1 - (2*height^2/(rad^2 + height^2)))
	
	return vol, s_area, rad2deg(angle), angle
end

# ╔═╡ 3ac50706-59e0-473f-85ef-558afce47549
drop_lam1_sine_v0 = drop_stats(5129, h_lam1_sine_v0.dh[end])
# drop_lam1_sine_v0 = drop_stats(5023, h_lam1_sine_v0.dh[end])

# ╔═╡ 479b39f9-8650-468c-a67e-c699fd00a7fa
md"
So what should we expect and what do we get?
Assuming that all of the fluids volume is accumulated inside the droplets we can, based on the contact angle, calculate the droplets height and compare it with our measurements.
This is done in the tabel below, where theory θ is a guess,

| λ    | theory h | measurement h | theory θ | measurement θ | error h | 
|---   |--------- | ------------- | -------- | ------------- | ------- |
|  L   | 11.3     | 10.8          | 15       | 14            | 0.5     |
| L/2  | 7.1      | 7.4           | 15       | 16            | 0.3     |  
| L/3  | 5.4      | 5.9           | 15       | 17            | 0.4     |

The theoretical assumptions and our measurements are not that far off.
In fact there is quite a good agreement between simulation and theory.

Okay that was a lot of checking for the consistency of the default state.
The droplet radii and contact angles seem to be at least not way of.

Here again a much nicer plot of the vₜ = 0 case for the three wavelenghts λ
"

# ╔═╡ 79d92592-f849-4083-81ef-35502939deda
begin	
	# Split the data into seperate arrays
	h_lam1_v0 = @linq df_delta_h |>
		where(:velocities .== 0) |>
		where(:lambda .== 1) |>
		where(:pattern .== "sine") |>
		select(:dh, :time)
	h_lam2_v0 = @linq df_delta_h |>
		where(:velocities .== 0) |>
		where(:lambda .== 2) |>
		where(:pattern .== "sine") |>
		select(:dh, :time)
	h_lam3_v0 = @linq df_delta_h |>
		where(:velocities .== 0) |>
		where(:lambda .== 3) |>
		where(:pattern .== "sine") |>
		select(:dh, :time)
	# A global time axis, all simulation did run up to roughly 30t₀
	x_time = h_lam1_v0.time
	# Restructure them into a single array for easier plotting
	h_v0_all_lam = zeros(length(h_lam1_v0.dh), 3)
	h_v0_all_lam[:,1] .= h_lam1_v0.dh
	h_v0_all_lam[:,2] .= h_lam2_v0.dh
	h_v0_all_lam[:,3] .= h_lam3_v0.dh
	# Some cosmetics
	mks_v0 = [:circle :rect :star5]
	labs_v0 = ["λ=L" "λ=L/2" "λ=L/3"]
	# The plot
	v0_plot = plot(x_time, 							# x-axis
		       h_v0_all_lam,     					# y-axis 
		       label=labs_v0, 						# labels
		       xlabel="t/t₀", 						# x-axis label
		       ylabel="Δh",							# y-axis label
			   w = 3, 								# line width
			   st = :samplemarkers, 				# some recipy stuff
		       step = 50, 							# density of markers
			   marker = (8, mks_v0, 0.6),			# marker size
			   legendfontsize = leg_size,			# legend font size
               tickfont = (tick_size, "Arial"),		# tick font and size
               guidefont = (label_size, "Arial"),	# label font and size
			   grid = :none,						# grid variable
			   legend=:bottomright)					# legend position
	# Lines that indicate some assumption
	hline!([10.78], line = (4, :dash, 0.5, palette(:default)[1]), label="")
	hline!([7.4], line = (4, :dash, 0.5, palette(:default)[2]), label="")
	hline!([5.9], line = (4, :dash, 0.5, palette(:default)[3]), label="")
end

# ╔═╡ f92a3bdf-2209-47be-8881-2a0567607b80
md"In the following we want to print our findings to some, preferably, `.svg` file. 
Important this format is vector and can be modified quite easily with e.g. *Inkscape*.
Additionally all fonts can be printed with svg output while the pdf format eats up some special characters, such as θ.

Independent of the operating system plots should be stored within the repo files.
That is why we ask the what operating system we are on.
- Windows: lots of `\\`
- Linux: only on `/`

Which is done before we save the first plot."

# ╔═╡ e156c4d1-279f-4073-aa21-5840b8554482
# Need this for plotting purposes
begin
	os = true
	if Sys.iswindows()
		os = false
	elseif Sys.islinux()
		os = true
	end
end

# ╔═╡ 3d56e346-49b8-4e86-b43d-2d812c94c072
if os
	savefig(v0_plot, "../Figures/v0_dh_sine_with_const.svg")
else
	savefig(v0_plot, "..\\Figures\\v0_dh_sine_with_const.svg")
end

# ╔═╡ fafe381e-0baf-40c1-b127-67b7f8c1a902
begin
	c_v0_all_lam = zeros(length(x_time), 3)
	for i in 1:3
		C_lam_sin_v0 = @linq df_clusters |>
			where(:velocities .== 0) |>
			where(:lambda .== i) |>
			where(:pattern .== "sine") |>
			select(:N_clusters, :A_clusters)
		c_v0_all_lam[:,i] .= C_lam_sin_v0.N_clusters
	end
	
	# Some cosmetics
	mks_v0_c = [:circle :rect :star5]
	labs_v0_c = ["λ=L" "λ=L/2" "λ=L/3"]
	# The plot
	c_v0_plot = plot(x_time,		 				# x-axis
		       c_v0_all_lam,     					# y-axis     
		       label=labs_v0_c, 					# labels
		       xlabel="t/t₀", 						# x-axis label
		       ylabel="N",							# y-axis label
			   w = 3, 								# line width
			   st = :samplemarkers, 				# some recipy stuff
		       step = 50, 							# density of markers
			   marker = (8, mks_v0_c, 0.6),			# marker size
			   legendfontsize = leg_size,			# legend font size
               tickfont = (tick_size, "Arial"),		# tick font and size
               guidefont = (label_size, "Arial"),	# label font and size
			   grid = :none,						# grid variable
			   legend=:topright)					# legend position
	# Theory
	hline!([2], line = (4, :dash, 0.5, palette(:default)[1]), label="")
	hline!([8], line = (4, :dash, 0.5, palette(:default)[2]), label="")
	hline!([18], line = (4, :dash, 0.5, palette(:default)[3]), label="")
end

# ╔═╡ cc64aa01-953e-49fd-8301-9be1f244437d
if os
	savefig(c_v0_plot, "../Figures/v0_clusters_sine.svg")
else
	savefig(c_v0_plot, "..\\Figures\\v0_clusters_sine.svg")
end

# ╔═╡ e82faaad-5278-4d8f-982b-fca335bbd006
md"
### Pattern velocity vₜ > 0

Now comes the fun part we start looking into the case where the substates pattern θ(x) becomes θ(x,t).
We start by taking a single wavelength and check the differences as a function of time.
First though for a nice data display we use a plots recipy taken from [here](https://github.com/JuliaPlots/Plots.jl/issues/2523).
This recipy allows to have the very convenient `markevery` function in plots, similar to the one used in *Pythons Matplotlib*
"

# ╔═╡ 6a5f4405-f63c-4fff-b692-e2bbe396ed7a
begin
	lam1_sin_all_v = zeros(length(x_time), 4)
	for v in enumerate([0 0.1 1 10])
		lam1_sin_vx = @linq df_delta_h |>
			where(:velocities .== v[2]) |>
			where(:lambda .== 1) |>
			where(:pattern .== "sine") |>
			select(:dh, :time)
		lam1_sin_all_v[:,v[1]] .= lam1_sin_vx.dh
	end
	
	# Some cosmetics
	mks_lam1= [:circle :rect :star5 :diamond]
	labs_lam1 = ["vₜ=0" "vₜ=0.1v₀" "vₜ=1v₀" "vₜ=10v₀"]
	# The plot
	fig_lam1 = plot(x_time, 							# x-axis
		            lam1_sin_all_v,     				# y-axis     
		            label=labs_lam1, 					# labels
		            xlabel="t/t₀", 						# x-axis label
		            ylabel="Δh",						# y-axis label
			        w = 3, 								# line width
			        st = :samplemarkers, 				# some recipy stuff
		            step = 50, 							# density of markers
			        marker = (8, :auto, 0.6),			# marker size
			        legendfontsize = leg_size,			# legend font size
                    tickfont = (tick_size, "Arial"),	# tick font and size
                    guidefont = (label_size, "Arial"),	# label font and size
			        grid = :none,						# grid variable
			        legend=:bottomright)				# legend position
end

# ╔═╡ bb659f3a-0a01-4f40-81ce-a8c13a34250b
# Here the command to save the figure
if os
	savefig(fig_lam1, "../Figures/dh_t_lam1_all_v.svg")
else
	savefig(fig_lam1, "..\\Figures\\dh_t_lam1_all_v.svg")
end

# ╔═╡ 0ec47530-59b9-11eb-0c49-2b70d7e37d4d
md"""
### Rupture times

After the initial checking of the stationary pattern we take a look at the rupture times $\tau_r$.
So far we have confirmed that the pattern minima enumerate the number of droplets after dewetting and the height of the stationary droplets are in the range where we expect them.

The rupture times have been computed using the time resolved height data.
We define the rupture as
```math
\tau_r = min_t\{h(x,t) \le h_{\ast}\},
```
and save to a file.
We can simply load a '.csv' file and import it as a dataframe.

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
md" ### Distribution of rupture times

First we like to analyse the stability of the film, thus how long does it the take the film to rupture.
Since it is a spinodally dewetting system we know that it will rupture.
On top of that we have a wettability gradient θ(x) which generates a flow.

For this project we generated two patterns.
The first one is a sine wave pattern given as
```math
 \theta_1(x,y) = \theta_0 + \delta\theta\left[\sin\left(\frac{2\pi i x}{\lambda}\right)\sin\left(\frac{2\pi j y}{\lambda}\right)\right], 
```
where $i$ and $j$ are wavenumbers.
In this work we use $i = j \in(1,2,3)$.
On the other hand we use a triangle wave given as 
```math
\theta_2(x,y) = \theta_0 + \frac{2\delta\theta}{\pi}\left[\sin^{-1}\left(\sin\left(\frac{2\pi i x}{\lambda}\right)\right)\sin^{-1}\left(\sin\left(\frac{2\pi j y}{\lambda}\right)\right)\right].
```

Previous research have found a stabilizing effect due to a time dependency on θ(x,t).
This is what we are going to take a look at in the next few plots.

First we look at the τᵣ, the rupture time, against the substrates pattern wavelength λ for pattern $\theta_1$.
This is displayed in the plot below.

"

# ╔═╡ d2fba1b6-bcd4-457e-82e1-3c9fa2922ba4
begin
	
	rts_sine = zeros(4,3)
	for i in 1:3
		hmm = []
		for v in enumerate([0.0 0.1 1.0 10.0])
			dummy = @linq df_rup_times |>
			where(:velocities .== v[2]) |>
			where(:lambda .== i) |>
			where(:pattern .== "sine") |>
			select(:rupture_times)
			push!(hmm, dummy.rupture_times[1])
			
		end
		rts_sine[:,i] .= hmm
	end
	vels = [0.0, 0.1, 1.0, 10.0]
	lambdas = [1, 0.5, 1/3]
	labels_lam = ["λ=L" "λ=L/2" "λ=L/3"]
	labels_vel = ["v=0" "v=0.1v₀" "v=1v₀" "v=10v₀"]
	# Plotting the data
	scatter(vels,								# x-data 
		    rts_sine,							# y-data
			xlabel="v/v₀",						# x-label
			ylabel="τᵣ/t₀",						# y-label
			# yaxis=:log,						# yaxis scaling
		    marker = (8, :auto, 0.6),			# markers(size, symbol, α)
			label=labels_lam, 					# labels
			legendfontsize = leg_size,			# legend font size
            tickfont = (tick_size, "Arial"),	# tick font and size
            guidefont = (label_size, "Arial"),	# label font and size
			grid = :none,						# grid variable
			legend=:right,						# legend position
		    )
end

# ╔═╡ fd0ed361-6317-48aa-b01e-34613db17ed1
md" To see if there some scaling law we can display the graph as a loglog like graph

But we need to modify the x-axis as it contains zero.
We know that the vₜ = 0.1v₀ ≈ 15000 Δt, adding a zero would mean the pattern is update about every 150k time steps.
Since the simulation is running for 5×10⁶ Δt we use instead of 0 -> 0.001"

# ╔═╡ b11ddc3c-0820-4cc3-b7e1-c67407a87685
begin
	v_scale = [0.001, 0.1, 1.0, 10.0]
	scatter(v_scale,							# x-data 
		    rts_sine,							# y-data
			xlabel="v/v₀",						# x-label
			ylabel="τᵣ/t₀",						# y-label
			yaxis=:log,							# yaxis scaling
			xaxis=:log,							# xaxis scaling
		    marker = (8, :auto, 0.6),			# markers(size, symbol, α)
			label=labels_lam, 					# labels
			legendfontsize = leg_size,			# legend font size
            tickfont = (tick_size, "Arial"),	# tick font and size
            guidefont = (label_size, "Arial"),	# label font and size
			grid = :none,						# grid variable
			legend=:left,						# legend position
		    )
end

# ╔═╡ 4117f552-f93d-4de4-819b-d1e352a9e182
md"In the next cell below we do not resolve the rupture time as a function of velocity but as a function of wavelength λ.
This of course means that we have now 4 points instead of three and only three x-values.

With this plot however it is much clearer that a pattern velocity has a stabilizing effect on the thin film.
The message is that the film on static contact angle field ruptures first."

# ╔═╡ 83464630-7b6b-11eb-0611-2bffbe393b19
begin
	# Shift velocity with wavelength dependency
	rts_sine2 = permutedims(rts_sine,(2,1))
	# Plot the shifted data
	scatter(lambdas, 							# x-data
		    rts_sine2,							# y-data
			xlabel="λ",							# xaxis label
			ylabel="τᵣ/t₀",						# yaxis label
		    marker = (8, :auto, 0.6),			# markers
			label=labels_vel, 					# labels
			legendfontsize = leg_size,			# legend font size
            tickfont = (tick_size, "Arial"),	# tick font and size
            guidefont = (label_size, "Arial"),	# label font and size
			grid = :none,						# grid variable
			legend=:topleft,					# legend position
		    )
end

# ╔═╡ c9ee5190-d362-43f9-94e7-de9b395d55fb
md"Here as well we check for some kind of scaling law that means we transform the axis to be displayed as log-scaled"

# ╔═╡ fff30b64-d5bb-41df-91bc-ebb2492981ec
rts_save = scatter(lambdas,							# x-data 
		rts_sine2,							# y-data
	    xlabel="λ",							# xaxis label
		ylabel="τᵣ/t₀",						# yaxis label
		xaxis=:log,							# xaxis scaling
		yaxis=:log,							# yaxis scaling
		marker = (8, :auto, 0.6),			# markers
		label=labels_vel, 					# labels
		legendfontsize = leg_size,			# legend font size
        tickfont = (tick_size, "Arial"),	# tick font and size
        guidefont = (label_size, "Arial"),	# label font and size
		grid = :none,						# grid variable
		legend=:topleft,					# legend position
		    )

# ╔═╡ 13eaf81b-3e3c-4678-a644-0d6aa5629188
if os
	savefig(rts_save, "../Figures/rupture_time.svg")
else
	savefig(rts_save, "..\\Figures\\rupture_time.svg")
end

# ╔═╡ 9d84d4e2-d81d-4874-a656-8ff2624a7f1d
md"### Linear pattern
Besides the sine wave pattern we have data on a linear pattern as well using the θ₂ pattern.
"

# ╔═╡ 7344c1d9-5d87-4b4d-8264-3043b162c49f
begin
	
	rts_lin = zeros(4,3)
	for i in 1:3
		hmm = []
		for v in enumerate([0.0 0.1 1.0 10.0])
			dummy = @linq df_rup_times |>
			where(:velocities .== v[2]) |>
			where(:lambda .== i) |>
			where(:pattern .== "linear") |>
			select(:rupture_times)
			push!(hmm, dummy.rupture_times[1])
			
		end
		rts_lin[:,i] .= hmm
	end
	
	# Plotting the data
	scatter(vels,								# x-data 
		    rts_lin,							# y-data
			xlabel="v/v₀",						# x-label
			ylabel="τᵣ/t₀",						# y-label
			# yaxis=:log,						# yaxis scaling
		    marker = (8, :auto, 0.6),			# markers(size, symbol, α)
			label=labels_lam, 					# labels
			legendfontsize = leg_size,			# legend font size
            tickfont = (tick_size, "Arial"),	# tick font and size
            guidefont = (label_size, "Arial"),	# label font and size
			grid = :none,						# grid variable
			legend=:right,						# legend position
		    )
end

# ╔═╡ 4227b4c1-8629-4062-b9d7-1c87b522c761
begin
	# Shift velocity with wavelength dependency
	rts_lin2 = permutedims(rts_lin,(2,1))
	# Plot the shifted data
	scatter(lambdas, 							# x-data
		    rts_lin2,							# y-data
			xlabel="λ",							# xaxis label
			ylabel="τᵣ/t₀",						# yaxis label
		    marker = (8, :auto, 0.6),			# markers
			label=labels_vel, 					# labels
			legendfontsize = leg_size,			# legend font size
            tickfont = (tick_size, "Arial"),	# tick font and size
            guidefont = (label_size, "Arial"),	# label font and size
			grid = :none,						# grid variable
			legend=:topleft,					# legend position
		    )
end

# ╔═╡ 17da9ce0-e748-4bb3-aed4-f33da671aa48
md"However we still like to know a little more, concerning the wavelength λ we only got 4 points. 

That is why there is more data conerning the rupture time with smaller wavelengths.
Loading the data is as simple as above, with the `HTTP` and `DataFrames` packages."

# ╔═╡ df5a3c48-f994-4a84-beca-f079420a1bbf
df_rup_more_lam = CSV.File(HTTP.get("https://jugit.fz-juelich.de/s.zitz/timedependent_wettability/-/raw/master/Data_CSV/Rupture_data_sin_pattern_multiple_lambda.csv?inline=false").body) |> DataFrame

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
# Data that has been computed
# ===========================
# Sine_data = CSV.File(HTTP.get("https://jugit.fz-juelich.de/s.zitz/timedependent_wettability/-/raw/master/Data_CSV/Sine_waves_data.csv?inline=false").body) |> DataFrame

# ╔═╡ f6d13570-8281-11eb-0f64-771e22a6b27d
# Data that has been computed
# ===========================
# Triangle_data = CSV.File(HTTP.get("https://jugit.fz-juelich.de/s.zitz/timedependent_wettability/-/raw/master/Data_CSV/Linear_waves_data.csv?inline=false").body) |> DataFrame

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
t₀ = \frac{3μ}{γh₀³q₀⁴},
```
with q₀ being
```math
q₀² = \frac{Π'(h₀)}{2},
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

#### Data $\lambda = 1$, $v_{\theta} = 0$, threshold=15, pattern=sine
Yes there are just 998 *datapoints*, this is due to some abiguity in papaya2 when it comes to time step **10** and time step **100**. Had no time to look into this yet.
"

# ╔═╡ b4879bcc-51de-46fc-892b-c2bcf44e21b3
begin
	lam = 1
	thresh = 15
	vel = 0.0
	vel_cont = 1.0
	pat = 1
	l1_sin_0 = @linq all_data |>
		where(:threshold .== thresh) |>
		where(:lambda .== lam) |>
		where(:vel_norm .== vel) |>
		where(:pattern .== pat) |>
		select(:q2, :q3, :q4, :q5, :q6, :q7, :q8, :isoperi_ratio, :anisotro_ind, :t_norm)
end

# ╔═╡ a02e45b0-bc1b-4210-9f2f-ae72ed92357b
md"Since the set with no pattern velocity is not instructive, as the dewetting is unidirectional we take a look something more interesting.

In the following we plot the series of q₂ values for the three wavelenghts based on their substrate velocity.
What we expect is that the lingament or rivulet states show a strong q₂ component."

# ╔═╡ 0ed0c180-834b-11eb-3f40-b1243e850675
begin
	q2_data_lam1 = zeros(998, 4)
	for i in enumerate([0.0 0.1 1.0 10.0])
		filtered = @linq all_data |>
			where(:threshold .== thresh) |>
			where(:lambda .== lam) |>
			where(:vel_norm .== i[2]) |>
			where(:pattern .== pat) |>
			select(:q2, :q3, :q4, :q5, :q6, :q7, :q8, :isoperi_ratio, :anisotro_ind, :t_norm)
		replace!(filtered.q2, NaN => 0.0)
		q2_data_lam1[:, i[1]] = filtered.q2
	end
	plot(l1_sin_0.t_norm,		 			# x-axis
		 q2_data_lam1,	     				# y-axis     
		 label=labs_lam1, 					# labels
		 xlabel="t/t₀", 					# x-axis label
		 ylabel="q₂",						# y-axis label
		 w = 3, 							# line width
		 st = :samplemarkers, 				# some recipy stuff
		 step = 50, 						# density of markers
		 marker = (8, :auto, 0.6),			# marker size
		 legendfontsize = leg_size,			# legend font size
         tickfont = (tick_size, "Arial"),	# tick font and size
         guidefont = (label_size, "Arial"),	# label font and size
	     grid = :none,						# grid variable
		 title="Sine λ=1",
		 legend=:topright)				    # legend position
end

# ╔═╡ affe8679-f56c-4564-b6c9-d4e17f890a12
begin
	wave_here = 3
	q2_data_lam1_lin = zeros(998, 4)
	for i in enumerate([0.0 0.1 1.0 10.0])
		filtered = @linq all_data |>
			where(:threshold .== thresh) |>
			where(:lambda .== wave_here) |>
			where(:vel_norm .== i[2]) |>
			where(:pattern .== 2.0) |>
			select(:q2, :q3, :q4, :q5, :q6, :q7, :q8, :isoperi_ratio, :anisotro_ind, :t_norm)
		replace!(filtered.q2, NaN => 0.0)
		q2_data_lam1_lin[:, i[1]] = filtered.q2
	end
	plot(l1_sin_0.t_norm,		 			# x-axis
		 q2_data_lam1_lin,	     				# y-axis     
		 label=labs_lam1, 					# labels
		 xlabel="t/t₀", 					# x-axis label
		 ylabel="q₂",						# y-axis label
		 w = 3, 							# line width
		 st = :samplemarkers, 				# some recipy stuff
		 step = 50, 						# density of markers
		 marker = (8, :auto, 0.6),			# marker size
		 legendfontsize = leg_size,			# legend font size
         tickfont = (tick_size, "Arial"),	# tick font and size
         guidefont = (label_size, "Arial"),	# label font and size
	     grid = :none,						# grid variable
		 title="Lin. λ=$(wave_here)",
		 legend=:topright)				    # legend position
end

# ╔═╡ f40c617d-ce54-4788-bd23-bd8462469b11
begin
	lh = 2
	q2_data_lam2 = zeros(998, 4)
	for i in enumerate([0.0 0.1 1.0 10.0])
		filtered = @linq all_data |>
			where(:threshold .== thresh) |>
			where(:lambda .== lh) |>
			where(:vel_norm .== i[2]) |>
			where(:pattern .== pat) |>
			select(:q2, :q3, :q4, :q5, :q6, :q7, :q8, :isoperi_ratio, :anisotro_ind, :t_norm)
		replace!(filtered.q2, NaN => 0.0)
		q2_data_lam1[:, i[1]] = filtered.q2
	end
	q2_lam2_plot = plot(l1_sin_0.t_norm,		 			# x-axis
		 q2_data_lam1,	     				# y-axis     
		 label=labs_lam1, 					# labels
		 xlabel="t/t₀", 					# x-axis label
		 ylabel="q₂",						# y-axis label
		 w = 3, 							# line width
		 st = :samplemarkers, 				# some recipy stuff
		 step = 50, 						# density of markers
		 marker = (8, :auto, 0.6),			# marker size
		 legendfontsize = leg_size,			# legend font size
         tickfont = (tick_size, "Arial"),	# tick font and size
         guidefont = (label_size, "Arial"),	# label font and size
	     grid = :none,						# grid variable
		 title="Sine λ=$(lh)",
		 legend=:topright)					# legend position
end

# ╔═╡ ee710208-b363-42b3-b811-efed2dc963a9
savefig(q2_lam2_plot, "..\\Figures\\q2_lam2_MSM.pdf")

# ╔═╡ 920e803d-f050-4854-834b-21f0ad94e8b1
begin
	q2_data_lam3 = zeros(998, 4)
	for i in enumerate([0.0 0.1 1.0 10.0])
		filtered = @linq all_data |>
			where(:threshold .== thresh) |>
			where(:lambda .== 3) |>
			where(:vel_norm .== i[2]) |>
			where(:pattern .== pat) |>
			select(:q2, :q3, :q4, :q5, :q6, :q7, :q8, :isoperi_ratio, :anisotro_ind, :t_norm)
		replace!(filtered.q2, NaN => 0.0)
		q2_data_lam1[:, i[1]] = filtered.q2
	end
	q2_lam3_plot = plot(l1_sin_0.t_norm,		 			# x-axis
		 q2_data_lam1,	     				# y-axis     
		 label=labs_lam1, 					# labels
		 xlabel="t/t₀", 					# x-axis label
		 ylabel="q₂",						# y-axis label
		 w = 3, 							# line width
		 st = :samplemarkers, 				# some recipy stuff
		 step = 50, 						# density of markers
		 marker = (8, :auto, 0.6),			# marker size
		 legendfontsize = leg_size,			# legend font size
         tickfont = (tick_size, "Arial"),	# tick font and size
         guidefont = (label_size, "Arial"),	# label font and size
	     grid = :none,						# grid variable
		 title="Sine λ=3",
		 legend=:topright)					# legend position
end

# ╔═╡ 0ebaff68-636c-4d98-95ee-0d770aaf5499
savefig(q2_lam3_plot, "..\\Figures\\q2_lam3_MSM.pdf")

# ╔═╡ 0067688c-d991-4071-940f-73a8609c356c
md"Just to for the check we look if q₃ is as well elevated"

# ╔═╡ 1f4ec6d2-d458-4760-a3b6-4f41348dd178
begin
	q3_data_lam1 = zeros(998, 4)
	for i in enumerate([0.0 0.1 1.0 10.0])
		filtered = @linq all_data |>
			where(:threshold .== thresh) |>
			where(:lambda .== lam) |>
			where(:vel_norm .== i[2]) |>
			where(:pattern .== pat) |>
			select(:q2, :q3, :isoperi_ratio, :anisotro_ind, :t_norm)
		replace!(filtered.q3, NaN => 0.0)
		q3_data_lam1[:, i[1]] = filtered.q3
	end
	plot(l1_sin_0.t_norm,		 			# x-axis
		 q3_data_lam1,	     				# y-axis     
		 label=labs_lam1, 					# labels
		 xlabel="t/t₀", 					# x-axis label
		 ylabel="q₃",						# y-axis label
		 w = 3, 							# line width
		 st = :samplemarkers, 				# some recipy stuff
		 step = 50, 						# density of markers
		 marker = (8, :auto, 0.6),			# marker size
		 legendfontsize = leg_size,			# legend font size
         tickfont = (tick_size, "Arial"),	# tick font and size
         guidefont = (label_size, "Arial"),	# label font and size
	     grid = :none,						# grid variable
		 title="Sine λ=1",
		 legend=:topright)					# legend position
end

# ╔═╡ b45279f3-05f5-4933-a08c-8e7e4b5c7ce5
begin
	q3_data_lam2 = zeros(998, 4)
	for i in enumerate([0.0 0.1 1.0 10.0])
		filtered = @linq all_data |>
			where(:threshold .== thresh) |>
			where(:lambda .== 2) |>
			where(:vel_norm .== i[2]) |>
			where(:pattern .== pat) |>
			select(:q2, :q3, :isoperi_ratio, :anisotro_ind, :t_norm)
		replace!(filtered.q3, NaN => 0.0)
		q3_data_lam2[:, i[1]] = filtered.q3
	end
	q3_lam2 = plot(l1_sin_0.t_norm,		 			# x-axis
		 q3_data_lam2,	     				# y-axis     
		 label=labs_lam1, 					# labels
		 xlabel="t/t₀", 					# x-axis label
		 ylabel="q₃",						# y-axis label
		 w = 3, 							# line width
		 st = :samplemarkers, 				# some recipy stuff
		 step = 50, 						# density of markers
		 marker = (8, :auto, 0.6),			# marker size
		 legendfontsize = leg_size,			# legend font size
         tickfont = (tick_size, "Arial"),	# tick font and size
         guidefont = (label_size, "Arial"),	# label font and size
	     grid = :none,						# grid variable
		 # title="Sine λ=2",
		 legend=:topright)					# legend position
end

# ╔═╡ 8682aebe-44ee-4a06-a245-3863f9b8b090
savefig(q3_lam2, "..\\Figures\\q3_lam2.svg")

# ╔═╡ fcae1759-26d7-4bd6-b46e-f4a84d3b366c
begin
	q3_data_lam3 = zeros(998, 4)
	for i in enumerate([0.0 0.1 1.0 10.0])
		filtered = @linq all_data |>
			where(:threshold .== thresh) |>
			where(:lambda .== 3) |>
			where(:vel_norm .== i[2]) |>
			where(:pattern .== pat) |>
			select(:q2, :q3,:isoperi_ratio, :anisotro_ind, :t_norm)
		replace!(filtered.q3, NaN => 0.0)
		q3_data_lam3[:, i[1]] = filtered.q3
	end
	plot(l1_sin_0.t_norm,		 			# x-axis
		 q3_data_lam3,	     				# y-axis     
		 label=labs_lam1, 					# labels
		 xlabel="t/t₀", 					# x-axis label
		 ylabel="q₃",						# y-axis label
		 w = 3, 							# line width
		 st = :samplemarkers, 				# some recipy stuff
		 step = 50, 						# density of markers
		 marker = (8, :auto, 0.6),			# marker size
		 legendfontsize = leg_size,			# legend font size
         tickfont = (tick_size, "Arial"),	# tick font and size
         guidefont = (label_size, "Arial"),	# label font and size
	     grid = :none,						# grid variable
		 title="Sine λ=3",
		 legend=:top)						# legend position
end

# ╔═╡ dfc66579-f6f6-443e-aa42-3ecf7fe8f8cf
md"The classics of topology is the isoperimetric ratio

```math
Q = \frac{4πA}{P^2}.
```

Let's have a look at this quantity
"

# ╔═╡ 388f9c8a-4723-4056-a329-732591a70077
begin
	Q_lam1 = zeros(998, 4)
	for i in enumerate([0.0 0.1 1.0 10.0])
		filtered = @linq all_data |>
			where(:threshold .== thresh) |>
			where(:lambda .== 1) |>
			where(:vel_norm .== i[2]) |>
			where(:pattern .== pat) |>
			select(:isoperi_ratio, :anisotro_ind, :t_norm)
		replace!(filtered.isoperi_ratio, Inf => 1.0)
		Q_lam1[:, i[1]] = filtered.isoperi_ratio
	end
	
	norm_lam1 = Q_lam1[end, 1]
	
	plot(l1_sin_0.t_norm,		 			# x-axis
		Q_lam1 ./ norm_lam1,		     	# y-axis, normed
		 label=labs_lam1, 					# labels
		 xlabel="t/t₀", 					# x-axis label
		 ylabel="Q/Q₀",						# y-axis label
		 ylim=(0.6, 1.25),
		 # yaxis=:log,
		 # xaxis=:log,
		 w = 3, 							# line width
		 st = :samplemarkers, 				# some recipy stuff
		 step = 50, 						# density of markers
		 marker = (8, :auto, 0.6),			# marker size
		 legendfontsize = leg_size,			# legend font size
         tickfont = (tick_size, "Arial"),	# tick font and size
         guidefont = (label_size, "Arial"),	# label font and size
	     grid = :none,						# grid variable
		 legend=:bottomright)						# legend position
end

# ╔═╡ c457ddb6-e0af-49c2-bfc4-a8014bd12fbb
begin
	Q_lam2 = zeros(998, 4)
	for i in enumerate([0.0 0.1 1.0 10.0])
		filtered = @linq all_data |>
			where(:threshold .== thresh) |>
			where(:lambda .== 2) |>
			where(:vel_norm .== i[2]) |>
			where(:pattern .== pat) |>
			select(:isoperi_ratio, :anisotro_ind, :t_norm)
		replace!(filtered.isoperi_ratio, Inf => 1.0)
		Q_lam2[:, i[1]] = filtered.isoperi_ratio
	end
	# Droplet state vₜ = 0 
	norm_lam2 = Q_lam2[end, 1]
	
	plot(l1_sin_0.t_norm,		 			# x-axis
		 Q_lam2 ./ norm_lam2,	     		# y-axis     
		 label=labs_lam1, 					# labels
		 xlabel="t/t₀", 					# x-axis label
		 ylabel="Q/Q₀",						# y-axis label
		 # yaxis=:log,
		 ylim = (0.5, 1.5),
		 w = 3, 							# line width
		 st = :samplemarkers, 				# some recipy stuff
		 step = 50, 						# density of markers
		 marker = (8, :auto, 0.6),			# marker size
		 legendfontsize = leg_size,			# legend font size
         tickfont = (tick_size, "Arial"),	# tick font and size
         guidefont = (label_size, "Arial"),	# label font and size
	     grid = :none,						# grid variable
		 legend=:bottomright)				# legend position
end

# ╔═╡ e15b167a-b50a-4431-8a3b-a2a06341c1ea
begin
	Q_lam3 = zeros(998, 4)
	for i in enumerate([0.0 0.1 1.0 10.0])
		filtered = @linq all_data |>
			where(:threshold .== thresh) |>
			where(:lambda .== 3) |>
			where(:vel_norm .== i[2]) |>
			where(:pattern .== pat) |>
			select(:isoperi_ratio, :anisotro_ind, :t_norm)
		replace!(filtered.isoperi_ratio, Inf => 1.0)
		Q_lam3[:, i[1]] = filtered.isoperi_ratio
	end
	
	# Droplet state vₜ = 0 
	norm_lam3 = Q_lam3[end, 1]
	# Plot 
	plot(l1_sin_0.t_norm,		 			# x-axis
		 Q_lam3 ./ norm_lam3,	     		# y-axis     
		 label=labs_lam1, 					# labels
		 xlabel="t/t₀", 					# x-axis label
		 ylabel="Q/Q₀",						# y-axis label
		 # yaxis=:log,
		 ylim = (0.75,1.5),
		 w = 3, 							# line width
		 st = :samplemarkers, 				# some recipy stuff
		 step = 50, 						# density of markers
		 marker = (8, :auto, 0.6),			# marker size
		 legendfontsize = leg_size,			# legend font size
         tickfont = (tick_size, "Arial"),	# tick font and size
         guidefont = (label_size, "Arial"),	# label font and size
	     grid = :none,						# grid variable
		 legend=:bottomright)						# legend position
end

# ╔═╡ 24520c51-e2ee-46c8-9290-cd0ee586a571
md"### Maxima of q₂

Since we have a lot of data it is not always helpful to show more.
One simple but hopefully insightful metric is the maximal value of q₂
```math
	q_2 = \frac{|\psi_2|}{\psi_0},
```
where we take the maximum of the time dependent value.

" 

# ╔═╡ b20a43cf-873b-4c9d-a78b-9c447bfdd5cf
begin
	max_q2s = zeros(3,4)
	for ll in [1, 2, 3]
		for i in enumerate([0 0.1 1.0 10.0])
			filtered = @linq all_data |>
				where(:threshold .== thresh) |>
				where(:lambda .== ll) |>
				where(:vel_norm .== i[2]) |>
				where(:pattern .== pat) |>
				select(:q2)
			replace!(filtered.q2, NaN => 0.0)
			max_q2s[ll, i[1]] = maximum(filtered.q2)
		end
	end
	wa = [1,1,1,1,2,2,2,2,3,3,3,3]
	vss = repeat([0, 0.1, 1, 10],3)
	p1 = scatter(wa[1:4], vss[1:4], max_q2s[1,:], xlabel="λ", ylabel="vₜ", zlabel="maxᵪ")
	scatter!(wa[5:8], vss[5:8], max_q2s[2,:])
	scatter!(wa[8:12], vss[8:12], max_q2s[3,:])
	
end

# ╔═╡ 544a78ed-074b-47ee-965f-0f5d72ec82aa
max_q2s

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
CSV = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
DataFramesMeta = "1313f7d8-7da2-5740-9ea0-a2ca25f37964"
HTTP = "cd3eb016-35fb-5094-929b-558a96fad6f3"
Plots = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
Query = "1a8c2f83-1ff3-5112-b086-8aa67b057ba1"

[compat]
CSV = "~0.9.1"
DataFrames = "~1.2.2"
DataFramesMeta = "~0.9.1"
HTTP = "~0.9.14"
Plots = "~1.21.3"
Query = "~1.0.0"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

[[Adapt]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "84918055d15b3114ede17ac6a7182f68870c16f7"
uuid = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
version = "3.3.1"

[[ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"

[[Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[Bzip2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "19a35467a82e236ff51bc17a3a44b69ef35185a2"
uuid = "6e34b625-4abd-537c-b88f-471c36dfa7a0"
version = "1.0.8+0"

[[CSV]]
deps = ["CodecZlib", "Dates", "FilePathsBase", "Mmap", "Parsers", "PooledArrays", "SentinelArrays", "Tables", "Unicode", "WeakRefStrings"]
git-tree-sha1 = "c907e91e253751f5840135f4c9deb1308273338d"
uuid = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
version = "0.9.1"

[[Cairo_jll]]
deps = ["Artifacts", "Bzip2_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "JLLWrappers", "LZO_jll", "Libdl", "Pixman_jll", "Pkg", "Xorg_libXext_jll", "Xorg_libXrender_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "f2202b55d816427cd385a9a4f3ffb226bee80f99"
uuid = "83423d85-b0ee-5818-9007-b63ccbeb887a"
version = "1.16.1+0"

[[Chain]]
git-tree-sha1 = "cac464e71767e8a04ceee82a889ca56502795705"
uuid = "8be319e6-bccf-4806-a6f7-6fae938471bc"
version = "0.4.8"

[[CodecZlib]]
deps = ["TranscodingStreams", "Zlib_jll"]
git-tree-sha1 = "ded953804d019afa9a3f98981d99b33e3db7b6da"
uuid = "944b1d66-785c-5afd-91f1-9de20f533193"
version = "0.7.0"

[[ColorSchemes]]
deps = ["ColorTypes", "Colors", "FixedPointNumbers", "Random"]
git-tree-sha1 = "9995eb3977fbf67b86d0a0a0508e83017ded03f2"
uuid = "35d6a980-a343-548e-a6ea-1d62b119f2f4"
version = "3.14.0"

[[ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "024fe24d83e4a5bf5fc80501a314ce0d1aa35597"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.0"

[[Colors]]
deps = ["ColorTypes", "FixedPointNumbers", "Reexport"]
git-tree-sha1 = "417b0ed7b8b838aa6ca0a87aadf1bb9eb111ce40"
uuid = "5ae59095-9a9b-59fe-a467-6f913c188581"
version = "0.12.8"

[[Compat]]
deps = ["Base64", "Dates", "DelimitedFiles", "Distributed", "InteractiveUtils", "LibGit2", "Libdl", "LinearAlgebra", "Markdown", "Mmap", "Pkg", "Printf", "REPL", "Random", "SHA", "Serialization", "SharedArrays", "Sockets", "SparseArrays", "Statistics", "Test", "UUIDs", "Unicode"]
git-tree-sha1 = "4866e381721b30fac8dda4c8cb1d9db45c8d2994"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "3.37.0"

[[CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"

[[Contour]]
deps = ["StaticArrays"]
git-tree-sha1 = "9f02045d934dc030edad45944ea80dbd1f0ebea7"
uuid = "d38c429a-6771-53c6-b99e-75d170b6e991"
version = "0.5.7"

[[Crayons]]
git-tree-sha1 = "3f71217b538d7aaee0b69ab47d9b7724ca8afa0d"
uuid = "a8cc5b0e-0ffa-5ad4-8c14-923d3ee1735f"
version = "4.0.4"

[[DataAPI]]
git-tree-sha1 = "bec2532f8adb82005476c141ec23e921fc20971b"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.8.0"

[[DataFrames]]
deps = ["Compat", "DataAPI", "Future", "InvertedIndices", "IteratorInterfaceExtensions", "LinearAlgebra", "Markdown", "Missings", "PooledArrays", "PrettyTables", "Printf", "REPL", "Reexport", "SortingAlgorithms", "Statistics", "TableTraits", "Tables", "Unicode"]
git-tree-sha1 = "d785f42445b63fc86caa08bb9a9351008be9b765"
uuid = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
version = "1.2.2"

[[DataFramesMeta]]
deps = ["Chain", "DataFrames", "MacroTools", "Reexport"]
git-tree-sha1 = "29e71b438935977f8905c0cb3a8a84475fc70101"
uuid = "1313f7d8-7da2-5740-9ea0-a2ca25f37964"
version = "0.9.1"

[[DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "7d9d316f04214f7efdbb6398d545446e246eff02"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.10"

[[DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[DataValues]]
deps = ["DataValueInterfaces", "Dates"]
git-tree-sha1 = "d88a19299eba280a6d062e135a43f00323ae70bf"
uuid = "e7dc6d0d-1eca-5fa6-8ad6-5aecde8b7ea5"
version = "0.4.13"

[[Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[DelimitedFiles]]
deps = ["Mmap"]
uuid = "8bb1440f-4735-579b-a4ab-409b98df4dab"

[[Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"

[[Downloads]]
deps = ["ArgTools", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"

[[EarCut_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "3f3a2501fa7236e9b911e0f7a588c657e822bb6d"
uuid = "5ae413db-bbd1-5e63-b57d-d24a61df00f5"
version = "2.2.3+0"

[[Expat_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b3bfd02e98aedfa5cf885665493c5598c350cd2f"
uuid = "2e619515-83b5-522b-bb60-26c02a35a201"
version = "2.2.10+0"

[[FFMPEG]]
deps = ["FFMPEG_jll"]
git-tree-sha1 = "b57e3acbe22f8484b4b5ff66a7499717fe1a9cc8"
uuid = "c87230d0-a227-11e9-1b43-d7ebe4e7570a"
version = "0.4.1"

[[FFMPEG_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "JLLWrappers", "LAME_jll", "Libdl", "Ogg_jll", "OpenSSL_jll", "Opus_jll", "Pkg", "Zlib_jll", "libass_jll", "libfdk_aac_jll", "libvorbis_jll", "x264_jll", "x265_jll"]
git-tree-sha1 = "d8a578692e3077ac998b50c0217dfd67f21d1e5f"
uuid = "b22a6f82-2f65-5046-a5b2-351ab43fb4e5"
version = "4.4.0+0"

[[FilePathsBase]]
deps = ["Dates", "Mmap", "Printf", "Test", "UUIDs"]
git-tree-sha1 = "0f5e8d0cb91a6386ba47bd1527b240bd5725fbae"
uuid = "48062228-2e41-5def-b9a4-89aafe57970f"
version = "0.9.10"

[[FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "335bfdceacc84c5cdf16aadc768aa5ddfc5383cc"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.4"

[[Fontconfig_jll]]
deps = ["Artifacts", "Bzip2_jll", "Expat_jll", "FreeType2_jll", "JLLWrappers", "Libdl", "Libuuid_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "21efd19106a55620a188615da6d3d06cd7f6ee03"
uuid = "a3f928ae-7b40-5064-980b-68af3947d34b"
version = "2.13.93+0"

[[Formatting]]
deps = ["Printf"]
git-tree-sha1 = "8339d61043228fdd3eb658d86c926cb282ae72a8"
uuid = "59287772-0a20-5a39-b81b-1366585eb4c0"
version = "0.4.2"

[[FreeType2_jll]]
deps = ["Artifacts", "Bzip2_jll", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "87eb71354d8ec1a96d4a7636bd57a7347dde3ef9"
uuid = "d7e528f0-a631-5988-bf34-fe36492bcfd7"
version = "2.10.4+0"

[[FriBidi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "aa31987c2ba8704e23c6c8ba8a4f769d5d7e4f91"
uuid = "559328eb-81f9-559d-9380-de523a88c83c"
version = "1.0.10+0"

[[Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"

[[GLFW_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libglvnd_jll", "Pkg", "Xorg_libXcursor_jll", "Xorg_libXi_jll", "Xorg_libXinerama_jll", "Xorg_libXrandr_jll"]
git-tree-sha1 = "0c603255764a1fa0b61752d2bec14cfbd18f7fe8"
uuid = "0656b61e-2033-5cc2-a64a-77c0f6c09b89"
version = "3.3.5+1"

[[GR]]
deps = ["Base64", "DelimitedFiles", "GR_jll", "HTTP", "JSON", "Libdl", "LinearAlgebra", "Pkg", "Printf", "Random", "Serialization", "Sockets", "Test", "UUIDs"]
git-tree-sha1 = "182da592436e287758ded5be6e32c406de3a2e47"
uuid = "28b8d3ca-fb5f-59d9-8090-bfdbd6d07a71"
version = "0.58.1"

[[GR_jll]]
deps = ["Artifacts", "Bzip2_jll", "Cairo_jll", "FFMPEG_jll", "Fontconfig_jll", "GLFW_jll", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Libtiff_jll", "Pixman_jll", "Pkg", "Qt5Base_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "ef49a187604f865f4708c90e3f431890724e9012"
uuid = "d2c73de3-f751-5644-a686-071e5b155ba9"
version = "0.59.0+0"

[[GeometryBasics]]
deps = ["EarCut_jll", "IterTools", "LinearAlgebra", "StaticArrays", "StructArrays", "Tables"]
git-tree-sha1 = "58bcdf5ebc057b085e58d95c138725628dd7453c"
uuid = "5c1252a2-5f33-56bf-86c9-59e7332b4326"
version = "0.4.1"

[[Gettext_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Libiconv_jll", "Pkg", "XML2_jll"]
git-tree-sha1 = "9b02998aba7bf074d14de89f9d37ca24a1a0b046"
uuid = "78b55507-aeef-58d4-861c-77aaff3498b1"
version = "0.21.0+0"

[[Glib_jll]]
deps = ["Artifacts", "Gettext_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Libiconv_jll", "Libmount_jll", "PCRE_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "7bf67e9a481712b3dbe9cb3dac852dc4b1162e02"
uuid = "7746bdde-850d-59dc-9ae8-88ece973131d"
version = "2.68.3+0"

[[Graphite2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "344bf40dcab1073aca04aa0df4fb092f920e4011"
uuid = "3b182d85-2403-5c21-9c21-1e1f0cc25472"
version = "1.3.14+0"

[[Grisu]]
git-tree-sha1 = "53bb909d1151e57e2484c3d1b53e19552b887fb2"
uuid = "42e2da0e-8278-4e71-bc24-59509adca0fe"
version = "1.0.2"

[[HTTP]]
deps = ["Base64", "Dates", "IniFile", "Logging", "MbedTLS", "NetworkOptions", "Sockets", "URIs"]
git-tree-sha1 = "60ed5f1643927479f845b0135bb369b031b541fa"
uuid = "cd3eb016-35fb-5094-929b-558a96fad6f3"
version = "0.9.14"

[[HarfBuzz_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "Graphite2_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Pkg"]
git-tree-sha1 = "8a954fed8ac097d5be04921d595f741115c1b2ad"
uuid = "2e76f6c2-a576-52d4-95c1-20adfe4de566"
version = "2.8.1+0"

[[IniFile]]
deps = ["Test"]
git-tree-sha1 = "098e4d2c533924c921f9f9847274f2ad89e018b8"
uuid = "83e8ac13-25f8-5344-8a64-a9f2b223428f"
version = "0.5.0"

[[InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[InvertedIndices]]
git-tree-sha1 = "bee5f1ef5bf65df56bdd2e40447590b272a5471f"
uuid = "41ab1584-1d38-5bbf-9106-f11c6c58b48f"
version = "1.1.0"

[[IterTools]]
git-tree-sha1 = "05110a2ab1fc5f932622ffea2a003221f4782c18"
uuid = "c8e1da08-722c-5040-9ed9-7db0dc04731e"
version = "1.3.0"

[[IterableTables]]
deps = ["DataValues", "IteratorInterfaceExtensions", "Requires", "TableTraits", "TableTraitsUtils"]
git-tree-sha1 = "70300b876b2cebde43ebc0df42bc8c94a144e1b4"
uuid = "1c8ee90f-4401-5389-894e-7a04a3dc0f4d"
version = "1.0.0"

[[IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[JLLWrappers]]
deps = ["Preferences"]
git-tree-sha1 = "642a199af8b68253517b80bd3bfd17eb4e84df6e"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.3.0"

[[JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "8076680b162ada2a031f707ac7b4953e30667a37"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.2"

[[JpegTurbo_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "d735490ac75c5cb9f1b00d8b5509c11984dc6943"
uuid = "aacddb02-875f-59d6-b918-886e6ef4fbf8"
version = "2.1.0+0"

[[LAME_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "f6250b16881adf048549549fba48b1161acdac8c"
uuid = "c1c5ebd0-6772-5130-a774-d5fcae4a789d"
version = "3.100.1+0"

[[LZO_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "e5b909bcf985c5e2605737d2ce278ed791b89be6"
uuid = "dd4b983a-f0e5-5f8d-a1b7-129d4a5fb1ac"
version = "2.10.1+0"

[[LaTeXStrings]]
git-tree-sha1 = "c7f1c695e06c01b95a67f0cd1d34994f3e7db104"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.2.1"

[[Latexify]]
deps = ["Formatting", "InteractiveUtils", "LaTeXStrings", "MacroTools", "Markdown", "Printf", "Requires"]
git-tree-sha1 = "a4b12a1bd2ebade87891ab7e36fdbce582301a92"
uuid = "23fbe1c1-3f47-55db-b15f-69d7ec21a316"
version = "0.15.6"

[[LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"

[[LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"

[[LibGit2]]
deps = ["Base64", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"

[[Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[Libffi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "761a393aeccd6aa92ec3515e428c26bf99575b3b"
uuid = "e9f186c6-92d2-5b65-8a66-fee21dc1b490"
version = "3.2.2+0"

[[Libgcrypt_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgpg_error_jll", "Pkg"]
git-tree-sha1 = "64613c82a59c120435c067c2b809fc61cf5166ae"
uuid = "d4300ac3-e22c-5743-9152-c294e39db1e4"
version = "1.8.7+0"

[[Libglvnd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll", "Xorg_libXext_jll"]
git-tree-sha1 = "7739f837d6447403596a75d19ed01fd08d6f56bf"
uuid = "7e76a0d4-f3c7-5321-8279-8d96eeed0f29"
version = "1.3.0+3"

[[Libgpg_error_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "c333716e46366857753e273ce6a69ee0945a6db9"
uuid = "7add5ba3-2f88-524e-9cd5-f83b8a55f7b8"
version = "1.42.0+0"

[[Libiconv_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "42b62845d70a619f063a7da093d995ec8e15e778"
uuid = "94ce4f54-9a6c-5748-9c1c-f9c7231a4531"
version = "1.16.1+1"

[[Libmount_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "9c30530bf0effd46e15e0fdcf2b8636e78cbbd73"
uuid = "4b2f31a3-9ecc-558c-b454-b3730dcb73e9"
version = "2.35.0+0"

[[Libtiff_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Pkg", "Zlib_jll", "Zstd_jll"]
git-tree-sha1 = "340e257aada13f95f98ee352d316c3bed37c8ab9"
uuid = "89763e89-9b03-5906-acba-b20f662cd828"
version = "4.3.0+0"

[[Libuuid_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "7f3efec06033682db852f8b3bc3c1d2b0a0ab066"
uuid = "38a345b3-de98-5d2b-a5d3-14cd9215e700"
version = "2.36.0+0"

[[LinearAlgebra]]
deps = ["Libdl"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "5a5bc6bf062f0f95e62d0fe0a2d99699fed82dd9"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.8"

[[Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[MbedTLS]]
deps = ["Dates", "MbedTLS_jll", "Random", "Sockets"]
git-tree-sha1 = "1c38e51c3d08ef2278062ebceade0e46cefc96fe"
uuid = "739be429-bea8-5141-9913-cc70e7f3736d"
version = "1.0.3"

[[MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"

[[Measures]]
git-tree-sha1 = "e498ddeee6f9fdb4551ce855a46f54dbd900245f"
uuid = "442fdcdd-2543-5da2-b0f3-8c86c306513e"
version = "0.3.1"

[[Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "2ca267b08821e86c5ef4376cffed98a46c2cb205"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.0.1"

[[Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"

[[NaNMath]]
git-tree-sha1 = "bfe47e760d60b82b66b61d2d44128b62e3a369fb"
uuid = "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3"
version = "0.3.5"

[[NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"

[[Ogg_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "7937eda4681660b4d6aeeecc2f7e1c81c8ee4e2f"
uuid = "e7412a2a-1a6e-54c0-be00-318e2571c051"
version = "1.3.5+0"

[[OpenSSL_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "15003dcb7d8db3c6c857fda14891a539a8f2705a"
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "1.1.10+0"

[[Opus_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "51a08fb14ec28da2ec7a927c4337e4332c2a4720"
uuid = "91d4177d-7536-5919-b921-800302f37372"
version = "1.3.2+0"

[[OrderedCollections]]
git-tree-sha1 = "85f8e6578bf1f9ee0d11e7bb1b1456435479d47c"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.4.1"

[[PCRE_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b2a7af664e098055a7529ad1a900ded962bca488"
uuid = "2f80f16e-611a-54ab-bc61-aa92de5b98fc"
version = "8.44.0+0"

[[Parsers]]
deps = ["Dates"]
git-tree-sha1 = "438d35d2d95ae2c5e8780b330592b6de8494e779"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.0.3"

[[Pixman_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b4f5d02549a10e20780a24fce72bea96b6329e29"
uuid = "30392449-352a-5448-841d-b1acce4e97dc"
version = "0.40.1+0"

[[Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"

[[PlotThemes]]
deps = ["PlotUtils", "Requires", "Statistics"]
git-tree-sha1 = "a3a964ce9dc7898193536002a6dd892b1b5a6f1d"
uuid = "ccf2f8ad-2431-5c83-bf29-c5338b663b6a"
version = "2.0.1"

[[PlotUtils]]
deps = ["ColorSchemes", "Colors", "Dates", "Printf", "Random", "Reexport", "Statistics"]
git-tree-sha1 = "9ff1c70190c1c30aebca35dc489f7411b256cd23"
uuid = "995b91a9-d308-5afd-9ec6-746e21dbc043"
version = "1.0.13"

[[Plots]]
deps = ["Base64", "Contour", "Dates", "Downloads", "FFMPEG", "FixedPointNumbers", "GR", "GeometryBasics", "JSON", "Latexify", "LinearAlgebra", "Measures", "NaNMath", "PlotThemes", "PlotUtils", "Printf", "REPL", "Random", "RecipesBase", "RecipesPipeline", "Reexport", "Requires", "Scratch", "Showoff", "SparseArrays", "Statistics", "StatsBase", "UUIDs"]
git-tree-sha1 = "2dbafeadadcf7dadff20cd60046bba416b4912be"
uuid = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
version = "1.21.3"

[[PooledArrays]]
deps = ["DataAPI", "Future"]
git-tree-sha1 = "a193d6ad9c45ada72c14b731a318bedd3c2f00cf"
uuid = "2dfb63ee-cc39-5dd5-95bd-886bf059d720"
version = "1.3.0"

[[Preferences]]
deps = ["TOML"]
git-tree-sha1 = "00cfd92944ca9c760982747e9a1d0d5d86ab1e5a"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.2.2"

[[PrettyTables]]
deps = ["Crayons", "Formatting", "Markdown", "Reexport", "Tables"]
git-tree-sha1 = "0d1245a357cc61c8cd61934c07447aa569ff22e6"
uuid = "08abe8d2-0d0c-5749-adfa-8a2ac140af0d"
version = "1.1.0"

[[Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[Qt5Base_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Fontconfig_jll", "Glib_jll", "JLLWrappers", "Libdl", "Libglvnd_jll", "OpenSSL_jll", "Pkg", "Xorg_libXext_jll", "Xorg_libxcb_jll", "Xorg_xcb_util_image_jll", "Xorg_xcb_util_keysyms_jll", "Xorg_xcb_util_renderutil_jll", "Xorg_xcb_util_wm_jll", "Zlib_jll", "xkbcommon_jll"]
git-tree-sha1 = "ad368663a5e20dbb8d6dc2fddeefe4dae0781ae8"
uuid = "ea2cea3b-5b76-57ae-a6ef-0a8af62496e1"
version = "5.15.3+0"

[[Query]]
deps = ["DataValues", "IterableTables", "MacroTools", "QueryOperators", "Statistics"]
git-tree-sha1 = "a66aa7ca6f5c29f0e303ccef5c8bd55067df9bbe"
uuid = "1a8c2f83-1ff3-5112-b086-8aa67b057ba1"
version = "1.0.0"

[[QueryOperators]]
deps = ["DataStructures", "DataValues", "IteratorInterfaceExtensions", "TableShowUtils"]
git-tree-sha1 = "911c64c204e7ecabfd1872eb93c49b4e7c701f02"
uuid = "2aef5ad7-51ca-5a8f-8e88-e75cf067b44b"
version = "0.9.3"

[[REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[Random]]
deps = ["Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[RecipesBase]]
git-tree-sha1 = "44a75aa7a527910ee3d1751d1f0e4148698add9e"
uuid = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
version = "1.1.2"

[[RecipesPipeline]]
deps = ["Dates", "NaNMath", "PlotUtils", "RecipesBase"]
git-tree-sha1 = "d4491becdc53580c6dadb0f6249f90caae888554"
uuid = "01d81517-befc-4cb6-b9ec-a95719d0359c"
version = "0.4.0"

[[Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "4036a3bd08ac7e968e27c203d45f5fff15020621"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.1.3"

[[SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"

[[Scratch]]
deps = ["Dates"]
git-tree-sha1 = "0b4b7f1393cff97c33891da2a0bf69c6ed241fda"
uuid = "6c6a2e73-6563-6170-7368-637461726353"
version = "1.1.0"

[[SentinelArrays]]
deps = ["Dates", "Random"]
git-tree-sha1 = "54f37736d8934a12a200edea2f9206b03bdf3159"
uuid = "91c51154-3ec4-41a3-a24f-3f23e20d615c"
version = "1.3.7"

[[Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[SharedArrays]]
deps = ["Distributed", "Mmap", "Random", "Serialization"]
uuid = "1a1011a3-84de-559e-8e89-a11a2f7dc383"

[[Showoff]]
deps = ["Dates", "Grisu"]
git-tree-sha1 = "91eddf657aca81df9ae6ceb20b959ae5653ad1de"
uuid = "992d4aef-0814-514b-bc4d-f2e9a6c4116f"
version = "1.0.3"

[[Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "b3363d7460f7d098ca0912c69b082f75625d7508"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.0.1"

[[SparseArrays]]
deps = ["LinearAlgebra", "Random"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[StaticArrays]]
deps = ["LinearAlgebra", "Random", "Statistics"]
git-tree-sha1 = "3240808c6d463ac46f1c1cd7638375cd22abbccb"
uuid = "90137ffa-7385-5640-81b9-e52037218182"
version = "1.2.12"

[[Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[[StatsAPI]]
git-tree-sha1 = "1958272568dc176a1d881acb797beb909c785510"
uuid = "82ae8749-77ed-4fe6-ae5f-f523153014b0"
version = "1.0.0"

[[StatsBase]]
deps = ["DataAPI", "DataStructures", "LinearAlgebra", "Missings", "Printf", "Random", "SortingAlgorithms", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "8cbbc098554648c84f79a463c9ff0fd277144b6c"
uuid = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
version = "0.33.10"

[[StructArrays]]
deps = ["Adapt", "DataAPI", "StaticArrays", "Tables"]
git-tree-sha1 = "f41020e84127781af49fc12b7e92becd7f5dd0ba"
uuid = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"
version = "0.6.2"

[[TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"

[[TableShowUtils]]
deps = ["DataValues", "Dates", "JSON", "Markdown", "Test"]
git-tree-sha1 = "14c54e1e96431fb87f0d2f5983f090f1b9d06457"
uuid = "5e66a065-1f0a-5976-b372-e0b8c017ca10"
version = "0.2.5"

[[TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[TableTraitsUtils]]
deps = ["DataValues", "IteratorInterfaceExtensions", "Missings", "TableTraits"]
git-tree-sha1 = "78fecfe140d7abb480b53a44f3f85b6aa373c293"
uuid = "382cd787-c1b6-5bf2-a167-d5b971a19bda"
version = "1.0.2"

[[Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "LinearAlgebra", "TableTraits", "Test"]
git-tree-sha1 = "368d04a820fe069f9080ff1b432147a6203c3c89"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.5.1"

[[Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"

[[Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[TranscodingStreams]]
deps = ["Random", "Test"]
git-tree-sha1 = "216b95ea110b5972db65aa90f88d8d89dcb8851c"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.9.6"

[[URIs]]
git-tree-sha1 = "97bbe755a53fe859669cd907f2d96aee8d2c1355"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.3.0"

[[UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[Wayland_jll]]
deps = ["Artifacts", "Expat_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Pkg", "XML2_jll"]
git-tree-sha1 = "3e61f0b86f90dacb0bc0e73a0c5a83f6a8636e23"
uuid = "a2964d1f-97da-50d4-b82a-358c7fce9d89"
version = "1.19.0+0"

[[Wayland_protocols_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Wayland_jll"]
git-tree-sha1 = "2839f1c1296940218e35df0bbb220f2a79686670"
uuid = "2381bf8a-dfd0-557d-9999-79630e7b1b91"
version = "1.18.0+4"

[[WeakRefStrings]]
deps = ["DataAPI", "Parsers"]
git-tree-sha1 = "4a4cfb1ae5f26202db4f0320ac9344b3372136b0"
uuid = "ea10d353-3f73-51f8-a26c-33c1cb351aa5"
version = "1.3.0"

[[XML2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libiconv_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "1acf5bdf07aa0907e0a37d3718bb88d4b687b74a"
uuid = "02c8fc9c-b97f-50b9-bbe4-9be30ff0a78a"
version = "2.9.12+0"

[[XSLT_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgcrypt_jll", "Libgpg_error_jll", "Libiconv_jll", "Pkg", "XML2_jll", "Zlib_jll"]
git-tree-sha1 = "91844873c4085240b95e795f692c4cec4d805f8a"
uuid = "aed1982a-8fda-507f-9586-7b0439959a61"
version = "1.1.34+0"

[[Xorg_libX11_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxcb_jll", "Xorg_xtrans_jll"]
git-tree-sha1 = "5be649d550f3f4b95308bf0183b82e2582876527"
uuid = "4f6342f7-b3d2-589e-9d20-edeb45f2b2bc"
version = "1.6.9+4"

[[Xorg_libXau_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4e490d5c960c314f33885790ed410ff3a94ce67e"
uuid = "0c0b7dd1-d40b-584c-a123-a41640f87eec"
version = "1.0.9+4"

[[Xorg_libXcursor_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXfixes_jll", "Xorg_libXrender_jll"]
git-tree-sha1 = "12e0eb3bc634fa2080c1c37fccf56f7c22989afd"
uuid = "935fb764-8cf2-53bf-bb30-45bb1f8bf724"
version = "1.2.0+4"

[[Xorg_libXdmcp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4fe47bd2247248125c428978740e18a681372dd4"
uuid = "a3789734-cfe1-5b06-b2d0-1dd0d9d62d05"
version = "1.1.3+4"

[[Xorg_libXext_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "b7c0aa8c376b31e4852b360222848637f481f8c3"
uuid = "1082639a-0dae-5f34-9b06-72781eeb8cb3"
version = "1.3.4+4"

[[Xorg_libXfixes_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "0e0dc7431e7a0587559f9294aeec269471c991a4"
uuid = "d091e8ba-531a-589c-9de9-94069b037ed8"
version = "5.0.3+4"

[[Xorg_libXi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll", "Xorg_libXfixes_jll"]
git-tree-sha1 = "89b52bc2160aadc84d707093930ef0bffa641246"
uuid = "a51aa0fd-4e3c-5386-b890-e753decda492"
version = "1.7.10+4"

[[Xorg_libXinerama_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll"]
git-tree-sha1 = "26be8b1c342929259317d8b9f7b53bf2bb73b123"
uuid = "d1454406-59df-5ea1-beac-c340f2130bc3"
version = "1.1.4+4"

[[Xorg_libXrandr_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll", "Xorg_libXrender_jll"]
git-tree-sha1 = "34cea83cb726fb58f325887bf0612c6b3fb17631"
uuid = "ec84b674-ba8e-5d96-8ba1-2a689ba10484"
version = "1.5.2+4"

[[Xorg_libXrender_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "19560f30fd49f4d4efbe7002a1037f8c43d43b96"
uuid = "ea2f1a96-1ddc-540d-b46f-429655e07cfa"
version = "0.9.10+4"

[[Xorg_libpthread_stubs_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "6783737e45d3c59a4a4c4091f5f88cdcf0908cbb"
uuid = "14d82f49-176c-5ed1-bb49-ad3f5cbd8c74"
version = "0.1.0+3"

[[Xorg_libxcb_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "XSLT_jll", "Xorg_libXau_jll", "Xorg_libXdmcp_jll", "Xorg_libpthread_stubs_jll"]
git-tree-sha1 = "daf17f441228e7a3833846cd048892861cff16d6"
uuid = "c7cfdc94-dc32-55de-ac96-5a1b8d977c5b"
version = "1.13.0+3"

[[Xorg_libxkbfile_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "926af861744212db0eb001d9e40b5d16292080b2"
uuid = "cc61e674-0454-545c-8b26-ed2c68acab7a"
version = "1.1.0+4"

[[Xorg_xcb_util_image_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "0fab0a40349ba1cba2c1da699243396ff8e94b97"
uuid = "12413925-8142-5f55-bb0e-6d7ca50bb09b"
version = "0.4.0+1"

[[Xorg_xcb_util_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxcb_jll"]
git-tree-sha1 = "e7fd7b2881fa2eaa72717420894d3938177862d1"
uuid = "2def613f-5ad1-5310-b15b-b15d46f528f5"
version = "0.4.0+1"

[[Xorg_xcb_util_keysyms_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "d1151e2c45a544f32441a567d1690e701ec89b00"
uuid = "975044d2-76e6-5fbe-bf08-97ce7c6574c7"
version = "0.4.0+1"

[[Xorg_xcb_util_renderutil_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "dfd7a8f38d4613b6a575253b3174dd991ca6183e"
uuid = "0d47668e-0667-5a69-a72c-f761630bfb7e"
version = "0.3.9+1"

[[Xorg_xcb_util_wm_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "e78d10aab01a4a154142c5006ed44fd9e8e31b67"
uuid = "c22f9ab0-d5fe-5066-847c-f4bb1cd4e361"
version = "0.4.1+1"

[[Xorg_xkbcomp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxkbfile_jll"]
git-tree-sha1 = "4bcbf660f6c2e714f87e960a171b119d06ee163b"
uuid = "35661453-b289-5fab-8a00-3d9160c6a3a4"
version = "1.4.2+4"

[[Xorg_xkeyboard_config_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xkbcomp_jll"]
git-tree-sha1 = "5c8424f8a67c3f2209646d4425f3d415fee5931d"
uuid = "33bec58e-1273-512f-9401-5d533626f822"
version = "2.27.0+4"

[[Xorg_xtrans_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "79c31e7844f6ecf779705fbc12146eb190b7d845"
uuid = "c5fb5394-a638-5e4d-96e5-b29de1b5cf10"
version = "1.4.0+3"

[[Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"

[[Zstd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "cc4bf3fdde8b7e3e9fa0351bdeedba1cf3b7f6e6"
uuid = "3161d3a3-bdf6-5164-811a-617609db77b4"
version = "1.5.0+0"

[[libass_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "5982a94fcba20f02f42ace44b9894ee2b140fe47"
uuid = "0ac62f75-1d6f-5e53-bd7c-93b484bb37c0"
version = "0.15.1+0"

[[libfdk_aac_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "daacc84a041563f965be61859a36e17c4e4fcd55"
uuid = "f638f0a6-7fb0-5443-88ba-1cc74229b280"
version = "2.0.2+0"

[[libpng_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "94d180a6d2b5e55e447e2d27a29ed04fe79eb30c"
uuid = "b53b4c65-9356-5827-b1ea-8c7a1a84506f"
version = "1.6.38+0"

[[libvorbis_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Ogg_jll", "Pkg"]
git-tree-sha1 = "c45f4e40e7aafe9d086379e5578947ec8b95a8fb"
uuid = "f27f6e37-5d2b-51aa-960f-b287f2bc3b7a"
version = "1.3.7+0"

[[nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"

[[p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"

[[x264_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4fea590b89e6ec504593146bf8b988b2c00922b2"
uuid = "1270edf5-f2f9-52d2-97e9-ab00b5d0237a"
version = "2021.5.5+0"

[[x265_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "ee567a171cce03570d77ad3a43e90218e38937a9"
uuid = "dfaa095f-4041-5dcd-9319-2fabd8486b76"
version = "3.5.0+0"

[[xkbcommon_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Wayland_jll", "Wayland_protocols_jll", "Xorg_libxcb_jll", "Xorg_xkeyboard_config_jll"]
git-tree-sha1 = "ece2350174195bb31de1a63bea3a41ae1aa593b6"
uuid = "d8fb68d0-12a3-5cfd-a85a-d49703b185fd"
version = "0.9.1+5"
"""

# ╔═╡ Cell order:
# ╟─3a80dbae-59b8-11eb-11c8-1b4ed01e73f5
# ╟─1151bf70-865e-11eb-044e-6d28c3bfce41
# ╟─11851990-8660-11eb-29a3-553867ba8c75
# ╠═f5c0cd40-59b8-11eb-1ade-234f67f7efab
# ╠═dc6948b9-7769-45c3-aed2-c5cc5e47ca1e
# ╟─4ebc1620-865a-11eb-1e0d-cd2669b2acad
# ╠═12901690-8684-11eb-2978-3f4b6f0d0fc4
# ╠═61793e10-8e47-11eb-3bf4-cd92fdcc2a1d
# ╟─e4395f40-870a-11eb-3c7f-435231c70f87
# ╟─9f546962-2798-4452-befa-883326271887
# ╟─b6b8f109-ab0b-4a9e-a82e-7f510f1c8974
# ╠═3be4828d-01f7-4450-8133-a429bb59ed62
# ╠═5eb88736-3ea8-458e-8091-58319ad37dc1
# ╟─6e719113-62d9-4119-a2aa-160b8854134a
# ╟─081746e8-25b1-4c55-99ce-fd7e38dd9fe4
# ╠═3ac50706-59e0-473f-85ef-558afce47549
# ╟─479b39f9-8650-468c-a67e-c699fd00a7fa
# ╟─79d92592-f849-4083-81ef-35502939deda
# ╟─f92a3bdf-2209-47be-8881-2a0567607b80
# ╟─e156c4d1-279f-4073-aa21-5840b8554482
# ╠═3d56e346-49b8-4e86-b43d-2d812c94c072
# ╟─fafe381e-0baf-40c1-b127-67b7f8c1a902
# ╠═cc64aa01-953e-49fd-8301-9be1f244437d
# ╟─e82faaad-5278-4d8f-982b-fca335bbd006
# ╟─6a5f4405-f63c-4fff-b692-e2bbe396ed7a
# ╠═bb659f3a-0a01-4f40-81ce-a8c13a34250b
# ╟─0ec47530-59b9-11eb-0c49-2b70d7e37d4d
# ╠═3e139540-7b6b-11eb-0671-c5e4c87e6b21
# ╟─57585d80-7b6e-11eb-18b3-339ab0f601af
# ╠═d2fba1b6-bcd4-457e-82e1-3c9fa2922ba4
# ╟─fd0ed361-6317-48aa-b01e-34613db17ed1
# ╠═b11ddc3c-0820-4cc3-b7e1-c67407a87685
# ╟─4117f552-f93d-4de4-819b-d1e352a9e182
# ╠═83464630-7b6b-11eb-0611-2bffbe393b19
# ╟─c9ee5190-d362-43f9-94e7-de9b395d55fb
# ╠═fff30b64-d5bb-41df-91bc-ebb2492981ec
# ╠═13eaf81b-3e3c-4678-a644-0d6aa5629188
# ╟─9d84d4e2-d81d-4874-a656-8ff2624a7f1d
# ╠═7344c1d9-5d87-4b4d-8264-3043b162c49f
# ╠═4227b4c1-8629-4062-b9d7-1c87b522c761
# ╟─17da9ce0-e748-4bb3-aed4-f33da671aa48
# ╠═df5a3c48-f994-4a84-beca-f079420a1bbf
# ╟─77b24122-7b6b-11eb-2036-41d8d55f985a
# ╠═598d0cd2-59b9-11eb-0a8b-a1938e2c3c43
# ╟─751f6650-7ce1-11eb-3bfe-a1f01e765cf4
# ╟─d8a75470-7ce2-11eb-356d-63c3da69b9f0
# ╟─f6d13570-8281-11eb-0f64-771e22a6b27d
# ╟─268c8790-8284-11eb-0511-e367b9211e74
# ╟─378cfcd0-8349-11eb-1ad0-8939849c2c1e
# ╠═a13e4120-8641-11eb-0c7b-b366d42b115c
# ╟─f5076320-834b-11eb-3d3d-0380c1997163
# ╠═b4879bcc-51de-46fc-892b-c2bcf44e21b3
# ╟─a02e45b0-bc1b-4210-9f2f-ae72ed92357b
# ╠═0ed0c180-834b-11eb-3f40-b1243e850675
# ╠═affe8679-f56c-4564-b6c9-d4e17f890a12
# ╠═f40c617d-ce54-4788-bd23-bd8462469b11
# ╠═ee710208-b363-42b3-b811-efed2dc963a9
# ╠═920e803d-f050-4854-834b-21f0ad94e8b1
# ╠═0ebaff68-636c-4d98-95ee-0d770aaf5499
# ╟─0067688c-d991-4071-940f-73a8609c356c
# ╠═1f4ec6d2-d458-4760-a3b6-4f41348dd178
# ╠═b45279f3-05f5-4933-a08c-8e7e4b5c7ce5
# ╠═8682aebe-44ee-4a06-a245-3863f9b8b090
# ╠═fcae1759-26d7-4bd6-b46e-f4a84d3b366c
# ╟─dfc66579-f6f6-443e-aa42-3ecf7fe8f8cf
# ╠═388f9c8a-4723-4056-a329-732591a70077
# ╠═c457ddb6-e0af-49c2-bfc4-a8014bd12fbb
# ╠═e15b167a-b50a-4431-8a3b-a2a06341c1ea
# ╠═24520c51-e2ee-46c8-9290-cd0ee586a571
# ╠═b20a43cf-873b-4c9d-a78b-9c447bfdd5cf
# ╠═544a78ed-074b-47ee-965f-0f5d72ec82aa
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
