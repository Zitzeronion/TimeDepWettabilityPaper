### A Pluto.jl notebook ###
# v0.14.5

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

# ╔═╡ 3d56e346-49b8-4e86-b43d-2d812c94c072
savefig(v0_plot, "..\\Figures\\v0_dh_sine_with_const.pdf")

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
savefig(c_v0_plot, "..\\Figures\\v0_clusters_sine.pdf")

# ╔═╡ e82faaad-5278-4d8f-982b-fca335bbd006
md"
### Pattern velocity vₜ > 0

Now comes the fun part we start looking into the case where the substates pattern θ(x) becomes θ(x,t).
We start by taking a single wavelength and check the differences as a function of time.
First though for a nice data display we use a plots recipy taken from [here](https://github.com/JuliaPlots/Plots.jl/issues/2523).
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
savefig(fig_lam1, "..\\Figures\\dh_t_lam1_all_v.pdf")

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
savefig(rts_save, "..\\Figures\\rupture_time.pdf")

# ╔═╡ 9d84d4e2-d81d-4874-a656-8ff2624a7f1d
md"### Linear pattern
Besides the sine wave pattern we have data on a linear pattern as well.
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
		 legend=:topright)				    # legend position
end

# ╔═╡ f40c617d-ce54-4788-bd23-bd8462469b11
begin
	q2_data_lam2 = zeros(998, 4)
	for i in enumerate([0.0 0.1 1.0 10.0])
		filtered = @linq all_data |>
			where(:threshold .== thresh) |>
			where(:lambda .== 2) |>
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
		 legend=:topright)					# legend position
end

# ╔═╡ 8682aebe-44ee-4a06-a245-3863f9b8b090
savefig(q3_lam2, "..\\Figures\\q3_lam2.pdf")

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
# ╠═9f546962-2798-4452-befa-883326271887
# ╟─b6b8f109-ab0b-4a9e-a82e-7f510f1c8974
# ╠═3be4828d-01f7-4450-8133-a429bb59ed62
# ╠═5eb88736-3ea8-458e-8091-58319ad37dc1
# ╟─6e719113-62d9-4119-a2aa-160b8854134a
# ╠═081746e8-25b1-4c55-99ce-fd7e38dd9fe4
# ╠═3ac50706-59e0-473f-85ef-558afce47549
# ╟─479b39f9-8650-468c-a67e-c699fd00a7fa
# ╠═79d92592-f849-4083-81ef-35502939deda
# ╠═3d56e346-49b8-4e86-b43d-2d812c94c072
# ╠═fafe381e-0baf-40c1-b127-67b7f8c1a902
# ╠═cc64aa01-953e-49fd-8301-9be1f244437d
# ╟─e82faaad-5278-4d8f-982b-fca335bbd006
# ╠═6a5f4405-f63c-4fff-b692-e2bbe396ed7a
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
# ╠═9d84d4e2-d81d-4874-a656-8ff2624a7f1d
# ╠═7344c1d9-5d87-4b4d-8264-3043b162c49f
# ╠═4227b4c1-8629-4062-b9d7-1c87b522c761
# ╟─77b24122-7b6b-11eb-2036-41d8d55f985a
# ╠═598d0cd2-59b9-11eb-0a8b-a1938e2c3c43
# ╟─751f6650-7ce1-11eb-3bfe-a1f01e765cf4
# ╠═d8a75470-7ce2-11eb-356d-63c3da69b9f0
# ╠═f6d13570-8281-11eb-0f64-771e22a6b27d
# ╟─268c8790-8284-11eb-0511-e367b9211e74
# ╟─378cfcd0-8349-11eb-1ad0-8939849c2c1e
# ╠═a13e4120-8641-11eb-0c7b-b366d42b115c
# ╟─f5076320-834b-11eb-3d3d-0380c1997163
# ╠═b4879bcc-51de-46fc-892b-c2bcf44e21b3
# ╟─a02e45b0-bc1b-4210-9f2f-ae72ed92357b
# ╠═0ed0c180-834b-11eb-3f40-b1243e850675
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
