using UpdateJulia
using Documenter

DocMeta.setdocmeta!(UpdateJulia, :DocTestSetup, :(using UpdateJulia); recursive=true)

makedocs(;
    modules=[UpdateJulia],
    authors="Lilith Orion Hafner <60898866+LilithHafner@users.noreply.github.com> and contributors",
    repo="https://github.com/LilithHafner/UpdateJulia.jl/blob/{commit}{path}#{line}",
    sitename="UpdateJulia.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://LilithHafner.github.io/UpdateJulia.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/LilithHafner/UpdateJulia.jl",
    devbranch="main",
)
