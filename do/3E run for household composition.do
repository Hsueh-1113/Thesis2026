cap mkdir "${out}/Tables/hhcomp_tables"

**************************************************
* 0. Start
**************************************************
use "${work}/BASE_delta2019_CA_zinv_COVIDWGT.dta", clear

svyset psu_ca [pweight=wgt_ca], strata(strata_ca) singleunit(scaled)

**************************************************
* 1. Single vs multi-occupancy
**************************************************

count if !missing(d_ghq_likert, bame, single_occ) & bame==1
local N_occ_b = r(N)

count if !missing(d_ghq_likert, bame, single_occ) & bame==0
local N_occ_nb = r(N)

* BAME only
svy, subpop(if bame==1 & !missing(single_occ)): regress d_ghq_likert i.single_occ
margins single_occ, ///
    saving("${out}/Tables/hhcomp_tables/marg_single_occ_bame_cells.dta", replace)

* Non-BAME only
svy, subpop(if bame==0 & !missing(single_occ)): regress d_ghq_likert i.single_occ
margins single_occ, ///
    saving("${out}/Tables/hhcomp_tables/marg_single_occ_nonbame_cells.dta", replace)

* pooled difference p-value
svy, subpop(if !missing(single_occ)): regress d_ghq_likert i.bame##i.single_occ
margins single_occ, dydx(bame) ///
    saving("${out}/Tables/hhcomp_tables/marg_single_occ_dydx.dta", replace)

**************************************************
* 2. Dependent children category
**************************************************

count if !missing(d_ghq_likert, bame, kids_cat) & bame==1
local N_kids_b = r(N)

count if !missing(d_ghq_likert, bame, kids_cat) & bame==0
local N_kids_nb = r(N)

* BAME only
svy, subpop(if bame==1 & !missing(kids_cat)): regress d_ghq_likert i.kids_cat
margins kids_cat, ///
    saving("${out}/Tables/hhcomp_tables/marg_kids_cat_bame_cells.dta", replace)

* Non-BAME only
svy, subpop(if bame==0 & !missing(kids_cat)): regress d_ghq_likert i.kids_cat
margins kids_cat, ///
    saving("${out}/Tables/hhcomp_tables/marg_kids_cat_nonbame_cells.dta", replace)

* pooled difference p-value
svy, subpop(if !missing(kids_cat)): regress d_ghq_likert i.bame##i.kids_cat
margins kids_cat, dydx(bame) ///
    saving("${out}/Tables/hhcomp_tables/marg_kids_cat_dydx.dta", replace)
	
**************************************************
* 3. Tools
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
* 4. Single occupancy: BAME cells
**************************************************
use "${out}/Tables/hhcomp_tables/marg_single_occ_bame_cells.dta", clear
gen ord = _n

* 假設排序：1 = Multi-occupancy, 2 = Single
quietly summarize _margin if ord==1, meanonly
local occ_b_b0 = r(mean)
quietly summarize _se if ord==1, meanonly
local occ_b_se0 = r(mean)

quietly summarize _margin if ord==2, meanonly
local occ_b_b1 = r(mean)
quietly summarize _se if ord==2, meanonly
local occ_b_se1 = r(mean)

**************************************************
* 5. Single occupancy: Non-BAME cells
**************************************************
use "${out}/Tables/hhcomp_tables/marg_single_occ_nonbame_cells.dta", clear
gen ord = _n

quietly summarize _margin if ord==1, meanonly
local occ_nb_b0 = r(mean)
quietly summarize _se if ord==1, meanonly
local occ_nb_se0 = r(mean)

quietly summarize _margin if ord==2, meanonly
local occ_nb_b1 = r(mean)
quietly summarize _se if ord==2, meanonly
local occ_nb_se1 = r(mean)

**************************************************
* 6. Single occupancy: difference
**************************************************
use "${out}/Tables/hhcomp_tables/marg_single_occ_dydx.dta", clear
gen ord = _n

quietly summarize _margin if ord==1, meanonly
local occ_diff_b0 = r(mean)
quietly summarize _se if ord==1, meanonly
local occ_diff_se0 = r(mean)

quietly summarize _margin if ord==2, meanonly
local occ_diff_b1 = r(mean)
quietly summarize _se if ord==2, meanonly
local occ_diff_se1 = r(mean)

**************************************************
* 7. Kids category: BAME cells
**************************************************
use "${out}/Tables/hhcomp_tables/marg_kids_cat_bame_cells.dta", clear
gen ord = _n

* 1 = No kids, 2 = 1-2 dep kids, 3 = >=3 dep kids
forvalues i = 1/3 {
    quietly summarize _margin if ord==`i', meanonly
    local kids_b_b`i' = r(mean)
    quietly summarize _se if ord==`i', meanonly
    local kids_b_se`i' = r(mean)
}

**************************************************
* 8. Kids category: Non-BAME cells
**************************************************
use "${out}/Tables/hhcomp_tables/marg_kids_cat_nonbame_cells.dta", clear
gen ord = _n

forvalues i = 1/3 {
    quietly summarize _margin if ord==`i', meanonly
    local kids_nb_b`i' = r(mean)
    quietly summarize _se if ord==`i', meanonly
    local kids_nb_se`i' = r(mean)
}

**************************************************
* 9. Kids category: difference
**************************************************
use "${out}/Tables/hhcomp_tables/marg_kids_cat_dydx.dta", clear
gen ord = _n

forvalues i = 1/3 {
    quietly summarize _margin if ord==`i', meanonly
    local kids_diff_b`i' = r(mean)
    quietly summarize _se if ord==`i', meanonly
    local kids_diff_se`i' = r(mean)
}

**************************************************
* 10. str
**************************************************

* single occupancy: 0=Multi-occupancy, 1=Single
forvalues i = 0/1 {
    quietly fmt_coef `occ_b_b`i'' `occ_b_se`i''
    local occ_b_txt`i' `"`r(out)'"'
    quietly fmt_se `occ_b_se`i''
    local occ_b_se_txt`i' `"`r(out)'"'

    quietly fmt_coef `occ_nb_b`i'' `occ_nb_se`i''
    local occ_nb_txt`i' `"`r(out)'"'
    quietly fmt_se `occ_nb_se`i''
    local occ_nb_se_txt`i' `"`r(out)'"'

    quietly fmt_p `occ_diff_b`i'' `occ_diff_se`i''
    local occ_diff_txt`i' `"`r(out)'"'
}

* kids category: 1/2/3
forvalues i = 1/3 {
    quietly fmt_coef `kids_b_b`i'' `kids_b_se`i''
    local kids_b_txt`i' `"`r(out)'"'
    quietly fmt_se `kids_b_se`i''
    local kids_b_se_txt`i' `"`r(out)'"'

    quietly fmt_coef `kids_nb_b`i'' `kids_nb_se`i''
    local kids_nb_txt`i' `"`r(out)'"'
    quietly fmt_se `kids_nb_se`i''
    local kids_nb_se_txt`i' `"`r(out)'"'

    quietly fmt_p `kids_diff_b`i'' `kids_diff_se`i''
    local kids_diff_txt`i' `"`r(out)'"'
}

**************************************************
* 11. Excel
**************************************************
putexcel set "${out}/hhcomp_tables/Table_BAME_hhcomp.xlsx", replace

putexcel A1 = "Table 5"
putexcel A2 = "Well-being by ethnicity: household composition"

* header
putexcel D4 = "Bame"
putexcel E4 = "Bame"
putexcel F4 = "Non-Bame"
putexcel G4 = "Non-Bame"
putexcel H4 = "Difference"
putexcel H5 = "p-value"

* ---------------- Single occupancy block ----------------
putexcel A7  = "Household occupancy at baseline"
putexcel A8  = "Multi-occupancy"
putexcel D8  = "`occ_b_txt0'"
putexcel F8  = "`occ_nb_txt0'"
putexcel H8  = "`occ_diff_txt0'"
putexcel D9  = "`occ_b_se_txt0'"
putexcel F9  = "`occ_nb_se_txt0'"

putexcel A10 = "Single"
putexcel D10 = "`occ_b_txt1'"
putexcel F10 = "`occ_nb_txt1'"
putexcel H10 = "`occ_diff_txt1'"
putexcel D11 = "`occ_b_se_txt1'"
putexcel F11 = "`occ_nb_se_txt1'"

* ---------------- Children block ----------------
putexcel A13 = "Dependent children at baseline"
putexcel A14 = "No kids"
putexcel E14 = "`kids_b_txt1'"
putexcel G14 = "`kids_nb_txt1'"
putexcel H14 = "`kids_diff_txt1'"
putexcel E15 = "`kids_b_se_txt1'"
putexcel G15 = "`kids_nb_se_txt1'"

putexcel A16 = "1-2 dep kids"
putexcel E16 = "`kids_b_txt2'"
putexcel G16 = "`kids_nb_txt2'"
putexcel H16 = "`kids_diff_txt2'"
putexcel E17 = "`kids_b_se_txt2'"
putexcel G17 = "`kids_nb_se_txt2'"

putexcel A18 = ">=3 dep kids"
putexcel E18 = "`kids_b_txt3'"
putexcel G18 = "`kids_nb_txt3'"
putexcel H18 = "`kids_diff_txt3'"
putexcel E19 = "`kids_b_se_txt3'"
putexcel G19 = "`kids_nb_se_txt3'"

* ---------------- Observations ----------------
putexcel A21 = "Observations"
putexcel D21 = `N_occ_b'
putexcel E21 = `N_kids_b'
putexcel F21 = `N_occ_nb'
putexcel G21 = `N_kids_nb'

* notes
putexcel A23 = "Notes: Entries are margins from separate Bame-only and Non-Bame-only survey regressions. Standard errors are in parentheses. Difference reports p-values from pooled models testing Bame vs Non-Bame within each row."
putexcel A24 = "* p<0.10, ** p<0.05, *** p<0.01."
