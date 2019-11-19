# -*- coding: utf-8 -*-
using ModelingToolkit
using MacroTools
using SemanticModels
using SemanticModels.ModelTools.PetriModels
import MacroTools: postwalk
using Test
using Petri

# +
@variables S, I, R

# generated by AMIDOL, basic SIR Model
sir = Petri.Model([S, I, R],
                 [(S+I, 2I), (I,R)])

# +
@variables I′, R′

# rule1 = SI <- SI -> SII
si = Petri.Model([S, I, R],
                 [(S+I, 2I)])

sii = Petri.Model([S, I, I′, R],
                  [(S+I,  2I ),
                   (S+I′, 2I′)]
                 )

rule1 = PetriModels.PetriSpan(si, si, sii)

# +
# rule2 = I <- I -> IR
i = Petri.Model([I′], Tuple{Operation,Operation}[])

ir = Petri.Model([I′, R′], [(I′, R′)])

rule2 = PetriModels.PetriSpan(i, i, ir)

# +
# rule3 = IRI′R′ <- II′ -> II′R
irir = Petri.Model([I, I′, R, R′], [(I, R), (I′, R′)])

ii = Petri.Model([I, I′], Tuple{Operation,Operation}[])

iir = Petri.Model([I, I′, R], [(I, R), (I′, R)])

rule3 = PetriModels.PetriSpan(irir, ii, iir)

# +
# Apply rules to each model in succession

siir = PetriModels.solve(PetriModels.DPOProblem(rule1, sir))

siirr = PetriModels.solve(PetriModels.DPOProblem(rule2, siir))

c′ = PetriModels.dropdown(irir, ii, siirr)
siir′ = PetriModels.solve(PetriModels.DPOProblem(rule3, c′))

println(sir.Δ)
println()
println(siir′.Δ)