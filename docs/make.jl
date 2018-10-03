using Pkg, Documenter

try
    using JAXTAM
catch ArgumentError
    Pkg.activate(joinpath(pwd(), ".."))
    using JAXTAM
end

@info "Current dir: $(pwd())"

DOCUMENTER_DEBUG=true

makedocs(
    modules  = [JAXTAM],
    doctest  = false,
    clean    = false,
    sitename = "JAXTAM Documentation",
    format   = :html
)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
deploydocs(
    repo  = "github.com/RobertRosca/JAXTAM.jl.git",
    julia = "0.7",
    deps  = nothing,
    make  = nothing,
)