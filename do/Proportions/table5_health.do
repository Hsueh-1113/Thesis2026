****************************************************
* Weighted health proportions by ethnicity
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
* 3. Use a common denominator
*----------------------------------*
keep if !missing(covid_symp, cc_resp, cc_cardio, cc_endo, cc_arth, cc_other)

*----------------------------------*
* 4. Weighted proportions
*----------------------------------*
tempfile prop_tbl n_tbl

preserve
    collapse ///
        (mean) p_covidsymp = covid_symp ///
        (mean) p_resp      = cc_resp ///
        (mean) p_cardio    = cc_cardio ///
        (mean) p_endo      = cc_endo ///
        (mean) p_arth      = cc_arth ///
        (mean) p_other     = cc_other ///
        [pw=wgt_ca], by(ethn_order ethn_group)

    foreach v in p_covidsymp p_resp p_cardio p_endo p_arth p_other {
        replace `v' = 100 * `v'
    }

    save `prop_tbl', replace
restore

*----------------------------------*
* 5. Unweighted N
*----------------------------------*
preserve
    collapse (count) n = covid_symp, by(ethn_order ethn_group)
    save `n_tbl', replace
restore

*----------------------------------*
* 6. Merge and output
*----------------------------------*
use `prop_tbl', clear
merge 1:1 ethn_order ethn_group using `n_tbl', nogen

format p_covidsymp p_resp p_cardio p_endo p_arth p_other %9.2f
sort ethn_order

list ethn_group p_covidsymp p_resp p_cardio p_endo p_arth p_other n, noobs

save "${out}/Tables/health_tables/ethnicity_health_shares.dta", replace
export delimited using "${out}/Tables/health_tables/ethnicity_health_shares.csv", replace

****************************************************
* END
****************************************************
