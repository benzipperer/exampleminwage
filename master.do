* example code to see relationship between state min wage and state-specific deciles of wage distribution
* sort of similar to Autor Manning Smith (2016)
set more off
clear all 

* use annual min wage data
* exported from version 1.2.0 of https://github.com/benzipperer/historicalminwage
import delimited using mw_state_annual, clear
rename statefipscode statefips
rename annualstatemaximum max_mw
rename annualstateminimum min_mw
* modify NY min wage, which has some Dec 31 min wage changes, so that diff occurs next year
replace max_mw = min_mw if stateabb == "NY" & year >= 2013
gen logmw = log(max_mw)
keep statefips year logmw
keep if year >= 2010 & year <= 2019
tempfile mwdata 
save `mwdata'

* use EPI CPS ORG data and load_epiextracts package from https://microdata.epi.org
load_epiextracts, begin(2010m1) end(2019m12) sample(org) keep(wage statefips)
keep if wage > 0 & wage ~= .
gen logwage = log(wage)
* create a wage-earning population indicator for using as state-population weights later
gen pop = 1
* create percentile list for collapse
local collapselist ""
forvalues i = 10(1)90 {
  local collapselist `collapselist' (p`i') p`i' = logwage
}
gcollapse `collapselist' (sum) pop [pw=orgwgt], by(statefips year)
merge 1:1 statefips year using `mwdata', assert(3) nogenerate

* temporary names for postfile
tempname memhold
tempfile results
postfile `memhold' percentile b ub95 lb95 using "`results'"

forvalues i = 10(1)90 {
  * run regression
  reghdfe p`i' logmw [aw = pop], a(i.statefips i.year) cluster(statefips)

  * use lincom to easily grab estimates and CIs
  lincom logmw

  * store results
  post `memhold' (`i') (`r(estimate)') (`r(ub)') (`r(lb)')
}
postclose `memhold'

use `results', clear 
scatter b ub95 lb95 percentile, connect(l ..) msize(small ..) legend(off) graphregion(color(white))
graph export mw_percentiles.pdf, replace

