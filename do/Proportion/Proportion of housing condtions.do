****************************************************
* Weighted housing proportions by ethnicity
* Bedroom-per-person ratio and other rooms at baseline
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
*    so all columns are comparable
*----------------------------------*
keep if !missing(bedratio_cat, hsrooms_cat)

*----------------------------------*
* 4. Construct indicators
*----------------------------------*

* Bedroom-per-person ratio
gen byte bed_lt1 = 0
replace bed_lt1 = 1 if bedratio_cat == 1

gen byte bed_1to2 = 0
replace bed_1to2 = 1 if bedratio_cat == 2

gen byte bed_ge2 = 0
replace bed_ge2 = 1 if bedratio_cat == 3

* Other rooms at baseline
gen byte room_01 = 0
replace room_01 = 1 if hsrooms_cat == 1

gen byte room_23 = 0
replace room_23 = 1 if hsrooms_cat == 2

gen byte room_4p = 0
replace room_4p = 1 if hsrooms_cat == 3

*----------------------------------*
* 5. Weighted proportions
*----------------------------------*
tempfile prop_tbl n_tbl

preserve
    collapse ///
        (mean) p_bed_lt1 = bed_lt1 ///
        (mean) p_bed_1to2 = bed_1to2 ///
        (mean) p_bed_ge2 = bed_ge2 ///
        (mean) p_room_01 = room_01 ///
        (mean) p_room_23 = room_23 ///
        (mean) p_room_4p = room_4p ///
        [pw=wgt_ca], by(ethn_order ethn_group)

    foreach v in p_bed_lt1 p_bed_1to2 p_bed_ge2 p_room_01 p_room_23 p_room_4p {
        replace `v' = 100 * `v'
    }

    save `prop_tbl', replace
restore

*----------------------------------*
* 6. Unweighted N
*----------------------------------*
preserve
    collapse (count) n = bedratio_cat, by(ethn_order ethn_group)
    save `n_tbl', replace
restore

*----------------------------------*
* 7. Merge and output
*----------------------------------*
use `prop_tbl', clear
merge 1:1 ethn_order ethn_group using `n_tbl', nogen

format p_bed_lt1 p_bed_1to2 p_bed_ge2 ///
       p_room_01 p_room_23 p_room_4p %9.2f

sort ethn_order

list ethn_group ///
     p_bed_lt1 p_bed_1to2 p_bed_ge2 ///
     p_room_01 p_room_23 p_room_4p ///
     n, noobs

* Save
save "${out}/Tables/housing_tables/ethnicity_housing_shares.dta", replace
export delimited using "${out}/Tables/housing_tables/ethnicity_housing_shares.csv", replace

****************************************************
* END
****************************************************
