using Documenter, JAXTAM

makedocs()

deploydocs(
    repo = "github.com/robertrosca/JAXTAM.jl.git",
    julia = "0.6"
)