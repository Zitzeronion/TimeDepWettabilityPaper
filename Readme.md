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

<img src="https://jugit.fz-juelich.de/s.zitz/timedependent_wettability/-/raw/master/Figures/angle_early.png?inline=false" width="320" height="320" />
<img src="https://jugit.fz-juelich.de/s.zitz/timedependent_wettability/-/raw/master/Figures/angle_later.png?inline=false" width="320" height="320" />

## Dependencies

First some dependencies have to be loaded, [DataFrames](https://github.com/JuliaData/DataFrames.jl/tree/master) and [CSV](https://github.com/JuliaData/CSV.jl/tree/master) for the clean display of data, [Plots](https://github.com/JuliaPlots/Plots.jl) and [StatsPlots](https://github.com/JuliaPlots/StatsPlots.jl) for plotting, and [HTTP](https://github.com/JuliaWeb/HTTP.jl) for loading the data from web.
For the analysis of the our data we need some way to scan efficiently through the `DataFrames`, for this reason we include [DataFramesMeta](https://github.com/JuliaData/DataFramesMeta.jl) and make heavy use of the `@linq` macro.

```julia
using DataFrames, CSV, Plots, StatsPlots, HTTP, DataFramesMeta
```

## Height tracking

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
The file can be load with the following julia command,
```julia
df_delta_h = CSV.File(HTTP.get("https://jugit.fz-juelich.de/s.zitz/timedependent_wettability/-/raw/master/Data_CSV/height_differences.csv?inline=false").body) |> DataFrame
```

Okay the file got 24000 entries, which is consistent with our enumeration.

Now we want to dig into the data.
First thing we can easily access is the influence of the **wavelenght** λₜ (we use subscript t because it renders while θ does not) of the pattern.

Below we plot the **Δh** for the three wavelengths 512, 256 & 171. 
As expected the stability (sharp jump in Δh) will reduce with decreasing wavelenght.

### No Pattern velocity

Again concerning the plot below we can learn that the maximal height difference is corrolated with the pattern.
If the wavelength is similar to the full pattern we generate **two** droplets in the region of minimal contact angle.
The same idea applies for the other wavelengths as well, if there are **eight** contact angle minimia we create eight stabel droplets.
With the shortest wavelenght we observe **eighteen** stabel droplets.

To put this in math, two spherical cap shaped droplet with a given volumen of fluid have a well defined height *h*
```math
V = R³π/3(2+\cos(θ))(1-\cos(θ))²,
```
where $V$ is the volume and $R$ the radius of the sphere the spherical is cut from.
Lastly $θ$ is the contact angle the cap has with the substrate.