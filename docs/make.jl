using Documenter, JAXTAM

makedocs()

deploydocs(
    repo = "github.com/RobertRosca/JAXTAM.jl.git",
    julia = "0.6"
)