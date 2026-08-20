cap mkdir "${out}/Tables/demo_tables"

**************************************************
* 0. start
**************************************************
use "${work}/BASE_delta2019_CA_zinv_COVIDWGT_bip.dta", clear

svyset psu_ca [pweight=wgt_ca], strata(strata_ca) singleunit(scaled)

**************************************************
* 1. Sex
**************************************************

count if !missing(d_ghq_likert, bip, sex_bin) & bip==1
local N_sex_b = r(N)

count if !missing(d_ghq_likert, bip, sex_bin) & bip==0
local N_sex_nb = r(N)

* bip only
svy, subpop(if bip==1 & !missing(sex_bin)): regress d_ghq_likert i.sex_bin
margins sex_bin, ///
    saving("${out}/Tables/demo_tables/marg_sex_bin_bip_cells.dta", replace)

* Non-bip only
svy, subpop(if bip==0 & !missing(sex_bin)): regress d_ghq_likert i.sex_bin
margins sex_bin, ///
    saving("${out}/Tables/demo_tables/marg_sex_bin_nonbip_cells.dta", replace)

* pooled difference p-value
svy, subpop(if !missing(sex_bin)): regress d_ghq_likert i.bip##i.sex_bin
margins sex_bin, dydx(bip) ///
    saving("${out}/Tables/demo_tables/marg_sex_bin_dydx.dta", replace)

**************************************************
* 2. Age group
**************************************************

count if !missing(d_ghq_likert, bip, agegrp) & bip==1
local N_age_b = r(N)

count if !missing(d_ghq_likert, bip, agegrp) & bip==0
local N_age_nb = r(N)

* bip only
svy, subpop(if bip==1 & !missing(agegrp)): regress d_ghq_likert i.agegrp
margins agegrp, ///
    saving("${out}/Tables/demo_tables/marg_agegrp_bip_cells.dta", replace)

* Non-bip only
svy, subpop(if bip==0 & !missing(agegrp)): regress d_ghq_likert i.agegrp
margins agegrp, ///
    saving("${out}/Tables/demo_tables/marg_agegrp_nonbip_cells.dta", replace)

* pooled difference p-value
svy, subpop(if !missing(agegrp)): regress d_ghq_likert i.bip##i.agegrp
margins agegrp, dydx(bip) ///
    saving("${out}/Tables/demo_tables/marg_agegrp_dydx.dta", replace)
	
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
* 4. Sex: bip cells
**************************************************
use "${out}/Tables/demo_tables/marg_sex_bin_bip_cells.dta", clear
gen ord = _n

* 1 = Male, 2 = Female
quietly summarize _margin if ord==1, meanonly
local sex_b_b1 = r(mean)
quietly summarize _se if ord==1, meanonly
local sex_b_se1 = r(mean)

quietly summarize _margin if ord==2, meanonly
local sex_b_b2 = r(mean)
quietly summarize _se if ord==2, meanonly
local sex_b_se2 = r(mean)

**************************************************
* 5. Sex: Non-bip cells
**************************************************
use "${out}/Tables/demo_tables/marg_sex_bin_nonbip_cells.dta", clear
gen ord = _n

quietly summarize _margin if ord==1, meanonly
local sex_nb_b1 = r(mean)
quietly summarize _se if ord==1, meanonly
local sex_nb_se1 = r(mean)

quietly summarize _margin if ord==2, meanonly
local sex_nb_b2 = r(mean)
quietly summarize _se if ord==2, meanonly
local sex_nb_se2 = r(mean)

**************************************************
* 6. Sex: difference
**************************************************
use "${out}/Tables/demo_tables/marg_sex_bin_dydx.dta", clear
gen ord = _n

quietly summarize _margin if ord==1, meanonly
local sex_diff_b1 = r(mean)
quietly summarize _se if ord==1, meanonly
local sex_diff_se1 = r(mean)

quietly summarize _margin if ord==2, meanonly
local sex_diff_b2 = r(mean)
quietly summarize _se if ord==2, meanonly
local sex_diff_se2 = r(mean)

**************************************************
* 7. Age group: bip cells
**************************************************
use "${out}/Tables/demo_tables/marg_agegrp_bip_cells.dta", clear
gen ord = _n

* 1=16-29, 2=30-49, 3=50-69, 4=70+
forvalues i = 1/4 {
    quietly summarize _margin if ord==`i', meanonly
    local age_b_b`i' = r(mean)
    quietly summarize _se if ord==`i', meanonly
    local age_b_se`i' = r(mean)
}

**************************************************
* 8. Age group: Non-bip cells
**************************************************
use "${out}/Tables/demo_tables/marg_agegrp_nonbip_cells.dta", clear
gen ord = _n

forvalues i = 1/4 {
    quietly summarize _margin if ord==`i', meanonly
    local age_nb_b`i' = r(mean)
    quietly summarize _se if ord==`i', meanonly
    local age_nb_se`i' = r(mean)
}

**************************************************
* 9. Age group: difference
**************************************************
use "${out}/Tables/demo_tables/marg_agegrp_dydx.dta", clear
gen ord = _n

forvalues i = 1/4 {
    quietly summarize _margin if ord==`i', meanonly
    local age_diff_b`i' = r(mean)
    quietly summarize _se if ord==`i', meanonly
    local age_diff_se`i' = r(mean)
}

**************************************************
* 10. str
**************************************************

* sex: 1=Male, 2=Female
forvalues i = 1/2 {
    quietly fmt_coef `sex_b_b`i'' `sex_b_se`i''
    local sex_b_txt`i' `"`r(out)'"'
    quietly fmt_se `sex_b_se`i''
    local sex_b_se_txt`i' `"`r(out)'"'

    quietly fmt_coef `sex_nb_b`i'' `sex_nb_se`i''
    local sex_nb_txt`i' `"`r(out)'"'
    quietly fmt_se `sex_nb_se`i''
    local sex_nb_se_txt`i' `"`r(out)'"'

    quietly fmt_p `sex_diff_b`i'' `sex_diff_se`i''
    local sex_diff_txt`i' `"`r(out)'"'
}

* agegrp: 1/2/3/4
forvalues i = 1/4 {
    quietly fmt_coef `age_b_b`i'' `age_b_se`i''
    local age_b_txt`i' `"`r(out)'"'
    quietly fmt_se `age_b_se`i''
    local age_b_se_txt`i' `"`r(out)'"'

    quietly fmt_coef `age_nb_b`i'' `age_nb_se`i''
    local age_nb_txt`i' `"`r(out)'"'
    quietly fmt_se `age_nb_se`i''
    local age_nb_se_txt`i' `"`r(out)'"'

    quietly fmt_p `age_diff_b`i'' `age_diff_se`i''
    local age_diff_txt`i' `"`r(out)'"'
}

**************************************************
* 11. Excel
**************************************************
putexcel set "${out}/Tables/demo_tables/Table_bip_demographics.xlsx", replace

putexcel A1 = "Table 6"
putexcel A2 = "Well-being by ethnicity: demographics"

* header
putexcel D4 = "bip"
putexcel E4 = "bip"
putexcel F4 = "Non-bip"
putexcel G4 = "Non-bip"
putexcel H4 = "Difference"
putexcel H5 = "p-value"

* ---------------- Sex block ----------------
putexcel A7  = "Sex"
putexcel A8  = "Male"
putexcel D8  = "`sex_b_txt1'"
putexcel F8  = "`sex_nb_txt1'"
putexcel H8  = "`sex_diff_txt1'"
putexcel D9  = "`sex_b_se_txt1'"
putexcel F9  = "`sex_nb_se_txt1'"

putexcel A10 = "Female"
putexcel D10 = "`sex_b_txt2'"
putexcel F10 = "`sex_nb_txt2'"
putexcel H10 = "`sex_diff_txt2'"
putexcel D11 = "`sex_b_se_txt2'"
putexcel F11 = "`sex_nb_se_txt2'"

* ---------------- Age block ----------------
putexcel A13 = "Age group"
putexcel A14 = "16-29"
putexcel E14 = "`age_b_txt1'"
putexcel G14 = "`age_nb_txt1'"
putexcel H14 = "`age_diff_txt1'"
putexcel E15 = "`age_b_se_txt1'"
putexcel G15 = "`age_nb_se_txt1'"

putexcel A16 = "30-49"
putexcel E16 = "`age_b_txt2'"
putexcel G16 = "`age_nb_txt2'"
putexcel H16 = "`age_diff_txt2'"
putexcel E17 = "`age_b_se_txt2'"
putexcel G17 = "`age_nb_se_txt2'"

putexcel A18 = "50-69"
putexcel E18 = "`age_b_txt3'"
putexcel G18 = "`age_nb_txt3'"
putexcel H18 = "`age_diff_txt3'"
putexcel E19 = "`age_b_se_txt3'"
putexcel G19 = "`age_nb_se_txt3'"

putexcel A20 = "70+"
putexcel E20 = "`age_b_txt4'"
putexcel G20 = "`age_nb_txt4'"
putexcel H20 = "`age_diff_txt4'"
putexcel E21 = "`age_b_se_txt4'"
putexcel G21 = "`age_nb_se_txt4'"

* ---------------- Observations ----------------
putexcel A23 = "Observations"
putexcel D23 = `N_sex_b'
putexcel E23 = `N_age_b'
putexcel F23 = `N_sex_nb'
putexcel G23 = `N_age_nb'

* notes
putexcel A25 = "Notes: Entries are margins from separate bip-only and Non-bip-only survey regressions. Standard errors are in parentheses. Difference reports p-values from pooled models testing bip vs Non-bip within each row."
putexcel A26 = "* p<0.10, ** p<0.05, *** p<0.01."
