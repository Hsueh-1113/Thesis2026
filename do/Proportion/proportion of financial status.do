****************************************************
* Weighted financial-status proportions by ethnicity
****************************************************

use "${work}/BASE_delta2019_CA_zinv_COVIDWGT.dta", clear

*----------------------------------*
* 1. Keep valid observations
*----------------------------------*
keep if !missing(wgt_ca)

*----------------------------------*
* 2. Keep selected ethnic groups
*----------------------------------*
capture decode ethn_dv, gen(ethn_str)
if _rc tostring ethn_dv, gen(ethn_str) usedisplayformat
gen strL ethn_low = strlower(strtrim(ethn_str))

gen str60 ethn_group = ""
replace ethn_group = "Pakistani" if ethn_low == "pakistani"
replace ethn_group = "Indian" if ethn_low == "indian"
replace ethn_group = "Bangladeshi" if ethn_low == "bangladeshi"
replace ethn_group = "Any other white background" if ethn_low == "any other white background"
replace ethn_group = "African" if ethn_low == "african"
replace ethn_group = "British/English/Scottish/Welsh/Northern Irish" ///
    if ethn_low == "british/english/scottish/welsh/northern irish"
replace ethn_group = "Caribbean" if ethn_low == "caribbean"

keep if ethn_group != ""

* Order for display
gen byte ethn_order = .
replace ethn_order = 1 if ethn_group == "British/English/Scottish/Welsh/Northern Irish"
replace ethn_order = 2 if ethn_group == "Indian"
replace ethn_order = 3 if ethn_group == "Pakistani"
replace ethn_order = 4 if ethn_group == "Bangladeshi"
replace ethn_order = 5 if ethn_group == "African"
replace ethn_order = 6 if ethn_group == "Caribbean"
replace ethn_order = 7 if ethn_group == "Any other white background"

*----------------------------------*
* 3. Restrict to common denominator
*    so both columns are comparable
*----------------------------------*
keep if !missing(fin_diff_base, fin_change)

*----------------------------------*
* 4. Construct indicators
*----------------------------------*
gen byte ind_findiff = 0
replace ind_findiff = 1 if fin_diff_base == 1

gen byte ind_finworse = 0
replace ind_finworse = 1 if fin_change == 3

*----------------------------------*
* 5. Weighted proportions
*----------------------------------*
tempfile prop_tbl n_tbl

preserve
    collapse ///
        (mean) p_findiff  = ind_findiff ///
        (mean) p_finworse = ind_finworse ///
        [pw=wgt_ca], by(ethn_order ethn_group)

    foreach v in p_findiff p_finworse {
        replace `v' = 100 * `v'
    }

    save `prop_tbl', replace
restore

*----------------------------------*
* 6. Unweighted N
*----------------------------------*
preserve
    collapse (count) n = ind_findiff, by(ethn_order ethn_group)
    save `n_tbl', replace
restore

*----------------------------------*
* 7. Merge and output
*----------------------------------*
use `prop_tbl', clear
merge 1:1 ethn_order ethn_group using `n_tbl', nogen

format p_findiff p_finworse %9.2f
sort ethn_order

list ethn_group p_findiff p_finworse n, noobs

save "${out}/Tables/financial_tables/ethnicity_financial_shares.dta", replace
export delimited using "${out}/Tables/financial_tables/ethnicity_financial_shares.csv", replace

****************************************************
* END
****************************************************
