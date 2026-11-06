use "${work}/GHQ_longpanel_UKHLS_w1w11_plus_COVID_2020_2021_withIDs_apr_zinv.dta", clear

*----------------------------------------
* keep usable sample (ethnicity + valid design vars/weight)
*----------------------------------------
keep if !missing(ethn_dv)

*----------------------------------------
* build BAME indicator (your definition)
*----------------------------------------
capture confirm numeric variable ethn_dv
if _rc==0 {
    decode ethn_dv, gen(ethn_str)
}
else {
    gen strL ethn_str = ethn_dv
}

gen strL ethn_low = lower(strtrim(ethn_str))

gen byte bame = .
replace bame = 0 if strpos(ethn_low, "british/english/scottish/welsh/northern") > 0
replace bame = 1 if !missing(ethn_dv) & bame != 0

drop if missing(bame)


*----------------------------------------
* survey design
*----------------------------------------
svyset psu_dv [pweight=wgt], strata(strata_dv) singleunit(scaled)

*----------------------------------------
* weighted mean GHQ by time x BAME (with SE) + unweighted N
*----------------------------------------
capture postclose H
tempfile results

* detect whether time_label is string
capture confirm string variable time_label
local time_is_string = (_rc==0)

if `time_is_string' {
    postfile H str40 time_label byte bame ///
        double mean_likert se_likert mean_case se_case ///
        long n_likert n_case using `results', replace
}
else {
    postfile H double time_label byte bame ///
        double mean_likert se_likert mean_case se_case ///
        long n_likert n_case using `results', replace
}

levelsof time_label, local(tlevels)
levelsof bame, local(blevels)

foreach t of local tlevels {
    foreach b of local blevels {

        * unweighted counts (non-missing y)
        if `time_is_string' {
            quietly count if time_label=="`t'" & bame==`b' & !missing(ghq_likert_apr_zinv)
            local nlik = r(N)
            quietly count if time_label=="`t'" & bame==`b' & !missing(ghq_case_apr_zinv)
            local ncas = r(N)

            if (`nlik'==0 & `ncas'==0) continue

            quietly svy, subpop(if time_label=="`t'" & bame==`b'): ///
                mean ghq_likert_apr_zinv ghq_case_apr_zinv
        }
        else {
            quietly count if time_label==`t' & bame==`b' & !missing(ghq_likert_apr_zinv)
            local nlik = r(N)
            quietly count if time_label==`t' & bame==`b' & !missing(ghq_case_apr_zinv)
            local ncas = r(N)

            if (`nlik'==0 & `ncas'==0) continue

            quietly svy, subpop(if time_label==`t' & bame==`b'): ///
                mean ghq_likert_apr_zinv ghq_case_apr_zinv
        }

        matrix bvec = e(b)
        matrix V = e(V)

        local mlik = bvec[1,1]
        local mcas = bvec[1,2]
        local slik = sqrt(V[1,1])
        local scas = sqrt(V[2,2])

        if `time_is_string' {
            post H ("`t'") (`b') (`mlik') (`slik') (`mcas') (`scas') (`nlik') (`ncas')
        }
        else {
            post H (`t') (`b') (`mlik') (`slik') (`mcas') (`scas') (`nlik') (`ncas')
        }
    }
}

postclose H

use `results', clear
label define bame_lbl 0 "Non-BAME" 1 "BAME", replace
label values bame bame_lbl
save "${out}/Figure 1/GHQaverage_BAME_NonBAME.dta", replace
