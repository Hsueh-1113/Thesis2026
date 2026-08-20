cap mkdir "${out}/Tables/financial_tables"

**************************************************
* 0. 準備樣本
**************************************************
use "${work}/BASE_delta2019_CA_zinv_COVIDWGT.dta", clear

svyset psu_ca [pweight=wgt_ca], strata(strata_ca) singleunit(scaled)

**************************************************
* 1. Financial difficulties at baseline
**************************************************

count if !missing(d_ghq_likert, bame, fin_diff_base) & bame==1
local N_finbase_b = r(N)

count if !missing(d_ghq_likert, bame, fin_diff_base) & bame==0
local N_finbase_nb = r(N)


* BAME only
svy, subpop(if bame==1 & !missing(fin_diff_base)): regress d_ghq_likert i.fin_diff_base
margins fin_diff_base, ///
    saving("${out}/Tables/financial_tables/marg_fin_diff_base_bame_cells.dta", replace)

* Non-BAME only
svy, subpop(if bame==0 & !missing(fin_diff_base)): regress d_ghq_likert i.fin_diff_base
margins fin_diff_base, ///
    saving("${out}/Tables/financial_tables/marg_fin_diff_base_nonbame_cells.dta", replace)

* pooled difference p-value
svy, subpop(if !missing(fin_diff_base)): regress d_ghq_likert i.bame##i.fin_diff_base
margins fin_diff_base, dydx(bame) ///
    saving("${out}/Tables/financial_tables/marg_fin_diff_base_dydx.dta", replace)

**************************************************
* 2. Change in financial status
**************************************************

count if !missing(d_ghq_likert, bame, fin_change) & bame==1
local N_finchg_b = r(N)

count if !missing(d_ghq_likert, bame, fin_change) & bame==0
local N_finchg_nb = r(N)

* BAME only
svy, subpop(if bame==1 & !missing(fin_change)): regress d_ghq_likert i.fin_change
margins fin_change, ///
    saving("${out}/Tables/financial_tables/marg_fin_change_bame_cells.dta", replace)

* Non-BAME only
svy, subpop(if bame==0 & !missing(fin_change)): regress d_ghq_likert i.fin_change
margins fin_change, ///
    saving("${out}/Tables/financial_tables/marg_fin_change_nonbame_cells.dta", replace)

* pooled difference p-value
svy, subpop(if !missing(fin_change)): regress d_ghq_likert i.bame##i.fin_change
margins fin_change, dydx(bame) ///
    saving("${out}/Tables/financial_tables/marg_fin_change_dydx.dta", replace)
	
**************************************************
* 3. 小工具：格式化文字
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
* 4. Baseline financial difficulties: BAME cells
**************************************************
use "${out}/Tables/financial_tables/marg_fin_diff_base_bame_cells.dta", clear
gen ord = _n

* 假設排序：1 = No (1-2), 2 = Yes (3-5)
quietly summarize _margin if ord==1, meanonly
local fdb_b_b0 = r(mean)
quietly summarize _se if ord==1, meanonly
local fdb_b_se0 = r(mean)

quietly summarize _margin if ord==2, meanonly
local fdb_b_b1 = r(mean)
quietly summarize _se if ord==2, meanonly
local fdb_b_se1 = r(mean)

**************************************************
* 5. Baseline financial difficulties: Non-BAME cells
**************************************************
use "${out}/Tables/financial_tables/marg_fin_diff_base_nonbame_cells.dta", clear
gen ord = _n

quietly summarize _margin if ord==1, meanonly
local fdb_nb_b0 = r(mean)
quietly summarize _se if ord==1, meanonly
local fdb_nb_se0 = r(mean)

quietly summarize _margin if ord==2, meanonly
local fdb_nb_b1 = r(mean)
quietly summarize _se if ord==2, meanonly
local fdb_nb_se1 = r(mean)

**************************************************
* 6. Baseline financial difficulties: difference
**************************************************
use "${out}/Tables/financial_tables/marg_fin_diff_base_dydx.dta", clear
gen ord = _n

quietly summarize _margin if ord==1, meanonly
local fdb_diff_b0 = r(mean)
quietly summarize _se if ord==1, meanonly
local fdb_diff_se0 = r(mean)

quietly summarize _margin if ord==2, meanonly
local fdb_diff_b1 = r(mean)
quietly summarize _se if ord==2, meanonly
local fdb_diff_se1 = r(mean)

**************************************************
* 7. Financial change: BAME cells
**************************************************
use "${out}/Tables/financial_tables/marg_fin_change_bame_cells.dta", clear
gen ord = _n

* 假設排序：1 = Better, 2 = No change, 3 = Worse
forvalues i = 1/3 {
    quietly summarize _margin if ord==`i', meanonly
    local fc_b_b`i' = r(mean)
    quietly summarize _se if ord==`i', meanonly
    local fc_b_se`i' = r(mean)
}

**************************************************
* 8. Financial change: Non-BAME cells
**************************************************
use "${out}/Tables/financial_tables/marg_fin_change_nonbame_cells.dta", clear
gen ord = _n

forvalues i = 1/3 {
    quietly summarize _margin if ord==`i', meanonly
    local fc_nb_b`i' = r(mean)
    quietly summarize _se if ord==`i', meanonly
    local fc_nb_se`i' = r(mean)
}

**************************************************
* 9. Financial change: difference
**************************************************
use "${out}/Tables/financial_tables/marg_fin_change_dydx.dta", clear
gen ord = _n

forvalues i = 1/3 {
    quietly summarize _margin if ord==`i', meanonly
    local fc_diff_b`i' = r(mean)
    quietly summarize _se if ord==`i', meanonly
    local fc_diff_se`i' = r(mean)
}

**************************************************
* 10. Convert number to words
**************************************************

* baseline financial difficulties: 0=No, 1=Yes
forvalues i = 0/1 {
    quietly fmt_coef `fdb_b_b`i'' `fdb_b_se`i''
    local fdb_b_txt`i' `"`r(out)'"'
    quietly fmt_se `fdb_b_se`i''
    local fdb_b_se_txt`i' `"`r(out)'"'

    quietly fmt_coef `fdb_nb_b`i'' `fdb_nb_se`i''
    local fdb_nb_txt`i' `"`r(out)'"'
    quietly fmt_se `fdb_nb_se`i''
    local fdb_nb_se_txt`i' `"`r(out)'"'

    quietly fmt_p `fdb_diff_b`i'' `fdb_diff_se`i''
    local fdb_diff_txt`i' `"`r(out)'"'
}

* financial change: 1=Better, 2=No change, 3=Worse
forvalues i = 1/3 {
    quietly fmt_coef `fc_b_b`i'' `fc_b_se`i''
    local fc_b_txt`i' `"`r(out)'"'
    quietly fmt_se `fc_b_se`i''
    local fc_b_se_txt`i' `"`r(out)'"'

    quietly fmt_coef `fc_nb_b`i'' `fc_nb_se`i''
    local fc_nb_txt`i' `"`r(out)'"'
    quietly fmt_se `fc_nb_se`i''
    local fc_nb_se_txt`i' `"`r(out)'"'

    quietly fmt_p `fc_diff_b`i'' `fc_diff_se`i''
    local fc_diff_txt`i' `"`r(out)'"'
}

**************************************************
* 11. export to Excel
**************************************************
putexcel set "${out}/Tables/financial_tables/Table_BAME_financial.xlsx", replace

putexcel A1 = "Table 2"
putexcel A2 = "Well-being by ethnicity: financial status"

* header
putexcel D4 = "Bame"
putexcel E4 = "Bame"
putexcel F4 = "Non-Bame"
putexcel G4 = "Non-Bame"
putexcel H4 = "Difference"
putexcel H5 = "p-value"

* ---------------- Baseline financial difficulties block ----------------
putexcel A7  = "Financial difficulties at baseline"
putexcel A8  = "No"
putexcel D8  = "`fdb_b_txt0'"
putexcel F8  = "`fdb_nb_txt0'"
putexcel H8  = "`fdb_diff_txt0'"
putexcel D9  = "`fdb_b_se_txt0'"
putexcel F9  = "`fdb_nb_se_txt0'"

putexcel A10 = "Yes"
putexcel D10 = "`fdb_b_txt1'"
putexcel F10 = "`fdb_nb_txt1'"
putexcel H10 = "`fdb_diff_txt1'"
putexcel D11 = "`fdb_b_se_txt1'"
putexcel F11 = "`fdb_nb_se_txt1'"

* ---------------- Change in financial status block ----------------
putexcel A13 = "Change in financial status"
putexcel A14 = "Better"
putexcel E14 = "`fc_b_txt1'"
putexcel G14 = "`fc_nb_txt1'"
putexcel H14 = "`fc_diff_txt1'"
putexcel E15 = "`fc_b_se_txt1'"
putexcel G15 = "`fc_nb_se_txt1'"

putexcel A16 = "No change"
putexcel E16 = "`fc_b_txt2'"
putexcel G16 = "`fc_nb_txt2'"
putexcel H16 = "`fc_diff_txt2'"
putexcel E17 = "`fc_b_se_txt2'"
putexcel G17 = "`fc_nb_se_txt2'"

putexcel A18 = "Worse"
putexcel E18 = "`fc_b_txt3'"
putexcel G18 = "`fc_nb_txt3'"
putexcel H18 = "`fc_diff_txt3'"
putexcel E19 = "`fc_b_se_txt3'"
putexcel G19 = "`fc_nb_se_txt3'"

* ---------------- Observations ----------------
putexcel A21 = "Observations"
putexcel D21 = `N_finbase_b'
putexcel E21 = `N_finchg_b'
putexcel F21 = `N_finbase_nb'
putexcel G21 = `N_finchg_nb'

* notes
putexcel A23 = "Notes: Entries are margins from separate Bame-only and Non-Bame-only survey regressions. Standard errors are in parentheses. Difference reports p-values from pooled models testing Bame vs Non-Bame within each row."
putexcel A24 = "* p<0.10, ** p<0.05, *** p<0.01."
