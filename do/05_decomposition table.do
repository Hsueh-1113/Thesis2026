capture program drop post_lincom
program define post_lincom
    syntax , Handle(name) Panel(string) Row(string) Col(integer) Expr(string asis)

    capture quietly lincom `expr'
    if _rc {
        post `handle' ("`panel'") ("`row'") (`col') (.) (.) (.)
    }
    else {
        post `handle' ("`panel'") ("`row'") (`col') (r(estimate)) (r(se)) (r(p))
    }
end

capture program drop collect_decomp
program define collect_decomp
    syntax , Handle(name) Col(integer)

    * overall
    post_lincom, handle(`handle') panel("overall") row("Group gap") col(`col') ///
        expr("_b[overall:difference]")

    * explained
    post_lincom, handle(`handle') panel("explained") row("Employment and financial") col(`col') ///
        expr("_b[explained:emp_red] + _b[explained:emp_loss] + _b[explained:key_yes] + _b[explained:selfemp_yes] + _b[explained:fin_base_yes] + _b[explained:fin_better] + _b[explained:fin_worse]")

    post_lincom, handle(`handle') panel("explained") row("Housing") col(`col') ///
        expr("_b[explained:bedratio_base] + _b[explained:bedratio_sq] + _b[explained:hsrooms_base2] + _b[explained:rooms_sq]")

    post_lincom, handle(`handle') panel("explained") row("Health") col(`col') ///
        expr("_b[explained:covid_symp] + _b[explained:cc_resp] + _b[explained:cc_cardio] + _b[explained:cc_endo] + _b[explained:cc_arth] + _b[explained:cc_other]")

    post_lincom, handle(`handle') panel("explained") row("Household composition") col(`col') ///
        expr("_b[explained:single_occ] + _b[explained:base_ndep] + _b[explained:kids_sq] + _b[explained:single_kids] + _b[explained:single_kids_sq]")

    post_lincom, handle(`handle') panel("explained") row("Sex") col(`col') ///
        expr("_b[explained:female]")

    post_lincom, handle(`handle') panel("explained") row("Age") col(`col') ///
        expr("_b[explained:age16_29] + _b[explained:age30_49] + _b[explained:age50_69]")

    post_lincom, handle(`handle') panel("explained") row("Total composition effect") col(`col') ///
        expr("_b[overall:explained]")

    * unexplained
    post_lincom, handle(`handle') panel("unexplained") row("Employment and financial") col(`col') ///
        expr("_b[unexplained:emp_red] + _b[unexplained:emp_loss] + _b[unexplained:key_yes] + _b[unexplained:selfemp_yes] + _b[unexplained:fin_base_yes] + _b[unexplained:fin_better] + _b[unexplained:fin_worse]")

    post_lincom, handle(`handle') panel("unexplained") row("Housing") col(`col') ///
        expr("_b[unexplained:bedratio_base] + _b[unexplained:bedratio_sq] + _b[unexplained:hsrooms_base2] + _b[unexplained:rooms_sq]")

    post_lincom, handle(`handle') panel("unexplained") row("Health") col(`col') ///
        expr("_b[unexplained:covid_symp] + _b[unexplained:cc_resp] + _b[unexplained:cc_cardio] + _b[unexplained:cc_endo] + _b[unexplained:cc_arth] + _b[unexplained:cc_other]")

    post_lincom, handle(`handle') panel("unexplained") row("Household composition") col(`col') ///
        expr("_b[unexplained:single_occ] + _b[unexplained:base_ndep] + _b[unexplained:kids_sq] + _b[unexplained:single_kids] + _b[unexplained:single_kids_sq]")

    post_lincom, handle(`handle') panel("unexplained") row("Sex") col(`col') ///
        expr("_b[unexplained:female]")

    post_lincom, handle(`handle') panel("unexplained") row("Age") col(`col') ///
        expr("_b[unexplained:age16_29] + _b[unexplained:age30_49] + _b[unexplained:age50_69]")

    post_lincom, handle(`handle') panel("unexplained") row("Constant") col(`col') ///
        expr("_b[unexplained:_cons]")

    post_lincom, handle(`handle') panel("unexplained") row("Total structural effect") col(`col') ///
        expr("_b[overall:unexplained]")

    quietly count
    post `handle' ("footer") ("Observations") (`col') (r(N)) (.) (.)
end


************************* Bame decomposition-ready
use "${work}/BASE_delta2019_CA_zinv_COVIDWGT.dta", clear
capture drop ca_hours_clean ca_blhours_clean hours_reduced furlough ///
             emp_change keyworker selfemp_only

gen double ca_hours_clean = ca_hours
replace ca_hours_clean = . if ca_hours_clean < 0

gen double ca_blhours_clean = ca_blhours
replace ca_blhours_clean = . if ca_blhours_clean < 0

gen byte hours_reduced = .
replace hours_reduced = (ca_hours_clean + 1 < ca_blhours_clean) ///
    if ca_blhours_clean>0 & !missing(ca_hours_clean, ca_blhours_clean)

gen byte furlough = .
replace furlough = (ca_furlough==1) if !missing(ca_furlough)

* emp_change:
* 1 = No change  (includes prework==0)
* 2 = Reduction
* 3 = Job loss
gen byte emp_change = .
replace emp_change = 3 if prework==1 & ca_sempderived==4
replace emp_change = 2 if prework==1 & inlist(ca_sempderived,1,2,3) ///
    & (furlough==1 | hours_reduced==1)
replace emp_change = 1 if prework==0
replace emp_change = 1 if prework==1 & inlist(ca_sempderived,1,2,3) ///
    & ((furlough==0 | missing(furlough)) & (hours_reduced==0 | missing(hours_reduced)))

label define empchg 1 "No change" 2 "Reduction" 3 "Job loss", replace
label values emp_change empchg

* keyworker:
* 1 only if prework==1 & stable employment & key worker
* 0 otherwise (including prework==0, reduction, job loss)
gen byte keyworker = .
replace keyworker = 1 if prework==1 & emp_change==1 & ca_keyworker==1
replace keyworker = 0 if prework==1 & emp_change==1 & ca_keyworker==2
replace keyworker = 0 if prework==0
replace keyworker = 0 if prework==1 & inlist(emp_change,2,3)
label define keyw 0 "No" 1 "Yes", replace
label values keyworker keyw

* selfemp_only:
* 1 only if prework==1 & self-employed only
* 0 otherwise
gen byte selfemp_only = .
replace selfemp_only = 1 if prework==1 & ca_blwork==2
replace selfemp_only = 0 if prework==1 & inlist(ca_blwork,1,3)
replace selfemp_only = 0 if prework==0
label define selfemp 0 "No" 1 "Yes", replace
label values selfemp_only selfemp


* 2) decomposition-ready dummies
* employment
gen byte emp_red  = (emp_change==2) if !missing(emp_change)
gen byte emp_loss = (emp_change==3) if !missing(emp_change)

gen byte key_yes = (keyworker==1) if !missing(keyworker)
replace key_yes = 0 if missing(key_yes) & !missing(emp_change)

gen byte selfemp_yes = (selfemp_only==1) if !missing(selfemp_only)
replace selfemp_yes = 0 if missing(selfemp_yes) & !missing(emp_change)


* financial
gen byte fin_base_yes = (fin_diff_base==1) if !missing(fin_diff_base)

gen byte fin_better = (fin_change==1) if !missing(fin_change)
gen byte fin_worse  = (fin_change==3) if !missing(fin_change)

* housing: continuous + square
gen double bedratio_sq = bedratio_base^2 if !missing(bedratio_base)
gen double rooms_sq    = hsrooms_base2^2 if !missing(hsrooms_base2)

* health
foreach v in covid_symp cc_resp cc_cardio cc_endo cc_arth cc_other {
    replace `v' = . if `v' < 0
}

* household composition: continuous version
capture drop kids_sq single_kids single_kids_sq

gen double kids_sq = base_ndep^2 if !missing(base_ndep)

gen double single_kids = .
replace single_kids = single_occ * base_ndep ///
    if !missing(single_occ, base_ndep)

gen double single_kids_sq = .
replace single_kids_sq = single_occ * kids_sq ///
    if !missing(single_occ, kids_sq)


* demographics
gen byte female = (sex_bin==2) if !missing(sex_bin)

gen byte age16_29 = (agegrp==1) if !missing(agegrp)
gen byte age30_49 = (agegrp==2) if !missing(agegrp)
gen byte age50_69 = (agegrp==3) if !missing(agegrp)
* agegrp==4 (70+) is omitted base

capture drop sample_c1 miss_c1
egen miss_c1 = rowmiss( ///
    d_ghq_likert bame ///
    emp_red emp_loss key_yes selfemp_yes ///
    fin_base_yes fin_better fin_worse ///
    bedratio_base bedratio_sq hsrooms_base2 rooms_sq ///
    covid_symp cc_resp cc_cardio cc_endo cc_arth cc_other ///
    single_occ base_ndep kids_sq single_kids single_kids_sq ///
    female age16_29 age30_49 age50_69 ///
    wgt_ca psu_ca strata_ca )

gen byte sample_c1 = (miss_c1==0)
keep if sample_c1==1

count
tab bame

svyset psu_ca [pweight=wgt_ca], strata(strata_ca) singleunit(scaled)

local empfin    "emp_red emp_loss key_yes selfemp_yes fin_base_yes fin_better fin_worse"
local housing   "bedratio_base bedratio_sq hsrooms_base2 rooms_sq"
local health    "covid_symp cc_resp cc_cardio cc_endo cc_arth cc_other"
local hhcomp    "single_occ base_ndep kids_sq single_kids single_kids_sq"
local sexage    "female age16_29 age30_49 age50_69"

local allvars   "`empfin' `housing' `health' `hhcomp' `sexage'"
local houseonly "`housing'"
local hhdemo    "`housing' `hhcomp' `sexage'"
local nohouse   "`empfin' `health' `hhcomp' `sexage'"

tempfile bame_res
tempname bamehold

postfile `bamehold' ///
    str15 panel ///
    str40 row ///
    byte col ///
    double coef se p ///
    using `bame_res', replace
	
* Column 1: pooled price, all factors
oaxaca d_ghq_likert `allvars' [pw=wgt_ca], ///
    by(bame) pooled detail vce(cluster psu_ca)
collect_decomp, handle(`bamehold') col(1)

* Column 2: Non-BAME price, all factors
oaxaca d_ghq_likert `allvars' [pw=wgt_ca], ///
    by(bame) weight(1) detail vce(cluster psu_ca)
collect_decomp, handle(`bamehold') col(2)

* Column 3: pooled price, Housing only
oaxaca d_ghq_likert `houseonly' [pw=wgt_ca], ///
    by(bame) pooled detail vce(cluster psu_ca)
collect_decomp, handle(`bamehold') col(3)

* Column 4: pooled price, Housing + Household composition + Sex + Age
oaxaca d_ghq_likert `hhdemo' [pw=wgt_ca], ///
    by(bame) pooled detail vce(cluster psu_ca)
collect_decomp, handle(`bamehold') col(4)

* Column 5: pooled price, all factors except Housing
oaxaca d_ghq_likert `nohouse' [pw=wgt_ca], ///
    by(bame) pooled detail vce(cluster psu_ca)
collect_decomp, handle(`bamehold') col(5)

postclose `bamehold'
use `bame_res', clear
sort panel row col
save "${out}/Decomposition/bame_decomp_tidy.dta", replace
export delimited using "${out}/Decomposition/bame_decomp_tidy.csv", replace



************************** BIP decomposition-ready
use "${work}/BASE_delta2019_CA_zinv_COVIDWGT_BIP.dta", clear

capture drop ca_hours_clean ca_blhours_clean hours_reduced furlough ///
             emp_change keyworker selfemp_only

gen double ca_hours_clean = ca_hours
replace ca_hours_clean = . if ca_hours_clean < 0

gen double ca_blhours_clean = ca_blhours
replace ca_blhours_clean = . if ca_blhours_clean < 0

gen byte hours_reduced = .
replace hours_reduced = (ca_hours_clean + 1 < ca_blhours_clean) ///
    if ca_blhours_clean>0 & !missing(ca_hours_clean, ca_blhours_clean)

gen byte furlough = .
replace furlough = (ca_furlough==1) if !missing(ca_furlough)

* emp_change:
* 1 = No change  (includes prework==0)
* 2 = Reduction
* 3 = Job loss
gen byte emp_change = .
replace emp_change = 3 if prework==1 & ca_sempderived==4
replace emp_change = 2 if prework==1 & inlist(ca_sempderived,1,2,3) ///
    & (furlough==1 | hours_reduced==1)
replace emp_change = 1 if prework==0
replace emp_change = 1 if prework==1 & inlist(ca_sempderived,1,2,3) ///
    & ((furlough==0 | missing(furlough)) & (hours_reduced==0 | missing(hours_reduced)))

label define empchg 1 "No change" 2 "Reduction" 3 "Job loss", replace
label values emp_change empchg

* keyworker:
* 1 only if prework==1 & stable employment & key worker
* 0 otherwise (including prework==0, reduction, job loss)
gen byte keyworker = .
replace keyworker = 1 if prework==1 & emp_change==1 & ca_keyworker==1
replace keyworker = 0 if prework==1 & emp_change==1 & ca_keyworker==2
replace keyworker = 0 if prework==0
replace keyworker = 0 if prework==1 & inlist(emp_change,2,3)
label define keyw 0 "No" 1 "Yes", replace
label values keyworker keyw

* selfemp_only:
* 1 only if prework==1 & self-employed only
* 0 otherwise
gen byte selfemp_only = .
replace selfemp_only = 1 if prework==1 & ca_blwork==2
replace selfemp_only = 0 if prework==1 & inlist(ca_blwork,1,3)
replace selfemp_only = 0 if prework==0
label define selfemp 0 "No" 1 "Yes", replace
label values selfemp_only selfemp




* 2) decomposition-ready dummies
* employment
gen byte emp_red  = (emp_change==2) if !missing(emp_change)
gen byte emp_loss = (emp_change==3) if !missing(emp_change)

gen byte key_yes = (keyworker==1) if !missing(keyworker)
replace key_yes = 0 if missing(key_yes) & !missing(emp_change)

gen byte selfemp_yes = (selfemp_only==1) if !missing(selfemp_only)
replace selfemp_yes = 0 if missing(selfemp_yes) & !missing(emp_change)


* financial
gen byte fin_base_yes = (fin_diff_base==1) if !missing(fin_diff_base)

gen byte fin_better = (fin_change==1) if !missing(fin_change)
gen byte fin_worse  = (fin_change==3) if !missing(fin_change)

* housing: continuous + square
gen double bedratio_sq = bedratio_base^2 if !missing(bedratio_base)
gen double rooms_sq    = hsrooms_base2^2 if !missing(hsrooms_base2)

* health
foreach v in covid_symp cc_resp cc_cardio cc_endo cc_arth cc_other {
    replace `v' = . if `v' < 0
}

* household composition: continuous version
capture drop kids_sq single_kids single_kids_sq

gen double kids_sq = base_ndep^2 if !missing(base_ndep)

gen double single_kids = .
replace single_kids = single_occ * base_ndep ///
    if !missing(single_occ, base_ndep)

gen double single_kids_sq = .
replace single_kids_sq = single_occ * kids_sq ///
    if !missing(single_occ, kids_sq)


* demographics
gen byte female = (sex_bin==2) if !missing(sex_bin)

gen byte age16_29 = (agegrp==1) if !missing(agegrp)
gen byte age30_49 = (agegrp==2) if !missing(agegrp)
gen byte age50_69 = (agegrp==3) if !missing(agegrp)
* agegrp==4 (70+) is omitted base

capture drop sample_c1 miss_c1
egen miss_c1 = rowmiss( ///
    d_ghq_likert bip ///
    emp_red emp_loss key_yes selfemp_yes ///
    fin_base_yes fin_better fin_worse ///
    bedratio_base bedratio_sq hsrooms_base2 rooms_sq ///
    covid_symp cc_resp cc_cardio cc_endo cc_arth cc_other ///
    single_occ base_ndep kids_sq single_kids single_kids_sq ///
    female age16_29 age30_49 age50_69 ///
    wgt_ca psu_ca strata_ca )

gen byte sample_c1 = (miss_c1==0)
keep if sample_c1==1

count
tab bip

svyset psu_ca [pweight=wgt_ca], strata(strata_ca) singleunit(scaled)

local empfin    "emp_red emp_loss key_yes selfemp_yes fin_base_yes fin_better fin_worse"
local housing   "bedratio_base bedratio_sq hsrooms_base2 rooms_sq"
local health    "covid_symp cc_resp cc_cardio cc_endo cc_arth cc_other"
local hhcomp    "single_occ base_ndep kids_sq single_kids single_kids_sq"
local sexage    "female age16_29 age30_49 age50_69"

local allvars   "`empfin' `housing' `health' `hhcomp' `sexage'"
local houseonly "`housing'"
local hhdemo    "`housing' `hhcomp' `sexage'"
local nohouse   "`empfin' `health' `hhcomp' `sexage'"


tempfile bip_res
tempname biphold

postfile `biphold' ///
    str15 panel ///
    str40 row ///
    byte col ///
    double coef se p ///
    using `bip_res', replace
	
	

* Column 1: pooled price, all factors
oaxaca d_ghq_likert `allvars' [pw=wgt_ca], ///
    by(bip) pooled detail vce(cluster psu_ca)
collect_decomp, handle(`biphold') col(1)

* Column 2: Non-BIP price, all factors
oaxaca d_ghq_likert `allvars' [pw=wgt_ca], ///
    by(bip) weight(1) detail vce(cluster psu_ca)
collect_decomp, handle(`biphold') col(2)

* Column 3: pooled price, Housing only
oaxaca d_ghq_likert `houseonly' [pw=wgt_ca], ///
    by(bip) pooled detail vce(cluster psu_ca)
collect_decomp, handle(`biphold') col(3)

* Column 4: pooled price, Housing + Household composition + Sex + Age
oaxaca d_ghq_likert `hhdemo' [pw=wgt_ca], ///
    by(bip) pooled detail vce(cluster psu_ca)
collect_decomp, handle(`biphold') col(4)

* Column 5: pooled price, all factors except Housing
oaxaca d_ghq_likert `nohouse' [pw=wgt_ca], ///
    by(bip) pooled detail vce(cluster psu_ca)
collect_decomp, handle(`biphold') col(5)

postclose `biphold'
use `bip_res', clear
sort panel row col
save "${out}/Decomposition/bip_decomp_tidy.dta", replace
export delimited using "${out}/Decomposition/bip_decomp_tidy.csv", replace
