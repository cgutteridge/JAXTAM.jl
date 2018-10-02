using Pkg
Pkg.activate("/home/robert/Projects/JAXTAM")

using Documenter
using JAXTAM

makedocs(
    sitename="JAXTAM Documentation",
    modules = [JAXTAM]
)

deploydocs(
    repo = "github.com/RobertRosca/JAXTAM.jl.git",
)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
#=deploydocs(
    repo = "<repository url>"
)=#
