use "${work}/BASE_delta2019_CA_zinv_COVIDWGT_bip.dta", clear

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

tempfile analysis_sample
save `analysis_sample', replace



****************************************************
* Helper programs: post regression and oaxaca results
****************************************************

capture program drop post_lc
program define post_lc
    args handle table col model panel row expr

    capture quietly lincom `expr'

    if _rc {
        post `handle' ("`table'") (`col') ("`model'") ("`panel'") ("`row'") ///
            (.) (.) (.) (.)
    }
    else {
        post `handle' ("`table'") (`col') ("`model'") ("`panel'") ("`row'") ///
            (r(estimate)) (r(se)) (r(p)) (.)
    }
end

capture program drop post_obs
program define post_obs
    args handle table col model N

    post `handle' ("`table'") (`col') ("`model'") ("footer") ("Observations") ///
        (.) (.) (.) (`N')
end




****************************************************
* Save Model 1 and Model 2 regression results
****************************************************

tempfile regres
tempname reghold

postfile `reghold' ///
    str20 table ///
    byte col ///
    str30 model ///
    str20 panel ///
    str60 row ///
    double coef se p N ///
    using `regres', replace
	
local controls ///
    emp_red emp_loss key_yes selfemp_yes ///
    fin_base_yes fin_better fin_worse ///
    c.bedratio_base c.bedratio_sq c.hsrooms_base2 c.rooms_sq ///
    covid_symp cc_resp cc_cardio cc_endo cc_arth cc_other ///
    single_occ c.base_ndep c.kids_sq c.single_kids c.single_kids_sq ///
    female age16_29 age30_49 age50_69
	
	
	
	
****************************************************
* Model 1: pooled model
****************************************************

svy: regress d_ghq_likert i.bip `controls'

count
local N_pool = r(N)

post_lc `reghold' "regression" 1 "Model 1: pooled" "main" "BIP" "_b[1.bip]"

post_lc `reghold' "regression" 1 "Model 1: pooled" "employment" "Employment reduction" "_b[emp_red]"
post_lc `reghold' "regression" 1 "Model 1: pooled" "employment" "Job loss" "_b[emp_loss]"
post_lc `reghold' "regression" 1 "Model 1: pooled" "employment" "Key worker" "_b[key_yes]"
post_lc `reghold' "regression" 1 "Model 1: pooled" "employment" "Self-employed" "_b[selfemp_yes]"

post_lc `reghold' "regression" 1 "Model 1: pooled" "financial" "Financial difficulties" "_b[fin_base_yes]"
post_lc `reghold' "regression" 1 "Model 1: pooled" "financial" "Financial better" "_b[fin_better]"
post_lc `reghold' "regression" 1 "Model 1: pooled" "financial" "Financial worse" "_b[fin_worse]"

post_lc `reghold' "regression" 1 "Model 1: pooled" "housing" "Bedroom-per-person ratio" "_b[bedratio_base]"
post_lc `reghold' "regression" 1 "Model 1: pooled" "housing" "Bedroom-per-person ratio squared" "_b[bedratio_sq]"
post_lc `reghold' "regression" 1 "Model 1: pooled" "housing" "Number of rooms" "_b[hsrooms_base2]"
post_lc `reghold' "regression" 1 "Model 1: pooled" "housing" "Number of rooms squared" "_b[rooms_sq]"

post_lc `reghold' "regression" 1 "Model 1: pooled" "health" "COVID symptoms" "_b[covid_symp]"
post_lc `reghold' "regression" 1 "Model 1: pooled" "health" "Respiratory condition" "_b[cc_resp]"
post_lc `reghold' "regression" 1 "Model 1: pooled" "health" "Cardiovascular condition" "_b[cc_cardio]"
post_lc `reghold' "regression" 1 "Model 1: pooled" "health" "Endocrine condition" "_b[cc_endo]"
post_lc `reghold' "regression" 1 "Model 1: pooled" "health" "Arthritis" "_b[cc_arth]"
post_lc `reghold' "regression" 1 "Model 1: pooled" "health" "Other chronic condition" "_b[cc_other]"

post_lc `reghold' "regression" 1 "Model 1: pooled" "household" "Single occupancy" "_b[single_occ]"
post_lc `reghold' "regression" 1 "Model 1: pooled" "household" "Dependent children" "_b[base_ndep]"
post_lc `reghold' "regression" 1 "Model 1: pooled" "household" "Dependent children squared" "_b[kids_sq]"
post_lc `reghold' "regression" 1 "Model 1: pooled" "household" "Single occupancy x children" "_b[single_kids]"
post_lc `reghold' "regression" 1 "Model 1: pooled" "household" "Single occupancy x children squared" "_b[single_kids_sq]"

post_lc `reghold' "regression" 1 "Model 1: pooled" "demographics" "Female" "_b[female]"
post_lc `reghold' "regression" 1 "Model 1: pooled" "demographics" "Age 16-29" "_b[age16_29]"
post_lc `reghold' "regression" 1 "Model 1: pooled" "demographics" "Age 30-49" "_b[age30_49]"
post_lc `reghold' "regression" 1 "Model 1: pooled" "demographics" "Age 50-69" "_b[age50_69]"

post_lc `reghold' "regression" 1 "Model 1: pooled" "constant" "Constant" "_b[_cons]"
post_obs `reghold' "regression" 1 "Model 1: pooled" `N_pool'





****************************************************
* Model 2: BIP only
****************************************************

svy, subpop(if bip==1): regress d_ghq_likert `controls'

count if bip==1
local N_bip = r(N)

post_lc `reghold' "regression" 2 "Model 2: BIP" "employment" "Employment reduction" "_b[emp_red]"
post_lc `reghold' "regression" 2 "Model 2: BIP" "employment" "Job loss" "_b[emp_loss]"
post_lc `reghold' "regression" 2 "Model 2: BIP" "employment" "Key worker" "_b[key_yes]"
post_lc `reghold' "regression" 2 "Model 2: BIP" "employment" "Self-employed" "_b[selfemp_yes]"

post_lc `reghold' "regression" 2 "Model 2: BIP" "financial" "Financial difficulties" "_b[fin_base_yes]"
post_lc `reghold' "regression" 2 "Model 2: BIP" "financial" "Financial better" "_b[fin_better]"
post_lc `reghold' "regression" 2 "Model 2: BIP" "financial" "Financial worse" "_b[fin_worse]"

post_lc `reghold' "regression" 2 "Model 2: BIP" "housing" "Bedroom-per-person ratio" "_b[bedratio_base]"
post_lc `reghold' "regression" 2 "Model 2: BIP" "housing" "Bedroom-per-person ratio squared" "_b[bedratio_sq]"
post_lc `reghold' "regression" 2 "Model 2: BIP" "housing" "Number of rooms" "_b[hsrooms_base2]"
post_lc `reghold' "regression" 2 "Model 2: BIP" "housing" "Number of rooms squared" "_b[rooms_sq]"

post_lc `reghold' "regression" 2 "Model 2: BIP" "health" "COVID symptoms" "_b[covid_symp]"
post_lc `reghold' "regression" 2 "Model 2: BIP" "health" "Respiratory condition" "_b[cc_resp]"
post_lc `reghold' "regression" 2 "Model 2: BIP" "health" "Cardiovascular condition" "_b[cc_cardio]"
post_lc `reghold' "regression" 2 "Model 2: BIP" "health" "Endocrine condition" "_b[cc_endo]"
post_lc `reghold' "regression" 2 "Model 2: BIP" "health" "Arthritis" "_b[cc_arth]"
post_lc `reghold' "regression" 2 "Model 2: BIP" "health" "Other chronic condition" "_b[cc_other]"

post_lc `reghold' "regression" 2 "Model 2: BIP" "household" "Single occupancy" "_b[single_occ]"
post_lc `reghold' "regression" 2 "Model 2: BIP" "household" "Dependent children" "_b[base_ndep]"
post_lc `reghold' "regression" 2 "Model 2: BIP" "household" "Dependent children squared" "_b[kids_sq]"
post_lc `reghold' "regression" 2 "Model 2: BIP" "household" "Single occupancy x children" "_b[single_kids]"
post_lc `reghold' "regression" 2 "Model 2: BIP" "household" "Single occupancy x children squared" "_b[single_kids_sq]"

post_lc `reghold' "regression" 2 "Model 2: BIP" "demographics" "Female" "_b[female]"
post_lc `reghold' "regression" 2 "Model 2: BIP" "demographics" "Age 16-29" "_b[age16_29]"
post_lc `reghold' "regression" 2 "Model 2: BIP" "demographics" "Age 30-49" "_b[age30_49]"
post_lc `reghold' "regression" 2 "Model 2: BIP" "demographics" "Age 50-69" "_b[age50_69]"

post_lc `reghold' "regression" 2 "Model 2: BIP" "constant" "Constant" "_b[_cons]"
post_obs `reghold' "regression" 2 "Model 2: BIP" `N_bip'


****************************************************
* Model 2: WM only
****************************************************

svy, subpop(if bip==0): regress d_ghq_likert `controls'

count if bip==0
local N_nonbip = r(N)

post_lc `reghold' "regression" 3 "Model 2: Non-BIP" "employment" "Employment reduction" "_b[emp_red]"
post_lc `reghold' "regression" 3 "Model 2: Non-BIP" "employment" "Job loss" "_b[emp_loss]"
post_lc `reghold' "regression" 3 "Model 2: Non-BIP" "employment" "Key worker" "_b[key_yes]"
post_lc `reghold' "regression" 3 "Model 2: Non-BIP" "employment" "Self-employed" "_b[selfemp_yes]"

post_lc `reghold' "regression" 3 "Model 2: Non-BIP" "financial" "Financial difficulties" "_b[fin_base_yes]"
post_lc `reghold' "regression" 3 "Model 2: Non-BIP" "financial" "Financial better" "_b[fin_better]"
post_lc `reghold' "regression" 3 "Model 2: Non-BIP" "financial" "Financial worse" "_b[fin_worse]"

post_lc `reghold' "regression" 3 "Model 2: Non-BIP" "housing" "Bedroom-per-person ratio" "_b[bedratio_base]"
post_lc `reghold' "regression" 3 "Model 2: Non-BIP" "housing" "Bedroom-per-person ratio squared" "_b[bedratio_sq]"
post_lc `reghold' "regression" 3 "Model 2: Non-BIP" "housing" "Number of rooms" "_b[hsrooms_base2]"
post_lc `reghold' "regression" 3 "Model 2: Non-BIP" "housing" "Number of rooms squared" "_b[rooms_sq]"

post_lc `reghold' "regression" 3 "Model 2: Non-BIP" "health" "COVID symptoms" "_b[covid_symp]"
post_lc `reghold' "regression" 3 "Model 2: Non-BIP" "health" "Respiratory condition" "_b[cc_resp]"
post_lc `reghold' "regression" 3 "Model 2: Non-BIP" "health" "Cardiovascular condition" "_b[cc_cardio]"
post_lc `reghold' "regression" 3 "Model 2: Non-BIP" "health" "Endocrine condition" "_b[cc_endo]"
post_lc `reghold' "regression" 3 "Model 2: Non-BIP" "health" "Arthritis" "_b[cc_arth]"
post_lc `reghold' "regression" 3 "Model 2: Non-BIP" "health" "Other chronic condition" "_b[cc_other]"

post_lc `reghold' "regression" 3 "Model 2: Non-BIP" "household" "Single occupancy" "_b[single_occ]"
post_lc `reghold' "regression" 3 "Model 2: Non-BIP" "household" "Dependent children" "_b[base_ndep]"
post_lc `reghold' "regression" 3 "Model 2: Non-BIP" "household" "Dependent children squared" "_b[kids_sq]"
post_lc `reghold' "regression" 3 "Model 2: Non-BIP" "household" "Single occupancy x children" "_b[single_kids]"
post_lc `reghold' "regression" 3 "Model 2: Non-BIP" "household" "Single occupancy x children squared" "_b[single_kids_sq]"

post_lc `reghold' "regression" 3 "Model 2: Non-BIP" "demographics" "Female" "_b[female]"
post_lc `reghold' "regression" 3 "Model 2: Non-BIP" "demographics" "Age 16-29" "_b[age16_29]"
post_lc `reghold' "regression" 3 "Model 2: Non-BIP" "demographics" "Age 30-49" "_b[age30_49]"
post_lc `reghold' "regression" 3 "Model 2: Non-BIP" "demographics" "Age 50-69" "_b[age50_69]"

post_lc `reghold' "regression" 3 "Model 2: Non-BIP" "constant" "Constant" "_b[_cons]"
post_obs `reghold' "regression" 3 "Model 2: Non-BIP" `N_nonbip'


postclose `reghold'

use `regres', clear
sort panel row col

save "${out}/Appendix/BIP/appendix_bip.dta", replace
export delimited using "${out}/Appendix/BIP/appendix_bip.csv", replace


****************************************************
* Reload analysis sample before Oaxaca
****************************************************
use `analysis_sample', clear
svyset psu_ca [pweight=wgt_ca], strata(strata_ca) singleunit(scaled)


****************************************************
* Save Oaxaca decomposition results
****************************************************

tempfile oxres
tempname oxhold

postfile `oxhold' ///
    str20 table ///
    byte col ///
    str30 model ///
    str40 panel ///
    str80 row ///
    double coef se p N ///
    using `oxres', replace

capture program drop post_ox_lc
program define post_ox_lc
    args handle col model panel row expr

    capture quietly lincom `expr'

    if _rc {
        post `handle' ("oaxaca") (`col') ("`model'") ("`panel'") ("`row'") ///
            (.) (.) (.) (.)
    }
    else {
        post `handle' ("oaxaca") (`col') ("`model'") ("`panel'") ("`row'") ///
            (r(estimate)) (r(se)) (r(p)) (.)
    }
end

capture program drop collect_ox_detail
program define collect_ox_detail
    args handle col model

    *-----------------------------*
    * Overall
    *-----------------------------*
    post_ox_lc `handle' `col' "`model'" "overall" "Group gap" ///
        "_b[overall:difference]"

    post_ox_lc `handle' `col' "`model'" "overall" "Total composition effect" ///
        "_b[overall:explained]"

    post_ox_lc `handle' `col' "`model'" "overall" "Total structural effect" ///
        "_b[overall:unexplained]"


    *============================================================*
    * Composition effect: detailed variables
    *============================================================*

    * Employment
    post_ox_lc `handle' `col' "`model'" "explained_employment" "Employment reduction" ///
        "_b[explained:emp_red]"

    post_ox_lc `handle' `col' "`model'" "explained_employment" "Job loss" ///
        "_b[explained:emp_loss]"

    post_ox_lc `handle' `col' "`model'" "explained_employment" "Key worker" ///
        "_b[explained:key_yes]"

    post_ox_lc `handle' `col' "`model'" "explained_employment" "Self-employed" ///
        "_b[explained:selfemp_yes]"


    * Financial
    post_ox_lc `handle' `col' "`model'" "explained_financial" "Financial difficulties" ///
        "_b[explained:fin_base_yes]"

    post_ox_lc `handle' `col' "`model'" "explained_financial" "Financial status improved" ///
        "_b[explained:fin_better]"

    post_ox_lc `handle' `col' "`model'" "explained_financial" "Financial status worsened" ///
        "_b[explained:fin_worse]"


    * Housing
    post_ox_lc `handle' `col' "`model'" "explained_housing" "Bedroom-per-person ratio" ///
        "_b[explained:bedratio_base]"

    post_ox_lc `handle' `col' "`model'" "explained_housing" "Bedroom-per-person ratio squared" ///
        "_b[explained:bedratio_sq]"

    post_ox_lc `handle' `col' "`model'" "explained_housing" "Number of rooms" ///
        "_b[explained:hsrooms_base2]"

    post_ox_lc `handle' `col' "`model'" "explained_housing" "Number of rooms squared" ///
        "_b[explained:rooms_sq]"


    * Health
    post_ox_lc `handle' `col' "`model'" "explained_health" "COVID symptoms" ///
        "_b[explained:covid_symp]"

    post_ox_lc `handle' `col' "`model'" "explained_health" "Respiratory condition" ///
        "_b[explained:cc_resp]"

    post_ox_lc `handle' `col' "`model'" "explained_health" "Cardiovascular condition" ///
        "_b[explained:cc_cardio]"

    post_ox_lc `handle' `col' "`model'" "explained_health" "Endocrine condition" ///
        "_b[explained:cc_endo]"

    post_ox_lc `handle' `col' "`model'" "explained_health" "Arthritis" ///
        "_b[explained:cc_arth]"

    post_ox_lc `handle' `col' "`model'" "explained_health" "Other chronic condition" ///
        "_b[explained:cc_other]"


    * Household composition
    post_ox_lc `handle' `col' "`model'" "explained_household" "Single occupancy" ///
        "_b[explained:single_occ]"

    post_ox_lc `handle' `col' "`model'" "explained_household" "Dependent children" ///
        "_b[explained:base_ndep]"

    post_ox_lc `handle' `col' "`model'" "explained_household" "Dependent children squared" ///
        "_b[explained:kids_sq]"

    post_ox_lc `handle' `col' "`model'" "explained_household" "Single occupancy x children" ///
        "_b[explained:single_kids]"

    post_ox_lc `handle' `col' "`model'" "explained_household" "Single occupancy x children squared" ///
        "_b[explained:single_kids_sq]"


    * Demographics
    post_ox_lc `handle' `col' "`model'" "explained_demographics" "Female" ///
        "_b[explained:female]"

    post_ox_lc `handle' `col' "`model'" "explained_demographics" "Age 16-29" ///
        "_b[explained:age16_29]"

    post_ox_lc `handle' `col' "`model'" "explained_demographics" "Age 30-49" ///
        "_b[explained:age30_49]"

    post_ox_lc `handle' `col' "`model'" "explained_demographics" "Age 50-69" ///
        "_b[explained:age50_69]"


    *============================================================*
    * Structural effect: detailed variables
    *============================================================*

    * Employment
    post_ox_lc `handle' `col' "`model'" "unexplained_employment" "Employment reduction" ///
        "_b[unexplained:emp_red]"

    post_ox_lc `handle' `col' "`model'" "unexplained_employment" "Job loss" ///
        "_b[unexplained:emp_loss]"

    post_ox_lc `handle' `col' "`model'" "unexplained_employment" "Key worker" ///
        "_b[unexplained:key_yes]"

    post_ox_lc `handle' `col' "`model'" "unexplained_employment" "Self-employed" ///
        "_b[unexplained:selfemp_yes]"


    * Financial
    post_ox_lc `handle' `col' "`model'" "unexplained_financial" "Financial difficulties" ///
        "_b[unexplained:fin_base_yes]"

    post_ox_lc `handle' `col' "`model'" "unexplained_financial" "Financial status improved" ///
        "_b[unexplained:fin_better]"

    post_ox_lc `handle' `col' "`model'" "unexplained_financial" "Financial status worsened" ///
        "_b[unexplained:fin_worse]"


    * Housing
    post_ox_lc `handle' `col' "`model'" "unexplained_housing" "Bedroom-per-person ratio" ///
        "_b[unexplained:bedratio_base]"

    post_ox_lc `handle' `col' "`model'" "unexplained_housing" "Bedroom-per-person ratio squared" ///
        "_b[unexplained:bedratio_sq]"

    post_ox_lc `handle' `col' "`model'" "unexplained_housing" "Number of rooms" ///
        "_b[unexplained:hsrooms_base2]"

    post_ox_lc `handle' `col' "`model'" "unexplained_housing" "Number of rooms squared" ///
        "_b[unexplained:rooms_sq]"


    * Health
    post_ox_lc `handle' `col' "`model'" "unexplained_health" "COVID symptoms" ///
        "_b[unexplained:covid_symp]"

    post_ox_lc `handle' `col' "`model'" "unexplained_health" "Respiratory condition" ///
        "_b[unexplained:cc_resp]"

    post_ox_lc `handle' `col' "`model'" "unexplained_health" "Cardiovascular condition" ///
        "_b[unexplained:cc_cardio]"

    post_ox_lc `handle' `col' "`model'" "unexplained_health" "Endocrine condition" ///
        "_b[unexplained:cc_endo]"

    post_ox_lc `handle' `col' "`model'" "unexplained_health" "Arthritis" ///
        "_b[unexplained:cc_arth]"

    post_ox_lc `handle' `col' "`model'" "unexplained_health" "Other chronic condition" ///
        "_b[unexplained:cc_other]"


    * Household composition
    post_ox_lc `handle' `col' "`model'" "unexplained_household" "Single occupancy" ///
        "_b[unexplained:single_occ]"

    post_ox_lc `handle' `col' "`model'" "unexplained_household" "Dependent children" ///
        "_b[unexplained:base_ndep]"

    post_ox_lc `handle' `col' "`model'" "unexplained_household" "Dependent children squared" ///
        "_b[unexplained:kids_sq]"

    post_ox_lc `handle' `col' "`model'" "unexplained_household" "Single occupancy x children" ///
        "_b[unexplained:single_kids]"

    post_ox_lc `handle' `col' "`model'" "unexplained_household" "Single occupancy x children squared" ///
        "_b[unexplained:single_kids_sq]"


    * Demographics
    post_ox_lc `handle' `col' "`model'" "unexplained_demographics" "Female" ///
        "_b[unexplained:female]"

    post_ox_lc `handle' `col' "`model'" "unexplained_demographics" "Age 16-29" ///
        "_b[unexplained:age16_29]"

    post_ox_lc `handle' `col' "`model'" "unexplained_demographics" "Age 30-49" ///
        "_b[unexplained:age30_49]"

    post_ox_lc `handle' `col' "`model'" "unexplained_demographics" "Age 50-69" ///
        "_b[unexplained:age50_69]"


    * Constant
    post_ox_lc `handle' `col' "`model'" "unexplained_constant" "Constant" ///
        "_b[unexplained:_cons]"


    * Observations
    quietly count
    post `handle' ("oaxaca") (`col') ("`model'") ("footer") ("Observations") ///
        (.) (.) (.) (r(N))
end

*--------------------------------------------------*
* Column 1: pooled price
*--------------------------------------------------*
oaxaca d_ghq_likert ///
    emp_red emp_loss key_yes selfemp_yes ///
    fin_base_yes fin_better fin_worse ///
    bedratio_base bedratio_sq hsrooms_base2 rooms_sq ///
    covid_symp cc_resp cc_cardio cc_endo cc_arth cc_other ///
    single_occ base_ndep kids_sq single_kids single_kids_sq ///
    female age16_29 age30_49 age50_69 ///
    [pw=wgt_ca], ///
    by(bip) pooled detail vce(cluster psu_ca)

collect_ox_detail `oxhold' 1 "Oaxaca: pooled price"


*--------------------------------------------------*
* Column 2: WM price / Non-bip price
* group 1 = bip==0 = WM
*--------------------------------------------------*
oaxaca d_ghq_likert ///
    emp_red emp_loss key_yes selfemp_yes ///
    fin_base_yes fin_better fin_worse ///
    bedratio_base bedratio_sq hsrooms_base2 rooms_sq ///
    covid_symp cc_resp cc_cardio cc_endo cc_arth cc_other ///
    single_occ base_ndep kids_sq single_kids single_kids_sq ///
    female age16_29 age30_49 age50_69 ///
    [pw=wgt_ca], ///
    by(bip) weight(1) detail vce(cluster psu_ca)

collect_ox_detail `oxhold' 2 "Oaxaca: WM price"


postclose `oxhold'

use `oxres', clear
sort panel row col

save "${out}/Appendix/BIP/appendix_oaxaca_bip.dta", replace
export delimited using "${out}/Appendix/BIP/appendix_oaxaca_bip.csv", replace
