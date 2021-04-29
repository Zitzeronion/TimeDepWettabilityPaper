### A Pluto.jl notebook ###
# v0.14.4

using Markdown
using InteractiveUtils

# ╔═╡ 3832de4e-a82b-11eb-08b3-0184778c8ef7
using DataFrames, CSV, Plots, HTTP, DataFramesMeta, Query

# ╔═╡ 7488404c-a534-4096-a0ea-c927acf352b4
# Plots default fonts and font sizes, could add colors as well
default(titlefont = (20, "Arial"), legendfontsize = (18, "Arial"), guidefont = (18, "Arial"), tickfont = (16, "Arial"))

# ╔═╡ 8dbd5bc3-008f-4704-9ca0-b7ee4632a932
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

# ╔═╡ 8549e36b-a0a2-42d2-a7f1-6ebbf9ebe5df
all_data = CSV.File(HTTP.get("https://jugit.fz-juelich.de/s.zitz/timedependent_wettability/-/raw/master/Data_CSV/Data_with_t0_Q_beta.csv?inline=false").body) |> DataFrame

# ╔═╡ f59adb20-e6cb-4108-8da8-e491238a287d
scatter(1:10, 10:20)

# ╔═╡ Cell order:
# ╠═3832de4e-a82b-11eb-08b3-0184778c8ef7
# ╠═7488404c-a534-4096-a0ea-c927acf352b4
# ╠═8dbd5bc3-008f-4704-9ca0-b7ee4632a932
# ╠═8549e36b-a0a2-42d2-a7f1-6ebbf9ebe5df
# ╠═f59adb20-e6cb-4108-8da8-e491238a287d
