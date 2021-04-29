### A Pluto.jl notebook ###
# v0.14.4

using Markdown
using InteractiveUtils

# ╔═╡ 337c79a0-a814-11eb-17c1-edcc877c1d00
using DataFrames, CSV, Plots, HTTP, DataFramesMeta, Query

# ╔═╡ 2c53ffd9-ff67-4018-b07c-45c778abae09
default(titlefont = (20, "Arial"), legendfontsize = (18, "Arial"), guidefont = (18, "Arial"), tickfont = (16, "Arial"))

# ╔═╡ bf40b942-92b6-4488-8a08-ce4c88b13a57
df_delta_h = CSV.File(HTTP.get("https://jugit.fz-juelich.de/s.zitz/timedependent_wettability/-/raw/master/Data_CSV/height_differences.csv?inline=false").body) |> DataFrame

# ╔═╡ 55bd1b7e-592d-4ff5-8fe7-a1a87a4522ad
df_clusters = CSV.File(HTTP.get("https://jugit.fz-juelich.de/s.zitz/timedependent_wettability/-/raw/master/Data_CSV/Clusters.csv?inline=false").body) |> DataFrame

# ╔═╡ b3237aee-707e-4a88-9ead-784b8e553b97
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

# ╔═╡ c4019275-eef9-474d-bf88-ec64f00410cf
x_time = df_delta_h.time[1:1000]

# ╔═╡ 4670376b-777d-4ee2-b1c7-9bb8888437c6
which_p = "sine"

# ╔═╡ c43e98c3-c582-4c6d-8e77-c17022e7d756
md"## vₜ=0.1v₀"

# ╔═╡ 5c16fff7-8a6f-431d-820d-085351d13db9
begin
	c_v01_all_lam = zeros(1000, 3)
	for i in 1:3
		C_lam_sin_v01 = @linq df_clusters |>
			where(:velocities .== 0.1) |>
			where(:lambda .== i) |>
			where(:pattern .== which_p) |>
			select(:N_clusters, :A_clusters)
		c_v01_all_lam[:,i] .= C_lam_sin_v01.N_clusters
	end
	
	# Some cosmetics
	mks_v0_c = [:circle :rect :star5]
	labs_v0_c = ["λ=L" "λ=L/2" "λ=L/3"]
	# The plot
	c_v0_plot = plot(x_time,		 				# x-axis
					 c_v01_all_lam,     				# y-axis
					 # xaxis=:log,
					 label=labs_v0_c, 				# labels
					 xlabel="t/t₀", 				# x-axis label
					 ylabel="N",					# y-axis label
					 w = 3, 						# line width
					 st = :samplemarkers, 			# some recipy stuff
					 step = 50, 					# density of markers
					 marker = (8, mks_v0_c, 0.6),	# marker size
					 legendfontsize = 10,			# legend font size
					 # tickfont = (12, "Arial"),	# tick font and size
					 # guidefont = (18, "Arial"),	# label font and size
					 grid = :none,					# grid variable
					 legend=:topright,				# legend position
					)
	# Lines for analytical solutions
	hline!([2], line = (4, :dash, 0.5, palette(:default)[1]), label="")
	hline!([8], line = (4, :dash, 0.5, palette(:default)[2]), label="")
	hline!([18], line = (4, :dash, 0.5, palette(:default)[3]), label="")
end

# ╔═╡ ac2a6848-161e-4acf-8cb8-66d55b6d145d
begin
	h_v01_all_lam = zeros(1000, 3)
	for i in 1:3
		H_lam_sin_v01 = @linq df_delta_h |>
			where(:velocities .== 0.1) |>
			where(:lambda .== i) |>
			where(:pattern .== which_p) |>
			select(:h_mins, :h_max, :dh)
		h_v01_all_lam[:,i] .= H_lam_sin_v01.dh
	end
	
	# Some cosmetics
	# mks_v0_c = [:circle :rect :star5]
	# labs_v0_h = ["λ=L" "λ=L/2" "λ=L/3"]
	# The plot
	plot(x_time,		 				# x-axis
		 h_v01_all_lam,     				# y-axis
		 # xaxis=:log,
		 label=labs_v0_c, 				# labels
		 xlabel="t/t₀", 				# x-axis label
		 ylabel="Δh",					# y-axis label
		 w = 3, 						# line width
		 st = :samplemarkers, 			# some recipy stuff
		 step = 50, 					# density of markers
		 marker = (8, mks_v0_c, 0.6),	# marker size
		 legendfontsize = 10,			# legend font size
		 # tickfont = (12, "Arial"),	# tick font and size
		 # guidefont = (18, "Arial"),	# label font and size
		 grid = :none,					# grid variable
		 legend=:bottomright,				# legend position
		)
	# Lines for analytical solutions
	# hline!([2], line = (4, :dash, 0.5, palette(:default)[1]), label="")
	# hline!([8], line = (4, :dash, 0.5, palette(:default)[2]), label="")
	# hline!([18], line = (4, :dash, 0.5, palette(:default)[3]), label="")
end

# ╔═╡ 02f45229-d76a-405f-8b60-b4c759faa535
md"## vₜ=1v₀"

# ╔═╡ eabfee15-a20d-472e-aaef-30768b8064a9
begin
	c_v1_all_lam = zeros(1000, 3)
	for i in 1:3
		C_lam_sin_v1 = @linq df_clusters |>
			where(:velocities .== 1) |>
			where(:lambda .== i) |>
			where(:pattern .== which_p) |>
			select(:N_clusters, :A_clusters)
		c_v1_all_lam[:,i] .= C_lam_sin_v1.N_clusters
	end
	
	# Some cosmetics
	# mks_v0_c = [:circle :rect :star5]
	# labs_v0_c = ["λ=L" "λ=L/2" "λ=L/3"]
	# The plot
	plot(x_time,		 				# x-axis
					 c_v1_all_lam,     				# y-axis
					 # xaxis=:log,
					 label=labs_v0_c, 				# labels
					 xlabel="t/t₀", 				# x-axis label
					 ylabel="N",					# y-axis label
					 w = 3, 						# line width
					 st = :samplemarkers, 			# some recipy stuff
					 step = 50, 					# density of markers
					 marker = (8, mks_v0_c, 0.6),	# marker size
					 legendfontsize = 10,			# legend font size
					 # tickfont = (12, "Arial"),	# tick font and size
					 # guidefont = (18, "Arial"),	# label font and size
					 grid = :none,					# grid variable
					 legend=:topright,				# legend position
					)
	# Lines for analytical solutions
	#hline!([2], line = (4, :dash, 0.5, palette(:default)[1]), label="")
	#hline!([8], line = (4, :dash, 0.5, palette(:default)[2]), label="")
	#hline!([18], line = (4, :dash, 0.5, palette(:default)[3]), label="")
end

# ╔═╡ 3bc5e677-a5ea-4054-ab02-da5b4b2c02eb
begin
	h_v1_all_lam = zeros(1000, 3)
	for i in 1:3
		H_lam_sin_v1 = @linq df_delta_h |>
			where(:velocities .== 1) |>
			where(:lambda .== i) |>
			where(:pattern .== which_p) |>
			select(:h_mins, :h_max, :dh)
		h_v1_all_lam[:,i] .= H_lam_sin_v1.dh
	end
	
	# Some cosmetics
	# mks_v0_c = [:circle :rect :star5]
	# labs_v0_h = ["λ=L" "λ=L/2" "λ=L/3"]
	# The plot
	plot(x_time,		 				# x-axis
		 h_v1_all_lam,     				# y-axis
		 # xaxis=:log,
		 label=labs_v0_c, 				# labels
		 xlabel="t/t₀", 				# x-axis label
		 ylabel="Δh",					# y-axis label
		 w = 3, 						# line width
		 st = :samplemarkers, 			# some recipy stuff
		 step = 50, 					# density of markers
		 marker = (8, mks_v0_c, 0.6),	# marker size
		 legendfontsize = 10,			# legend font size
		 # tickfont = (12, "Arial"),	# tick font and size
		 # guidefont = (18, "Arial"),	# label font and size
		 grid = :none,					# grid variable
		 legend=:bottomright,				# legend position
		)
	# Lines for analytical solutions
	# hline!([2], line = (4, :dash, 0.5, palette(:default)[1]), label="")
	# hline!([8], line = (4, :dash, 0.5, palette(:default)[2]), label="")
	# hline!([18], line = (4, :dash, 0.5, palette(:default)[3]), label="")
end

# ╔═╡ 1b754f1e-8232-42e2-b818-b61b20f6e39b
md"## vₜ = 10v₀"

# ╔═╡ e0abb98c-d3ee-4229-a90c-fa8d37d916e3
begin
	c_v10_all_lam = zeros(1000, 3)
	for i in 1:3
		C_lam_sin_v10 = @linq df_clusters |>
			where(:velocities .== 10) |>
			where(:lambda .== i) |>
			where(:pattern .== which_p) |>
			select(:N_clusters, :A_clusters)
		c_v10_all_lam[:,i] .= C_lam_sin_v10.N_clusters
	end
	
	# Some cosmetics
	# mks_v0_c = [:circle :rect :star5]
	# labs_v0_h = ["λ=L" "λ=L/2" "λ=L/3"]
	# The plot
	plot(x_time,		 				# x-axis
		 c_v10_all_lam,     				# y-axis
		 # xaxis=:log,
		 label=labs_v0_c, 				# labels
		 xlabel="t/t₀", 				# x-axis label
		 ylabel="N",					# y-axis label
		 w = 3, 						# line width
		 st = :samplemarkers, 			# some recipy stuff
		 step = 50, 					# density of markers
		 marker = (8, mks_v0_c, 0.6),	# marker size
		 legendfontsize = 10,			# legend font size
		 # tickfont = (12, "Arial"),	# tick font and size
		 # guidefont = (18, "Arial"),	# label font and size
		 grid = :none,					# grid variable
		 legend=:bottomright,				# legend position
		)
	# Lines for analytical solutions
	# hline!([2], line = (4, :dash, 0.5, palette(:default)[1]), label="")
	# hline!([8], line = (4, :dash, 0.5, palette(:default)[2]), label="")
	# hline!([18], line = (4, :dash, 0.5, palette(:default)[3]), label="")
end

# ╔═╡ a6e75112-7b51-4789-8d47-2c88d03e9d11
begin
	h_v10_all_lam = zeros(1000, 3)
	for i in 1:3
		H_lam_sin_v10 = @linq df_delta_h |>
			where(:velocities .== 10) |>
			where(:lambda .== i) |>
			where(:pattern .== which_p) |>
			select(:h_mins, :h_max, :dh)
		h_v10_all_lam[:,i] .= H_lam_sin_v10.dh
	end
	
	# Some cosmetics
	# mks_v0_c = [:circle :rect :star5]
	# labs_v0_h = ["λ=L" "λ=L/2" "λ=L/3"]
	# The plot
	plot(x_time,		 				# x-axis
		 h_v10_all_lam,     				# y-axis
		 # xaxis=:log,
		 label=labs_v0_c, 				# labels
		 xlabel="t/t₀", 				# x-axis label
		 ylabel="Δh",					# y-axis label
		 w = 3, 						# line width
		 st = :samplemarkers, 			# some recipy stuff
		 step = 50, 					# density of markers
		 marker = (8, mks_v0_c, 0.6),	# marker size
		 legendfontsize = 10,			# legend font size
		 # tickfont = (12, "Arial"),	# tick font and size
		 # guidefont = (18, "Arial"),	# label font and size
		 grid = :none,					# grid variable
		 legend=:bottomright,				# legend position
		)
	# Lines for analytical solutions
	# hline!([2], line = (4, :dash, 0.5, palette(:default)[1]), label="")
	# hline!([8], line = (4, :dash, 0.5, palette(:default)[2]), label="")
	# hline!([18], line = (4, :dash, 0.5, palette(:default)[3]), label="")
end

# ╔═╡ Cell order:
# ╠═337c79a0-a814-11eb-17c1-edcc877c1d00
# ╠═2c53ffd9-ff67-4018-b07c-45c778abae09
# ╠═bf40b942-92b6-4488-8a08-ce4c88b13a57
# ╠═55bd1b7e-592d-4ff5-8fe7-a1a87a4522ad
# ╠═b3237aee-707e-4a88-9ead-784b8e553b97
# ╠═c4019275-eef9-474d-bf88-ec64f00410cf
# ╠═4670376b-777d-4ee2-b1c7-9bb8888437c6
# ╟─c43e98c3-c582-4c6d-8e77-c17022e7d756
# ╠═5c16fff7-8a6f-431d-820d-085351d13db9
# ╠═ac2a6848-161e-4acf-8cb8-66d55b6d145d
# ╟─02f45229-d76a-405f-8b60-b4c759faa535
# ╠═eabfee15-a20d-472e-aaef-30768b8064a9
# ╠═3bc5e677-a5ea-4054-ab02-da5b4b2c02eb
# ╟─1b754f1e-8232-42e2-b818-b61b20f6e39b
# ╠═e0abb98c-d3ee-4229-a90c-fa8d37d916e3
# ╠═a6e75112-7b51-4789-8d47-2c88d03e9d11
