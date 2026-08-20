cap mkdir "${out}/Tables/employment_tables"

**************************************************
* 0. 
**************************************************
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


* svyset psu_covid [pweight=wgt_covid], strata(strata_covid) singleunit(scaled)
svyset psu_ca [pweight=wgt_ca], strata(strata_ca) singleunit(scaled)

**************************************************
* 1. Employment change
**************************************************
count if !missing(d_ghq_likert, bame, emp_change) & bame==1
local N_emp_b = r(N)

count if !missing(d_ghq_likert, bame, emp_change) & bame==0
local N_emp_nb = r(N)

* BAME only
svy, subpop(if bame==1 & !missing(emp_change)): regress d_ghq_likert i.emp_change
margins emp_change, saving("${out}/Tables/employment_tables/marg_emp_change_bame_cells.dta", replace)

* Non-BAME only
svy, subpop(if bame==0 & !missing(emp_change)): regress d_ghq_likert i.emp_change
margins emp_change, saving("${out}/Tables/employment_tables/marg_emp_change_nonbame_cells.dta", replace)

* pooled difference p-value
svy, subpop(if !missing(emp_change)): regress d_ghq_likert i.bame##i.emp_change
margins emp_change, dydx(bame) ///
    saving("${out}/Tables/employment_tables/marg_emp_change_dydx.dta", replace)

**************************************************
* 2. Key worker
**************************************************
count if !missing(d_ghq_likert, bame, keyworker) & bame==1
local N_key_b = r(N)

count if !missing(d_ghq_likert, bame, keyworker) & bame==0
local N_key_nb = r(N)

* BAME only
svy, subpop(if bame==1 & !missing(keyworker)): regress d_ghq_likert i.keyworker
margins keyworker, saving("${out}/Tables/employment_tables/marg_keyworker_bame_cells.dta", replace)

* Non-BAME only
svy, subpop(if bame==0 & !missing(keyworker)): regress d_ghq_likert i.keyworker
margins keyworker, saving("${out}/Tables/employment_tables/marg_keyworker_nonbame_cells.dta", replace)

* pooled difference p-value
svy, subpop(if !missing(keyworker)): regress d_ghq_likert i.bame##i.keyworker
margins keyworker, dydx(bame) ///
    saving("${out}/Tables/employment_tables/marg_keyworker_dydx.dta", replace)

**************************************************
* 3. Self-employed
**************************************************
count if !missing(d_ghq_likert, bame, selfemp_only) & bame==1
local N_self_b = r(N)

count if !missing(d_ghq_likert, bame, selfemp_only) & bame==0
local N_self_nb = r(N)

* BAME only
svy, subpop(if bame==1 & !missing(selfemp_only)): regress d_ghq_likert i.selfemp_only
margins selfemp_only, saving("${out}/Tables/employment_tables/marg_selfemp_bame_cells.dta", replace)

* Non-BAME only
svy, subpop(if bame==0 & !missing(selfemp_only)): regress d_ghq_likert i.selfemp_only
margins selfemp_only, saving("${out}/Tables/employment_tables/marg_selfemp_nonbame_cells.dta", replace)

* pooled difference p-value
svy, subpop(if !missing(selfemp_only)): regress d_ghq_likert i.bame##i.selfemp_only
margins selfemp_only, dydx(bame) ///
    saving("${out}/Tables/employment_tables/marg_selfemp_dydx.dta", replace)

**************************************************
* 4. tools
**************************************************
capture program drop fmt_coef
program define fmt_coef, rclass
    args b se
    local p = 2*normal(-abs(`b'/`se'))
    local stars ""
    if `p' < 0.10 local stars "*"
    if `p' < 0.05 local stars "**"
    if `p' < 0.01 local stars "***"
    local txt : display %6.2f `b'
    local txt : subinstr local txt " " "", all
    return local out "`txt'`stars'"
end

capture program drop fmt_se
program define fmt_se, rclass
    args se
    local txt : display %6.2f `se'
    local txt : subinstr local txt " " "", all
    return local out "(`txt')"
end

capture program drop fmt_p
program define fmt_p, rclass
    args b se
    local p = 2*normal(-abs(`b'/`se'))
    local txt : display %4.2f `p'
    local txt : subinstr local txt " " "", all
    return local out "[`txt']"
end

**************************************************
* 5. employment status: BAME cells
**************************************************
use "${out}/Tables/employment_tables/marg_emp_change_bame_cells.dta", clear
gen ord = _n

forvalues i = 1/3 {
    quietly summarize _margin if ord==`i', meanonly
    local emp_b_b`i' = r(mean)
    quietly summarize _se if ord==`i', meanonly
    local emp_b_se`i' = r(mean)
}

**************************************************
* 6. employment status: Non-BAME cells
**************************************************
use "${out}/Tables/employment_tables/marg_emp_change_nonbame_cells.dta", clear
gen ord = _n

forvalues i = 1/3 {
    quietly summarize _margin if ord==`i', meanonly
    local emp_nb_b`i' = r(mean)
    quietly summarize _se if ord==`i', meanonly
    local emp_nb_se`i' = r(mean)
}

**************************************************
* 7. employment status: difference
**************************************************
use "${out}/Tables/employment_tables/marg_emp_change_dydx.dta", clear
gen ord = _n

forvalues i = 1/3 {
    quietly summarize _margin if ord==`i', meanonly
    local emp_diff_b`i' = r(mean)
    quietly summarize _se if ord==`i', meanonly
    local emp_diff_se`i' = r(mean)
}

**************************************************
* 8. key worker: BAME cells
**************************************************
use "${out}/Tables/employment_tables/marg_keyworker_bame_cells.dta", clear
gen ord = _n

quietly summarize _margin if ord==1, meanonly
local key_b_b0 = r(mean)
quietly summarize _se if ord==1, meanonly
local key_b_se0 = r(mean)

quietly summarize _margin if ord==2, meanonly
local key_b_b1 = r(mean)
quietly summarize _se if ord==2, meanonly
local key_b_se1 = r(mean)

**************************************************
* 9. key worker: Non-BAME cells
**************************************************
use "${out}/Tables/employment_tables/marg_keyworker_nonbame_cells.dta", clear
gen ord = _n

quietly summarize _margin if ord==1, meanonly
local key_nb_b0 = r(mean)
quietly summarize _se if ord==1, meanonly
local key_nb_se0 = r(mean)

quietly summarize _margin if ord==2, meanonly
local key_nb_b1 = r(mean)
quietly summarize _se if ord==2, meanonly
local key_nb_se1 = r(mean)

**************************************************
* 10. key worker: difference
**************************************************
use "${out}/Tables/employment_tables/marg_keyworker_dydx.dta", clear
gen ord = _n

quietly summarize _margin if ord==1, meanonly
local key_diff_b0 = r(mean)
quietly summarize _se if ord==1, meanonly
local key_diff_se0 = r(mean)

quietly summarize _margin if ord==2, meanonly
local key_diff_b1 = r(mean)
quietly summarize _se if ord==2, meanonly
local key_diff_se1 = r(mean)

**************************************************
* 11. self-employed: BAME cells
**************************************************
use "${out}/Tables/employment_tables/marg_selfemp_bame_cells.dta", clear
gen ord = _n

quietly summarize _margin if ord==1, meanonly
local self_b_b0 = r(mean)
quietly summarize _se if ord==1, meanonly
local self_b_se0 = r(mean)

quietly summarize _margin if ord==2, meanonly
local self_b_b1 = r(mean)
quietly summarize _se if ord==2, meanonly
local self_b_se1 = r(mean)

**************************************************
* 12. self-employed: Non-BAME cells
**************************************************
use "${out}/Tables/employment_tables/marg_selfemp_nonbame_cells.dta", clear
gen ord = _n

quietly summarize _margin if ord==1, meanonly
local self_nb_b0 = r(mean)
quietly summarize _se if ord==1, meanonly
local self_nb_se0 = r(mean)

quietly summarize _margin if ord==2, meanonly
local self_nb_b1 = r(mean)
quietly summarize _se if ord==2, meanonly
local self_nb_se1 = r(mean)

**************************************************
* 13. self-employed: difference
**************************************************
use "${out}/Tables/employment_tables/marg_selfemp_dydx.dta", clear
gen ord = _n

quietly summarize _margin if ord==1, meanonly
local self_diff_b0 = r(mean)
quietly summarize _se if ord==1, meanonly
local self_diff_se0 = r(mean)

quietly summarize _margin if ord==2, meanonly
local self_diff_b1 = r(mean)
quietly summarize _se if ord==2, meanonly
local self_diff_se1 = r(mean)

**************************************************
* 14. 
**************************************************
forvalues i = 1/3 {
    quietly fmt_coef `emp_b_b`i'' `emp_b_se`i''
    local emp_b_txt`i' `"`r(out)'"'
    quietly fmt_se `emp_b_se`i''
    local emp_b_se_txt`i' `"`r(out)'"'

    quietly fmt_coef `emp_nb_b`i'' `emp_nb_se`i''
    local emp_nb_txt`i' `"`r(out)'"'
    quietly fmt_se `emp_nb_se`i''
    local emp_nb_se_txt`i' `"`r(out)'"'

    quietly fmt_p `emp_diff_b`i'' `emp_diff_se`i''
    local emp_diff_txt`i' `"`r(out)'"'
}

forvalues i = 0/1 {
    quietly fmt_coef `key_b_b`i'' `key_b_se`i''
    local key_b_txt`i' `"`r(out)'"'
    quietly fmt_se `key_b_se`i''
    local key_b_se_txt`i' `"`r(out)'"'

    quietly fmt_coef `key_nb_b`i'' `key_nb_se`i''
    local key_nb_txt`i' `"`r(out)'"'
    quietly fmt_se `key_nb_se`i''
    local key_nb_se_txt`i' `"`r(out)'"'

    quietly fmt_p `key_diff_b`i'' `key_diff_se`i''
    local key_diff_txt`i' `"`r(out)'"'
}

forvalues i = 0/1 {
    quietly fmt_coef `self_b_b`i'' `self_b_se`i''
    local self_b_txt`i' `"`r(out)'"'
    quietly fmt_se `self_b_se`i''
    local self_b_se_txt`i' `"`r(out)'"'

    quietly fmt_coef `self_nb_b`i'' `self_nb_se`i''
    local self_nb_txt`i' `"`r(out)'"'
    quietly fmt_se `self_nb_se`i''
    local self_nb_se_txt`i' `"`r(out)'"'

    quietly fmt_p `self_diff_b`i'' `self_diff_se`i''
    local self_diff_txt`i' `"`r(out)'"'
}

**************************************************
* 15. export to Excel
**************************************************
putexcel set "${out}/Tables/employment_tables/Table_BAME_custom.xlsx", replace

putexcel A1 = "Table 1"
putexcel A2 = "Well-being by ethnicity: employment status, key worker status, and self-employment"

putexcel D4 = "BAME"
putexcel E4 = "BAME"
putexcel F4 = "BAME"
putexcel G4 = "Non-BAME"
putexcel H4 = "Non-BAME"
putexcel I4 = "Non-BAME"
putexcel J4 = "Difference"
putexcel J5 = "p-value"

* Employment block
putexcel A7  = "Change in employment status"
putexcel A8  = "No change"
putexcel D8  = "`emp_b_txt1'"
putexcel G8  = "`emp_nb_txt1'"
putexcel J8  = "`emp_diff_txt1'"
putexcel D9  = "`emp_b_se_txt1'"
putexcel G9  = "`emp_nb_se_txt1'"

putexcel A10 = "Reduction"
putexcel D10 = "`emp_b_txt2'"
putexcel G10 = "`emp_nb_txt2'"
putexcel J10 = "`emp_diff_txt2'"
putexcel D11 = "`emp_b_se_txt2'"
putexcel G11 = "`emp_nb_se_txt2'"

putexcel A12 = "Job loss"
putexcel D12 = "`emp_b_txt3'"
putexcel G12 = "`emp_nb_txt3'"
putexcel J12 = "`emp_diff_txt3'"
putexcel D13 = "`emp_b_se_txt3'"
putexcel G13 = "`emp_nb_se_txt3'"

* Key worker block
putexcel A17 = "Key worker (yes among stable workers only)"
putexcel A18 = "Yes"
putexcel E18 = "`key_b_txt1'"
putexcel H18 = "`key_nb_txt1'"
putexcel J18 = "`key_diff_txt1'"
putexcel E19 = "`key_b_se_txt1'"
putexcel H19 = "`key_nb_se_txt1'"

putexcel A20 = "No"
putexcel E20 = "`key_b_txt0'"
putexcel H20 = "`key_nb_txt0'"
putexcel J20 = "`key_diff_txt0'"
putexcel E21 = "`key_b_se_txt0'"
putexcel H21 = "`key_nb_se_txt0'"

* Self-employed block
putexcel A23 = "Self-employed in the baseline"
putexcel A24 = "Yes"
putexcel F24 = "`self_b_txt1'"
putexcel I24 = "`self_nb_txt1'"
putexcel J24 = "`self_diff_txt1'"
putexcel F25 = "`self_b_se_txt1'"
putexcel I25 = "`self_nb_se_txt1'"

putexcel A26 = "No"
putexcel F26 = "`self_b_txt0'"
putexcel I26 = "`self_nb_txt0'"
putexcel J26 = "`self_diff_txt0'"
putexcel F27 = "`self_b_se_txt0'"
putexcel I27 = "`self_nb_se_txt0'"

* Observations
putexcel A29 = "Observations"
putexcel D29 = `N_emp_b'
putexcel E29 = `N_key_b'
putexcel F29 = `N_self_b'
putexcel G29 = `N_emp_nb'
putexcel H29 = `N_key_nb'
putexcel I29 = `N_self_nb'

* Notes
putexcel A31 = "Notes: Entries are margins from separate BAME-only and Non-BAME-only survey regressions. Standard errors are in parentheses. Difference reports p-values from pooled models testing BAME vs Non-BAME within each row."
putexcel A32 = "Employment status is coded as No change, Reduction, and Job loss. The No-change category includes respondents who were not working before the pandemic as well as respondents whose employment status did not change. Key worker = 1 only for respondents employed before the pandemic, with no employment change, who were identified as key workers; all others are coded as No. Self-employed = 1 only for respondents who were self-employed only before the pandemic; all others are coded as No."
putexcel A33 = "* p<0.10, ** p<0.05, *** p<0.01."
