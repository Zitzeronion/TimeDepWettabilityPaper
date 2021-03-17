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

![]("https://jugit.fz-juelich.de/s.zitz/timedependent_wettability/-/raw/master/Figures/angle_early.png?inline=false")
![]("https://jugit.fz-juelich.de/s.zitz/timedependent_wettability/-/raw/master/Figures/angle_later.png?inline=false")

## Dependencies

First some dependencies have to be loaded, [DataFrames](https://github.com/JuliaData/DataFrames.jl/tree/master) and [CSV](https://github.com/JuliaData/CSV.jl/tree/master) for the clean display of data, [Plots](https://github.com/JuliaPlots/Plots.jl) and [StatsPlots](https://github.com/JuliaPlots/StatsPlots.jl) for plotting, and [HTTP](https://github.com/JuliaWeb/HTTP.jl) for loading the data from web.
For the analysis of the our data we need some way to scan efficiently through the `DataFrames`, for this reason we include [DataFramesMeta](https://github.com/JuliaData/DataFramesMeta.jl) and make heavy use of the `@linq` macro.
