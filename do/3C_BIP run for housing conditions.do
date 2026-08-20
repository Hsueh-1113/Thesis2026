cap mkdir "${out}/Tables/housing_tables"

**************************************************
* 0. 準備樣本
**************************************************
use "${work}/BASE_delta2019_CA_zinv_COVIDWGT_bip.dta", clear

svyset psu_ca [pweight=wgt_ca], strata(strata_ca) singleunit(scaled)

**************************************************
* 1. Bedroom ratio category
**************************************************

count if !missing(d_ghq_likert, bip, bedratio_cat) & bip==1
local N_bed_b = r(N)

count if !missing(d_ghq_likert, bip, bedratio_cat) & bip==0
local N_bed_nb = r(N)

* bip only
svy, subpop(if bip==1 & !missing(bedratio_cat)): regress d_ghq_likert i.bedratio_cat
margins bedratio_cat, ///
    saving("${out}/Tables/housing_tables/marg_bedratio_cat_bip_cells.dta", replace)

* Non-bip only
svy, subpop(if bip==0 & !missing(bedratio_cat)): regress d_ghq_likert i.bedratio_cat
margins bedratio_cat, ///
    saving("${out}/Tables/housing_tables/marg_bedratio_cat_nonbip_cells.dta", replace)

* pooled difference p-value
svy, subpop(if !missing(bedratio_cat)): regress d_ghq_likert i.bip##i.bedratio_cat
margins bedratio_cat, dydx(bip) ///
    saving("${out}/Tables/housing_tables/marg_bedratio_cat_dydx.dta", replace)

**************************************************
* 2. Other rooms category
**************************************************

count if !missing(d_ghq_likert, bip, hsrooms_cat) & bip==1
local N_room_b = r(N)

count if !missing(d_ghq_likert, bip, hsrooms_cat) & bip==0
local N_room_nb = r(N)

* bip only
svy, subpop(if bip==1 & !missing(hsrooms_cat)): regress d_ghq_likert i.hsrooms_cat
margins hsrooms_cat, ///
    saving("${out}/Tables/housing_tables/marg_hsrooms_cat_bip_cells.dta", replace)

* Non-bip only
svy, subpop(if bip==0 & !missing(hsrooms_cat)): regress d_ghq_likert i.hsrooms_cat
margins hsrooms_cat, ///
    saving("${out}/Tables/housing_tables/marg_hsrooms_cat_nonbip_cells.dta", replace)

* pooled difference p-value
svy, subpop(if !missing(hsrooms_cat)): regress d_ghq_likert i.bip##i.hsrooms_cat
margins hsrooms_cat, dydx(bip) ///
    saving("${out}/Tables/housing_tables/marg_hsrooms_cat_dydx.dta", replace)

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
* 4. Bedroom ratio category: bip cells
**************************************************
use "${out}/Tables/housing_tables/marg_bedratio_cat_bip_cells.dta", clear
gen ord = _n

* 1 = <1 per person, 2 = 1-<2 per person, 3 = >=2 per person
forvalues i = 1/3 {
    quietly summarize _margin if ord==`i', meanonly
    local bed_b_b`i' = r(mean)
    quietly summarize _se if ord==`i', meanonly
    local bed_b_se`i' = r(mean)
}

**************************************************
* 5. Bedroom ratio category: Non-bip cells
**************************************************
use "${out}/Tables/housing_tables/marg_bedratio_cat_nonbip_cells.dta", clear
gen ord = _n

forvalues i = 1/3 {
    quietly summarize _margin if ord==`i', meanonly
    local bed_nb_b`i' = r(mean)
    quietly summarize _se if ord==`i', meanonly
    local bed_nb_se`i' = r(mean)
}

**************************************************
* 6. Bedroom ratio category: difference
**************************************************
use "${out}/Tables/housing_tables/marg_bedratio_cat_dydx.dta", clear
gen ord = _n

forvalues i = 1/3 {
    quietly summarize _margin if ord==`i', meanonly
    local bed_diff_b`i' = r(mean)
    quietly summarize _se if ord==`i', meanonly
    local bed_diff_se`i' = r(mean)
}

**************************************************
* 7. Other rooms category: bip cells
**************************************************
use "${out}/Tables/housing_tables/marg_hsrooms_cat_bip_cells.dta", clear
gen ord = _n

* 1 = 0-1 rooms, 2 = 2-3 rooms, 3 = 4+ rooms
forvalues i = 1/3 {
    quietly summarize _margin if ord==`i', meanonly
    local room_b_b`i' = r(mean)
    quietly summarize _se if ord==`i', meanonly
    local room_b_se`i' = r(mean)
}

**************************************************
* 8. Other rooms category: Non-bip cells
**************************************************
use "${out}/Tables/housing_tables/marg_hsrooms_cat_nonbip_cells.dta", clear
gen ord = _n

forvalues i = 1/3 {
    quietly summarize _margin if ord==`i', meanonly
    local room_nb_b`i' = r(mean)
    quietly summarize _se if ord==`i', meanonly
    local room_nb_se`i' = r(mean)
}

**************************************************
* 9. Other rooms category: difference
**************************************************
use "${out}/Tables/housing_tables/marg_hsrooms_cat_dydx.dta", clear
gen ord = _n

forvalues i = 1/3 {
    quietly summarize _margin if ord==`i', meanonly
    local room_diff_b`i' = r(mean)
    quietly summarize _se if ord==`i', meanonly
    local room_diff_se`i' = r(mean)
}

**************************************************
* 10. Num to str
**************************************************

* bed ratio: 1/2/3
forvalues i = 1/3 {
    quietly fmt_coef `bed_b_b`i'' `bed_b_se`i''
    local bed_b_txt`i' `"`r(out)'"'
    quietly fmt_se `bed_b_se`i''
    local bed_b_se_txt`i' `"`r(out)'"'

    quietly fmt_coef `bed_nb_b`i'' `bed_nb_se`i''
    local bed_nb_txt`i' `"`r(out)'"'
    quietly fmt_se `bed_nb_se`i''
    local bed_nb_se_txt`i' `"`r(out)'"'

    quietly fmt_p `bed_diff_b`i'' `bed_diff_se`i''
    local bed_diff_txt`i' `"`r(out)'"'
}

* rooms: 1/2/3
forvalues i = 1/3 {
    quietly fmt_coef `room_b_b`i'' `room_b_se`i''
    local room_b_txt`i' `"`r(out)'"'
    quietly fmt_se `room_b_se`i''
    local room_b_se_txt`i' `"`r(out)'"'

    quietly fmt_coef `room_nb_b`i'' `room_nb_se`i''
    local room_nb_txt`i' `"`r(out)'"'
    quietly fmt_se `room_nb_se`i''
    local room_nb_se_txt`i' `"`r(out)'"'

    quietly fmt_p `room_diff_b`i'' `room_diff_se`i''
    local room_diff_txt`i' `"`r(out)'"'
}

**************************************************
* 11. Excel
**************************************************
putexcel set "${out}/Tables/housing_tables/Table_bip_housing.xlsx", replace

putexcel A1 = "Table 3"
putexcel A2 = "Well-being by ethnicity: housing conditions"

* header
putexcel D4 = "bip"
putexcel E4 = "bip"
putexcel F4 = "Non-bip"
putexcel G4 = "Non-bip"
putexcel H4 = "Difference"
putexcel H5 = "p-value"

* ---------------- Bedroom ratio block ----------------
putexcel A7  = "Bedroom-per-person ratio at baseline"

putexcel A8  = "<1 per person"
putexcel D8  = "`bed_b_txt1'"
putexcel F8  = "`bed_nb_txt1'"
putexcel H8  = "`bed_diff_txt1'"
putexcel D9  = "`bed_b_se_txt1'"
putexcel F9  = "`bed_nb_se_txt1'"

putexcel A10 = "1-<2 per person"
putexcel D10 = "`bed_b_txt2'"
putexcel F10 = "`bed_nb_txt2'"
putexcel H10 = "`bed_diff_txt2'"
putexcel D11 = "`bed_b_se_txt2'"
putexcel F11 = "`bed_nb_se_txt2'"

putexcel A12 = ">=2 per person"
putexcel D12 = "`bed_b_txt3'"
putexcel F12 = "`bed_nb_txt3'"
putexcel H12 = "`bed_diff_txt3'"
putexcel D13 = "`bed_b_se_txt3'"
putexcel F13 = "`bed_nb_se_txt3'"

* ---------------- Other rooms block ----------------
putexcel A15 = "Other rooms at baseline"

putexcel A16 = "0-1 rooms"
putexcel E16 = "`room_b_txt1'"
putexcel G16 = "`room_nb_txt1'"
putexcel H16 = "`room_diff_txt1'"
putexcel E17 = "`room_b_se_txt1'"
putexcel G17 = "`room_nb_se_txt1'"

putexcel A18 = "2-3 rooms"
putexcel E18 = "`room_b_txt2'"
putexcel G18 = "`room_nb_txt2'"
putexcel H18 = "`room_diff_txt2'"
putexcel E19 = "`room_b_se_txt2'"
putexcel G19 = "`room_nb_se_txt2'"

putexcel A20 = "4+ rooms"
putexcel E20 = "`room_b_txt3'"
putexcel G20 = "`room_nb_txt3'"
putexcel H20 = "`room_diff_txt3'"
putexcel E21 = "`room_b_se_txt3'"
putexcel G21 = "`room_nb_se_txt3'"

* ---------------- Observations ----------------
putexcel A23 = "Observations"
putexcel D23 = `N_bed_b'
putexcel E23 = `N_room_b'
putexcel F23 = `N_bed_nb'
putexcel G23 = `N_room_nb'

* notes
putexcel A25 = "Notes: Entries are margins from separate bip-only and Non-bip-only survey regressions. Standard errors are in parentheses. Difference reports p-values from pooled models testing bip vs Non-bip within each row."
putexcel A26 = "* p<0.10, ** p<0.05, *** p<0.01."
