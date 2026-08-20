****************************************************
* Weighted household composition proportions by ethnicity
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
keep if !missing(single_occ, kids_cat)

*----------------------------------*
* 4. Construct indicators
*----------------------------------*

* Single household
gen byte p_single = 0
replace p_single = 1 if single_occ == 1

* Single household with kids
gen byte p_singlekids = 0
replace p_singlekids = 1 if single_occ == 1 & inlist(kids_cat, 1, 2)

* Children categories
gen byte p_nokids = 0
replace p_nokids = 1 if kids_cat == 0

gen byte p_1to2kids = 0
replace p_1to2kids = 1 if kids_cat == 1

gen byte p_3pkids = 0
replace p_3pkids = 1 if kids_cat == 2

*----------------------------------*
* 5. Weighted proportions
*----------------------------------*
tempfile prop_tbl n_tbl

preserve
    collapse ///
        (mean) p_singlehh     = p_single ///
        (mean) p_singlekids   = p_singlekids ///
        (mean) p_nokids       = p_nokids ///
        (mean) p_1to2kids     = p_1to2kids ///
        (mean) p_3pkids       = p_3pkids ///
        [pw=wgt_ca], by(ethn_order ethn_group)

    foreach v in p_singlehh p_singlekids p_nokids p_1to2kids p_3pkids {
        replace `v' = 100 * `v'
    }

    save `prop_tbl', replace
restore

*----------------------------------*
* 6. Unweighted N
*----------------------------------*
preserve
    collapse (count) n = single_occ, by(ethn_order ethn_group)
    save `n_tbl', replace
restore

*----------------------------------*
* 7. Merge and output
*----------------------------------*
use `prop_tbl', clear
merge 1:1 ethn_order ethn_group using `n_tbl', nogen

format p_singlehh p_singlekids p_nokids p_1to2kids p_3pkids %9.2f
sort ethn_order

list ethn_group p_singlehh p_singlekids p_nokids p_1to2kids p_3pkids n, noobs

save "${out}/Tables/hhcomp_tables/ethnicity_household_shares.dta", replace
export delimited using "${out}/Tables/hhcomp_tables/ethnicity_household_shares.csv", replace

****************************************************
* END
****************************************************
