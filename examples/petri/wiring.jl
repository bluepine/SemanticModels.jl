
using Catlab
using MacroTools
import MacroTools: postwalk, striplines

using Catlab.WiringDiagrams
using Catlab.Doctrines
using Test
import Catlab.Doctrines.⊗
⊗(a::WiringDiagram, b::WiringDiagram) = otimes(a,b)
import Base: ∘
∘(a::WiringDiagram, b::WiringDiagram) = compose(b, a)
⊚(a,b) = b ∘ a

WiringDiagram

# Generators
A, B, C, D = Ob(FreeSymmetricMonoidalCategory, :A, :B, :C, :D)
f = WiringDiagram(Hom(:f,A,B))
g = WiringDiagram(Hom(:g,B,A))


@test nboxes(f) == 1
@test boxes(f) == [ Box(Hom(:f,A,B)) ]
@test nwires(f) == 2
@test Ports([:A]) == Ports([:A])
@test WiringDiagram(Hom(:f,A,B)) == WiringDiagram(Hom(:f,A,B))

Hom(:h, otimes(A,B), C)

Hom(:f, A, B) ⊗ Hom(:g, B, C)

Hom(:g, B, C) ∘ Hom(:f, A, B)

@test_throws SyntaxDomainError Hom(:g, B, C) ⊚ Hom(:f, A, B) 

@test compose(Hom(:f, A, B), Hom(:g, B, C)) == ⊚(Hom(:f, A,B), Hom(:g, B, C))

h = WiringDiagram(Hom(:h, otimes(A,B), C)) 

@test compose(otimes(f,g), h) == (f⊗g) ⊚ h

# Generators
S, E, I, R, D= Ob(FreeSymmetricMonoidalCategory, :S, :E, :I, :R, :D)

# A person could get sick spontaniously
ens = Hom(:ensicken, S, I)

#And sick people recover spontaneously too.
recovery = Hom(:recover, I, R)

# We can compose these to make a diagram of illness
compose(WiringDiagram(ens), WiringDiagram(recovery))

infecting = Hom(:infection,S ⊗ I, I⊗I)

inf = WiringDiagram(infecting)
rec = WiringDiagram(Hom(:recovery,I, R))

SIR = inf ⊚ rec

SIR = inf ⊚ WiringDiagram(Hom(:recover, I⊗I, R⊗R))

SIR = inf ⊚ (rec ⊗ rec)

wan = WiringDiagram(Hom(:waning,R, S))
SIRS = SIR ⊚ (wan⊗wan)

dom(SIR), codom(SIR)

dom(SIRS), codom(SIRS)

exposure = WiringDiagram(Hom(:exposure, S⊗I, E⊗I))
exposure ⊚ WiringDiagram(Hom(:progression, E⊗I, I)) ⊚ rec 

seir = exposure ⊚ (WiringDiagram(Hom(:progression, E, I)) ⊗ rec)

dom(seir), codom(seir)

seir ⊚ wan

# the types didn't match, we need to do something with that infected wire
seirs = seir ⊚ (rec⊗wan)

#what is a diagram? 
boxes(seirs)

wirenames(d::WiringDiagram) = foldr(union,
    map(box->union(input_ports(box), output_ports(box)),
        boxes(d)))
function fluxes(d::WiringDiagram)
    # TODO design Multiple Dispatch Lens API
    # TODO use ModelingToolkit variables
    nb = nboxes(d)
    vars = wirenames(d)
    byvar = Dict{Symbol, Expr}()
    homnames = Vector{Symbol}()
    for var in vars
        byvar[var] = :(+())
    end
    map(enumerate(boxes(d))) do (i, box)
        invars = input_ports(box)
        outvars = output_ports(box)
        homname = box.value
        push!(homnames, homname)
        βᵢ = :(p.$(homname))
        ϕ =  :(*($βᵢ, $(invars...)))
        map(invars) do v
            push!(byvar[v].args, :(-$ϕ))
        end
        map(outvars) do v
            push!(byvar[v].args, :($ϕ))
        end
    end
    return byvar, vars, homnames
end
#end

sir = WiringDiagram(Hom(:infection, S⊗I, I⊗I)) ⊚ (rec ⊗ rec)
seir = WiringDiagram(Hom(:exposure, S⊗I, E⊗I)) ⊚ (rec ⊗ WiringDiagram(Hom(:progression, E, I)))
dudt = fluxes(sir)[1]

fluxes(seir)[1]

@show dudt[1][:I]
map(enumerate(dudt[1])) do (i, ϕ)
    :(du.$(ϕ.first) = $(ϕ.second))
end

function oderhs(dudt::Dict{T, Expr}, vars::Vector{T}, homnames::Any) where {T}
    lines = map(enumerate(vars)) do (i, v)
        ϕ = dudt[v]
        #:(du.$(ϕ.first) = $(ϕ.second))
        :(du[$(i)] = $(ϕ))
    end
    fdef = quote
    function f(du, u, p, t)
        $(lines...)
        return du
    end
    end
    return fdef, vars, homnames
end

"""    oderhs(d::WiringDiagram)

convert a wiring diagram into a dynamical system described as julia Exprs.
We need to keep track of the names we give the variables and the parameters so those are the second and third arguments respectively.

Returns an expression that defines a function, a list of symbols representing the variables, and a list of symbols representing the parameter names.

see also fluxes(d::WiringDiagram) for implementation details
"""
oderhs(d::WiringDiagram) = oderhs(fluxes(d)...)

oderhs(sir)

"""    odeProblem(d::WiringDiagram, params, initials, tdomain, alg=missing)

bind a wiring diagram to a set of paramters, initial conditions, time domain and solver algorithm and generate the code the solves it.

see also odetemplate.
"""
function odeProblem(d::WiringDiagram, params, initials, tdomain, alg=missing)
    quote
        using DifferentialEquations
        $(oderhs(d)[1])
        function main()
            params = $params
            initials = $initials
            tdomain = $tdomain
            prob = ODEProblem(f, params, initials, tdomain)
            soln = solve(prob, alg=$alg)
            return prob, soln
        end
    end
end


odeProblem(seir, :β, :i₀, (0, 365), :(Tsit5()))

"""    odetemplate(d::WiringDiagram)

create an expression that defines a code that solves the ODE.
Given just the wiring diagram, we don't know the paramters, initial conditions, or timedomain, 
so they are passed in as arguments to the function we generate.

These parameters and initial conditions are destructured in the main function so you can
see what the code is expecting to receive by reading the generated output.

The structure of the timedomain is not implied by the wiring diagram so it is passed directly to the
ODEProblem constructor. Any keyword arguments you pass to `main()` are forwarded to `solve()`. 

"""
function odetemplate(d::WiringDiagram)
    f, vars, homnames = oderhs(d)
    params = Expr(:tuple, map(enumerate(homnames)) do (i, name)
        Expr(:(=), name, :(β[$i]))
            end...)
    vars = wirenames(d)
    initials = Expr(:vect, map(vars) do v
            :(i₀.$v)
            end...)
    quote
        using DifferentialEquations
        $(f.args[end])
        function main(β, i₀, tdomain; kwargs...)
            params = $params
            initials = $initials
            prob = ODEProblem(f, params, initials, tdomain)
            soln = solve(prob; kwargs...)
            return prob, soln
        end
    end
end

odetemplate(seir) |> x -> postwalk(x) do x
    return striplines(x)
end
