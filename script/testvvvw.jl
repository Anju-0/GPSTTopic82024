using StatsFuns
using Plots
ϵ = 0.0001
r = -2:0.01:2.0
y(x,ϵ) = ϵ.*log.(1.0 .+ exp.(x./ϵ))
plot(r, y(r,ϵ))
plot!(r, ϵ.*log1pexp.(r./ϵ), linestyle=:dot)
#now you see that the function evalution is unreliable!


V_vw = [195; 253; 260; 276]./230
P_vw = [100; 100; 20; 20]./100

V_vv = [195; 207; 220; 240; 258; 276]./230
Q_vv = [44; 44;   0;   0;  -60;  -60]./100

vw = plot(V_vw, P_vw)
title!("Volt-Watt characteristic")
xlabel!("Voltage (V pu)")
ylabel!("Active power (W pu)")

vv = plot(V_vv, Q_vv)
title!("Volt-var characteristic")
xlabel!("Voltage (V pu)")
ylabel!("Reactive power (var pu)")


function rectifier(x,y,a;type="smooth", ϵ=10^-4)
    if type=="nonsmooth"
        return f = vals -> a*max(0, vals - x) + y
    elseif type=="smooth"
        return f = vals -> a*ϵ*log1pexp((vals-x)/ϵ) + y
    end
end

ϵ=1
type = "smooth"
plot()
for ϵ in [5,2,1,0.5,0.01]
    relu = rectifier(253,100,-80/7;type=type, ϵ=ϵ)
    relu2 =rectifier(260,0,+80/7;type=type, ϵ=ϵ)
    vw_curve(x) = relu(x) + relu2(x)
    rr =195:0.1:276
    plot!(rr,vw_curve.(rr), label="epsilon=$ϵ")
end
title!("Volt-Watt characteristic")
xlabel!("Voltage (V pu)")
ylabel!("Active power (W pu)")
savefig("voltwatt.pdf")

using JuMP
using Ipopt
xmin = 2.0
ϵ = 0.0001

m = Model(Ipopt.Optimizer)
register(m, :log1pexp, 1, log1pexp; autodiff = true)
@variable(m, x>=xmin)
@variable(m, y11>=0)
@NLconstraint(m, ϵ*log1pexp(x/ϵ) == y11)
@objective(m, Min, y11)
optimize!(m)
@show value.(x)
@show value.(y11)
termination_status(m)
##
m2 = Model(Ipopt.Optimizer)
@variable(m2, x2>=xmin)
@variable(m2, y22>=0)
@NLconstraint(m2, ϵ*log(1+exp(x2/ϵ)) == y22)
@objective(m2, Min, y22)
optimize!(m2)
@show value.(x2)
@show value.(y22)
termination_status(m2)