****************************************************
* Weighted sex and age-group proportions by ethnicity
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
keep if !missing(sex_bin, agegrp)

*----------------------------------*
* 4. Construct indicators
*----------------------------------*

* Female
gen byte p_female = 0
replace p_female = 1 if sex_bin == 2

* Age groups
gen byte p_age1629 = 0
replace p_age1629 = 1 if agegrp == 1

gen byte p_age3049 = 0
replace p_age3049 = 1 if agegrp == 2

gen byte p_age5069 = 0
replace p_age5069 = 1 if agegrp == 3

gen byte p_age70p = 0
replace p_age70p = 1 if agegrp == 4

*----------------------------------*
* 5. Weighted proportions
*----------------------------------*
tempfile prop_tbl n_tbl

preserve
    collapse ///
        (mean) p_female  = p_female ///
        (mean) p_age1629 = p_age1629 ///
        (mean) p_age3049 = p_age3049 ///
        (mean) p_age5069 = p_age5069 ///
        (mean) p_age70p  = p_age70p ///
        [pw=wgt_ca], by(ethn_order ethn_group)

    foreach v in p_female p_age1629 p_age3049 p_age5069 p_age70p {
        replace `v' = 100 * `v'
    }

    save `prop_tbl', replace
restore

*----------------------------------*
* 6. Unweighted N
*----------------------------------*
preserve
    collapse (count) n = sex_bin, by(ethn_order ethn_group)
    save `n_tbl', replace
restore

*----------------------------------*
* 7. Merge and output
*----------------------------------*
use `prop_tbl', clear
merge 1:1 ethn_order ethn_group using `n_tbl', nogen

format p_female p_age1629 p_age3049 p_age5069 p_age70p %9.2f
sort ethn_order

list ethn_group p_female p_age1629 p_age3049 p_age5069 p_age70p n, noobs

save "${out}/Tables/demo_tables/ethnicity_demographic_shares.dta", replace
export delimited using "${out}/Tables/demo_tables/ethnicity_demographic_shares.csv", replace

****************************************************
* END
****************************************************
