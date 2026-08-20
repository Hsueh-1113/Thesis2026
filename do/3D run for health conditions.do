cap mkdir "${out}/Tables/health_tables"

**************************************************
* 0. Start
**************************************************
use "${work}/BASE_delta2019_CA_zinv_COVIDWGT.dta", clear

svyset psu_ca [pweight=wgt_ca], strata(strata_ca) singleunit(scaled)

**************************************************
* 1. COVID symptoms
**************************************************
count if !missing(d_ghq_likert, bame, covid_symp) & bame==1
local N_covid_b = r(N)

count if !missing(d_ghq_likert, bame, covid_symp) & bame==0
local N_covid_nb = r(N)

svy, subpop(if bame==1 & !missing(covid_symp)): regress d_ghq_likert i.covid_symp
margins covid_symp, saving("${out}/Tables/health_tables/marg_covid_symp_bame_cells.dta", replace)

svy, subpop(if bame==0 & !missing(covid_symp)): regress d_ghq_likert i.covid_symp
margins covid_symp, saving("${out}/Tables/health_tables/marg_covid_symp_nonbame_cells.dta", replace)

svy, subpop(if !missing(covid_symp)): regress d_ghq_likert i.bame##i.covid_symp
margins covid_symp, dydx(bame) saving("${out}/Tables/health_tables/marg_covid_symp_dydx.dta", replace)

**************************************************
* 2. Respiratory chronic condition
**************************************************
count if !missing(d_ghq_likert, bame, cc_resp) & bame==1
local N_resp_b = r(N)

count if !missing(d_ghq_likert, bame, cc_resp) & bame==0
local N_resp_nb = r(N)

svy, subpop(if bame==1 & !missing(cc_resp)): regress d_ghq_likert i.cc_resp
margins cc_resp, saving("${out}/Tables/health_tables/marg_cc_resp_bame_cells.dta", replace)

svy, subpop(if bame==0 & !missing(cc_resp)): regress d_ghq_likert i.cc_resp
margins cc_resp, saving("${out}/Tables/health_tables/marg_cc_resp_nonbame_cells.dta", replace)

svy, subpop(if !missing(cc_resp)): regress d_ghq_likert i.bame##i.cc_resp
margins cc_resp, dydx(bame) saving("${out}/Tables/health_tables/marg_cc_resp_dydx.dta", replace)

**************************************************
* 3. Cardiovascular chronic condition
**************************************************
count if !missing(d_ghq_likert, bame, cc_cardio) & bame==1
local N_cardio_b = r(N)

count if !missing(d_ghq_likert, bame, cc_cardio) & bame==0
local N_cardio_nb = r(N)

svy, subpop(if bame==1 & !missing(cc_cardio)): regress d_ghq_likert i.cc_cardio
margins cc_cardio, saving("${out}/Tables/health_tables/marg_cc_cardio_bame_cells.dta", replace)

svy, subpop(if bame==0 & !missing(cc_cardio)): regress d_ghq_likert i.cc_cardio
margins cc_cardio, saving("${out}/Tables/health_tables/marg_cc_cardio_nonbame_cells.dta", replace)

svy, subpop(if !missing(cc_cardio)): regress d_ghq_likert i.bame##i.cc_cardio
margins cc_cardio, dydx(bame) saving("${out}/Tables/health_tables/marg_cc_cardio_dydx.dta", replace)

**************************************************
* 4. Endocrine chronic condition
**************************************************
count if !missing(d_ghq_likert, bame, cc_endo) & bame==1
local N_endo_b = r(N)

count if !missing(d_ghq_likert, bame, cc_endo) & bame==0
local N_endo_nb = r(N)

svy, subpop(if bame==1 & !missing(cc_endo)): regress d_ghq_likert i.cc_endo
margins cc_endo, saving("${out}/Tables/health_tables/marg_cc_endo_bame_cells.dta", replace)

svy, subpop(if bame==0 & !missing(cc_endo)): regress d_ghq_likert i.cc_endo
margins cc_endo, saving("${out}/Tables/health_tables/marg_cc_endo_nonbame_cells.dta", replace)

svy, subpop(if !missing(cc_endo)): regress d_ghq_likert i.bame##i.cc_endo
margins cc_endo, dydx(bame) saving("${out}/Tables/health_tables/marg_cc_endo_dydx.dta", replace)

**************************************************
* 5. Arthritis
**************************************************
count if !missing(d_ghq_likert, bame, cc_arth) & bame==1
local N_arth_b = r(N)

count if !missing(d_ghq_likert, bame, cc_arth) & bame==0
local N_arth_nb = r(N)

svy, subpop(if bame==1 & !missing(cc_arth)): regress d_ghq_likert i.cc_arth
margins cc_arth, saving("${out}/Tables/health_tables/marg_cc_arth_bame_cells.dta", replace)

svy, subpop(if bame==0 & !missing(cc_arth)): regress d_ghq_likert i.cc_arth
margins cc_arth, saving("${out}/Tables/health_tables/marg_cc_arth_nonbame_cells.dta", replace)

svy, subpop(if !missing(cc_arth)): regress d_ghq_likert i.bame##i.cc_arth
margins cc_arth, dydx(bame) saving("${out}/Tables/health_tables/marg_cc_arth_dydx.dta", replace)

**************************************************
* 6. Other chronic condition
**************************************************
count if !missing(d_ghq_likert, bame, cc_other) & bame==1
local N_other_b = r(N)

count if !missing(d_ghq_likert, bame, cc_other) & bame==0
local N_other_nb = r(N)

svy, subpop(if bame==1 & !missing(cc_other)): regress d_ghq_likert i.cc_other
margins cc_other, saving("${out}/Tables/health_tables/marg_cc_other_bame_cells.dta", replace)

svy, subpop(if bame==0 & !missing(cc_other)): regress d_ghq_likert i.cc_other
margins cc_other, saving("${out}/Tables/health_tables/marg_cc_other_nonbame_cells.dta", replace)

svy, subpop(if !missing(cc_other)): regress d_ghq_likert i.bame##i.cc_other
margins cc_other, dydx(bame) saving("${out}/Tables/health_tables/marg_cc_other_dydx.dta", replace)

**************************************************
* 7. Tools
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
* 8. Table 4A cells / dydx
**************************************************

* covid_symp: 0=No, 1=Yes
use "${out}/Tables/health_tables/marg_covid_symp_bame_cells.dta", clear
gen ord = _n
qui su _margin if ord==1, meanonly
local covid_b_b0 = r(mean)
qui su _se if ord==1, meanonly
local covid_b_se0 = r(mean)
qui su _margin if ord==2, meanonly
local covid_b_b1 = r(mean)
qui su _se if ord==2, meanonly
local covid_b_se1 = r(mean)

use "${out}/Tables/health_tables/marg_covid_symp_nonbame_cells.dta", clear
gen ord = _n
qui su _margin if ord==1, meanonly
local covid_nb_b0 = r(mean)
qui su _se if ord==1, meanonly
local covid_nb_se0 = r(mean)
qui su _margin if ord==2, meanonly
local covid_nb_b1 = r(mean)
qui su _se if ord==2, meanonly
local covid_nb_se1 = r(mean)

use "${out}/Tables/health_tables/marg_covid_symp_dydx.dta", clear
gen ord = _n
qui su _margin if ord==1, meanonly
local covid_diff_b0 = r(mean)
qui su _se if ord==1, meanonly
local covid_diff_se0 = r(mean)
qui su _margin if ord==2, meanonly
local covid_diff_b1 = r(mean)
qui su _se if ord==2, meanonly
local covid_diff_se1 = r(mean)

* cc_resp: 0=No, 1=Yes
use "${out}/Tables/health_tables/marg_cc_resp_bame_cells.dta", clear
gen ord = _n
qui su _margin if ord==1, meanonly
local resp_b_b0 = r(mean)
qui su _se if ord==1, meanonly
local resp_b_se0 = r(mean)
qui su _margin if ord==2, meanonly
local resp_b_b1 = r(mean)
qui su _se if ord==2, meanonly
local resp_b_se1 = r(mean)

use "${out}/Tables/health_tables/marg_cc_resp_nonbame_cells.dta", clear
gen ord = _n
qui su _margin if ord==1, meanonly
local resp_nb_b0 = r(mean)
qui su _se if ord==1, meanonly
local resp_nb_se0 = r(mean)
qui su _margin if ord==2, meanonly
local resp_nb_b1 = r(mean)
qui su _se if ord==2, meanonly
local resp_nb_se1 = r(mean)

use "${out}/Tables/health_tables/marg_cc_resp_dydx.dta", clear
gen ord = _n
qui su _margin if ord==1, meanonly
local resp_diff_b0 = r(mean)
qui su _se if ord==1, meanonly
local resp_diff_se0 = r(mean)
qui su _margin if ord==2, meanonly
local resp_diff_b1 = r(mean)
qui su _se if ord==2, meanonly
local resp_diff_se1 = r(mean)

* cc_cardio: 0=No, 1=Yes
use "${out}/Tables/health_tables/marg_cc_cardio_bame_cells.dta", clear
gen ord = _n
qui su _margin if ord==1, meanonly
local cardio_b_b0 = r(mean)
qui su _se if ord==1, meanonly
local cardio_b_se0 = r(mean)
qui su _margin if ord==2, meanonly
local cardio_b_b1 = r(mean)
qui su _se if ord==2, meanonly
local cardio_b_se1 = r(mean)

use "${out}/Tables/health_tables/marg_cc_cardio_nonbame_cells.dta", clear
gen ord = _n
qui su _margin if ord==1, meanonly
local cardio_nb_b0 = r(mean)
qui su _se if ord==1, meanonly
local cardio_nb_se0 = r(mean)
qui su _margin if ord==2, meanonly
local cardio_nb_b1 = r(mean)
qui su _se if ord==2, meanonly
local cardio_nb_se1 = r(mean)

use "${out}/Tables/health_tables/marg_cc_cardio_dydx.dta", clear
gen ord = _n
qui su _margin if ord==1, meanonly
local cardio_diff_b0 = r(mean)
qui su _se if ord==1, meanonly
local cardio_diff_se0 = r(mean)
qui su _margin if ord==2, meanonly
local cardio_diff_b1 = r(mean)
qui su _se if ord==2, meanonly
local cardio_diff_se1 = r(mean)

**************************************************
* 9. to str
**************************************************

* covid
forvalues i = 0/1 {
    quietly fmt_coef `covid_b_b`i'' `covid_b_se`i''
    local covid_b_txt`i' `"`r(out)'"'
    quietly fmt_se `covid_b_se`i''
    local covid_b_se_txt`i' `"`r(out)'"'

    quietly fmt_coef `covid_nb_b`i'' `covid_nb_se`i''
    local covid_nb_txt`i' `"`r(out)'"'
    quietly fmt_se `covid_nb_se`i''
    local covid_nb_se_txt`i' `"`r(out)'"'

    quietly fmt_p `covid_diff_b`i'' `covid_diff_se`i''
    local covid_diff_txt`i' `"`r(out)'"'
}

* resp
forvalues i = 0/1 {
    quietly fmt_coef `resp_b_b`i'' `resp_b_se`i''
    local resp_b_txt`i' `"`r(out)'"'
    quietly fmt_se `resp_b_se`i''
    local resp_b_se_txt`i' `"`r(out)'"'

    quietly fmt_coef `resp_nb_b`i'' `resp_nb_se`i''
    local resp_nb_txt`i' `"`r(out)'"'
    quietly fmt_se `resp_nb_se`i''
    local resp_nb_se_txt`i' `"`r(out)'"'

    quietly fmt_p `resp_diff_b`i'' `resp_diff_se`i''
    local resp_diff_txt`i' `"`r(out)'"'
}

* cardio
forvalues i = 0/1 {
    quietly fmt_coef `cardio_b_b`i'' `cardio_b_se`i''
    local cardio_b_txt`i' `"`r(out)'"'
    quietly fmt_se `cardio_b_se`i''
    local cardio_b_se_txt`i' `"`r(out)'"'

    quietly fmt_coef `cardio_nb_b`i'' `cardio_nb_se`i''
    local cardio_nb_txt`i' `"`r(out)'"'
    quietly fmt_se `cardio_nb_se`i''
    local cardio_nb_se_txt`i' `"`r(out)'"'

    quietly fmt_p `cardio_diff_b`i'' `cardio_diff_se`i''
    local cardio_diff_txt`i' `"`r(out)'"'
}

**************************************************
* 10. Excel：Table 4A
**************************************************
putexcel set "${out}/Tables/health_tables/Table_BAME_health_A.xlsx", replace

putexcel A1 = "Table 4A"
putexcel A2 = "Well-being by ethnicity: health conditions (I)"

putexcel D4 = "Bame"
putexcel E4 = "Bame"
putexcel F4 = "Bame"
putexcel G4 = "Non-Bame"
putexcel H4 = "Non-Bame"
putexcel I4 = "Non-Bame"
putexcel J4 = "Difference"
putexcel J5 = "p-value"

* COVID symptoms
putexcel A7 = "COVID symptoms"
putexcel A8 = "No"
putexcel D8 = "`covid_b_txt0'"
putexcel G8 = "`covid_nb_txt0'"
putexcel J8 = "`covid_diff_txt0'"
putexcel D9 = "`covid_b_se_txt0'"
putexcel G9 = "`covid_nb_se_txt0'"

putexcel A10 = "Yes"
putexcel D10 = "`covid_b_txt1'"
putexcel G10 = "`covid_nb_txt1'"
putexcel J10 = "`covid_diff_txt1'"
putexcel D11 = "`covid_b_se_txt1'"
putexcel G11 = "`covid_nb_se_txt1'"

* Respiratory
putexcel A13 = "Respiratory chronic condition"
putexcel A14 = "No"
putexcel E14 = "`resp_b_txt0'"
putexcel H14 = "`resp_nb_txt0'"
putexcel J14 = "`resp_diff_txt0'"
putexcel E15 = "`resp_b_se_txt0'"
putexcel H15 = "`resp_nb_se_txt0'"

putexcel A16 = "Yes"
putexcel E16 = "`resp_b_txt1'"
putexcel H16 = "`resp_nb_txt1'"
putexcel J16 = "`resp_diff_txt1'"
putexcel E17 = "`resp_b_se_txt1'"
putexcel H17 = "`resp_nb_se_txt1'"

* Cardiovascular
putexcel A19 = "Cardiovascular chronic condition"
putexcel A20 = "No"
putexcel F20 = "`cardio_b_txt0'"
putexcel I20 = "`cardio_nb_txt0'"
putexcel J20 = "`cardio_diff_txt0'"
putexcel F21 = "`cardio_b_se_txt0'"
putexcel I21 = "`cardio_nb_se_txt0'"

putexcel A22 = "Yes"
putexcel F22 = "`cardio_b_txt1'"
putexcel I22 = "`cardio_nb_txt1'"
putexcel J22 = "`cardio_diff_txt1'"
putexcel F23 = "`cardio_b_se_txt1'"
putexcel I23 = "`cardio_nb_se_txt1'"

* Observations
putexcel A25 = "Observations"
putexcel D25 = `N_covid_b'
putexcel E25 = `N_resp_b'
putexcel F25 = `N_cardio_b'
putexcel G25 = `N_covid_nb'
putexcel H25 = `N_resp_nb'
putexcel I25 = `N_cardio_nb'

putexcel A27 = "Notes: Entries are margins from separate Bame-only and Non-Bame-only survey regressions. Standard errors are in parentheses. Difference reports p-values from pooled models testing Bame vs Non-Bame within each row."
putexcel A28 = "* p<0.10, ** p<0.05, *** p<0.01."

**************************************************
* 11. Table 4B 
**************************************************

* cc_endo
use "${out}/Tables/health_tables/marg_cc_endo_bame_cells.dta", clear
gen ord = _n
qui su _margin if ord==1, meanonly
local endo_b_b0 = r(mean)
qui su _se if ord==1, meanonly
local endo_b_se0 = r(mean)
qui su _margin if ord==2, meanonly
local endo_b_b1 = r(mean)
qui su _se if ord==2, meanonly
local endo_b_se1 = r(mean)

use "${out}/Tables/health_tables/marg_cc_endo_nonbame_cells.dta", clear
gen ord = _n
qui su _margin if ord==1, meanonly
local endo_nb_b0 = r(mean)
qui su _se if ord==1, meanonly
local endo_nb_se0 = r(mean)
qui su _margin if ord==2, meanonly
local endo_nb_b1 = r(mean)
qui su _se if ord==2, meanonly
local endo_nb_se1 = r(mean)

use "${out}/Tables/health_tables/marg_cc_endo_dydx.dta", clear
gen ord = _n
qui su _margin if ord==1, meanonly
local endo_diff_b0 = r(mean)
qui su _se if ord==1, meanonly
local endo_diff_se0 = r(mean)
qui su _margin if ord==2, meanonly
local endo_diff_b1 = r(mean)
qui su _se if ord==2, meanonly
local endo_diff_se1 = r(mean)

* cc_arth
use "${out}/Tables/health_tables/marg_cc_arth_bame_cells.dta", clear
gen ord = _n
qui su _margin if ord==1, meanonly
local arth_b_b0 = r(mean)
qui su _se if ord==1, meanonly
local arth_b_se0 = r(mean)
qui su _margin if ord==2, meanonly
local arth_b_b1 = r(mean)
qui su _se if ord==2, meanonly
local arth_b_se1 = r(mean)

use "${out}/Tables/health_tables/marg_cc_arth_nonbame_cells.dta", clear
gen ord = _n
qui su _margin if ord==1, meanonly
local arth_nb_b0 = r(mean)
qui su _se if ord==1, meanonly
local arth_nb_se0 = r(mean)
qui su _margin if ord==2, meanonly
local arth_nb_b1 = r(mean)
qui su _se if ord==2, meanonly
local arth_nb_se1 = r(mean)

use "${out}/Tables/health_tables/marg_cc_arth_dydx.dta", clear
gen ord = _n
qui su _margin if ord==1, meanonly
local arth_diff_b0 = r(mean)
qui su _se if ord==1, meanonly
local arth_diff_se0 = r(mean)
qui su _margin if ord==2, meanonly
local arth_diff_b1 = r(mean)
qui su _se if ord==2, meanonly
local arth_diff_se1 = r(mean)

* cc_other
use "${out}/Tables/health_tables/marg_cc_other_bame_cells.dta", clear
gen ord = _n
qui su _margin if ord==1, meanonly
local other_b_b0 = r(mean)
qui su _se if ord==1, meanonly
local other_b_se0 = r(mean)
qui su _margin if ord==2, meanonly
local other_b_b1 = r(mean)
qui su _se if ord==2, meanonly
local other_b_se1 = r(mean)

use "${out}/Tables/health_tables/marg_cc_other_nonbame_cells.dta", clear
gen ord = _n
qui su _margin if ord==1, meanonly
local other_nb_b0 = r(mean)
qui su _se if ord==1, meanonly
local other_nb_se0 = r(mean)
qui su _margin if ord==2, meanonly
local other_nb_b1 = r(mean)
qui su _se if ord==2, meanonly
local other_nb_se1 = r(mean)

use "${out}/Tables/health_tables/marg_cc_other_dydx.dta", clear
gen ord = _n
qui su _margin if ord==1, meanonly
local other_diff_b0 = r(mean)
qui su _se if ord==1, meanonly
local other_diff_se0 = r(mean)
qui su _margin if ord==2, meanonly
local other_diff_b1 = r(mean)
qui su _se if ord==2, meanonly
local other_diff_se1 = r(mean)

**************************************************
* 12. str
**************************************************
foreach x in endo arth other {
    forvalues i = 0/1 {
        quietly fmt_coef ``x'_b_b`i'' ``x'_b_se`i''
        local `x'_b_txt`i' `"`r(out)'"'
        quietly fmt_se ``x'_b_se`i''
        local `x'_b_se_txt`i' `"`r(out)'"'

        quietly fmt_coef ``x'_nb_b`i'' ``x'_nb_se`i''
        local `x'_nb_txt`i' `"`r(out)'"'
        quietly fmt_se ``x'_nb_se`i''
        local `x'_nb_se_txt`i' `"`r(out)'"'

        quietly fmt_p ``x'_diff_b`i'' ``x'_diff_se`i''
        local `x'_diff_txt`i' `"`r(out)'"'
    }
}

**************************************************
* 13. Excel：Table 4B
**************************************************
putexcel set "${out}/Tables/health_tables/Table_BAME_health_B.xlsx", replace

putexcel A1 = "Table 4B"
putexcel A2 = "Well-being by ethnicity: health conditions (II)"

putexcel D4 = "Bame"
putexcel E4 = "Bame"
putexcel F4 = "Bame"
putexcel G4 = "Non-Bame"
putexcel H4 = "Non-Bame"
putexcel I4 = "Non-Bame"
putexcel J4 = "Difference"
putexcel J5 = "p-value"

* Endocrine
putexcel A7 = "Endocrine chronic condition"
putexcel A8 = "No"
putexcel D8 = "`endo_b_txt0'"
putexcel G8 = "`endo_nb_txt0'"
putexcel J8 = "`endo_diff_txt0'"
putexcel D9 = "`endo_b_se_txt0'"
putexcel G9 = "`endo_nb_se_txt0'"

putexcel A10 = "Yes"
putexcel D10 = "`endo_b_txt1'"
putexcel G10 = "`endo_nb_txt1'"
putexcel J10 = "`endo_diff_txt1'"
putexcel D11 = "`endo_b_se_txt1'"
putexcel G11 = "`endo_nb_se_txt1'"

* Arthritis
putexcel A13 = "Arthritis"
putexcel A14 = "No"
putexcel E14 = "`arth_b_txt0'"
putexcel H14 = "`arth_nb_txt0'"
putexcel J14 = "`arth_diff_txt0'"
putexcel E15 = "`arth_b_se_txt0'"
putexcel H15 = "`arth_nb_se_txt0'"

putexcel A16 = "Yes"
putexcel E16 = "`arth_b_txt1'"
putexcel H16 = "`arth_nb_txt1'"
putexcel J16 = "`arth_diff_txt1'"
putexcel E17 = "`arth_b_se_txt1'"
putexcel H17 = "`arth_nb_se_txt1'"

* Other
putexcel A19 = "Other chronic condition"
putexcel A20 = "No"
putexcel F20 = "`other_b_txt0'"
putexcel I20 = "`other_nb_txt0'"
putexcel J20 = "`other_diff_txt0'"
putexcel F21 = "`other_b_se_txt0'"
putexcel I21 = "`other_nb_se_txt0'"

putexcel A22 = "Yes"
putexcel F22 = "`other_b_txt1'"
putexcel I22 = "`other_nb_txt1'"
putexcel J22 = "`other_diff_txt1'"
putexcel F23 = "`other_b_se_txt1'"
putexcel I23 = "`other_nb_se_txt1'"

* Observations
putexcel A25 = "Observations"
putexcel D25 = `N_endo_b'
putexcel E25 = `N_arth_b'
putexcel F25 = `N_other_b'
putexcel G25 = `N_endo_nb'
putexcel H25 = `N_arth_nb'
putexcel I25 = `N_other_nb'

putexcel A27 = "Notes: Entries are margins from separate Bame-only and Non-Bame-only survey regressions. Standard errors are in parentheses. Difference reports p-values from pooled models testing Bame vs Non-Bame within each row."
putexcel A28 = "* p<0.10, ** p<0.05, *** p<0.01."
