****************************************************
* Build ethnicity-level table
* using the exact same matched sample
* so that:
* mean_d = mean_CA - mean_2019
****************************************************

use "${work}/GHQ_longpanel_CArespondents_bal2019CA_aprEq_stdinv_CAWGT.dta", clear

* Keep only the two relevant waves
keep if inlist(time_label, "2019", "CA")

* Keep needed vars only
keep pidp ethn_dv wgt_ca ghq_likert_stdinv time_label

*-----------------------------
* Construct person-level 2019 and CA values
*-----------------------------
tempvar y2019 yca

gen double `y2019' = .
replace `y2019' = ghq_likert_stdinv if time_label=="2019"

gen double `yca' = .
replace `yca' = ghq_likert_stdinv if time_label=="CA"

bys pidp: egen ghqL_2019 = max(`y2019')
bys pidp: egen ghqL_CA   = max(`yca')

* Keep one row per person
bys pidp: keep if _n==1

*-----------------------------
* Restrict to the exact matched sample
*-----------------------------
keep if !missing(ethn_dv, wgt_ca, ghqL_2019, ghqL_CA)

* Delta
gen double d_ghq_likert = ghqL_CA - ghqL_2019

* Ethnicity string
capture decode ethn_dv, gen(ethn_str)
if _rc tostring ethn_dv, gen(ethn_str) usedisplayformat

tempfile mean_tbl stats_tbl

*-----------------------------
* 1) Weighted means
*    (all from the same exact sample)
*-----------------------------
preserve
    collapse (mean) mean_2019_ghq_likert=ghqL_2019 ///
             (mean) mean_CA_ghq_likert=ghqL_CA ///
             (mean) mean_d_ghq_likert=d_ghq_likert ///
             [pw=wgt_ca], by(ethn_dv ethn_str)

    save `mean_tbl', replace
restore

*-----------------------------
* 2) Unweighted SD and raw N
*    (same exact sample)
*-----------------------------
collapse (sd) sd_d_ghq_likert=d_ghq_likert ///
         (count) n=d_ghq_likert, by(ethn_dv ethn_str)

save `stats_tbl', replace

*-----------------------------
* 3) Merge
*-----------------------------
use `mean_tbl', clear
merge 1:1 ethn_dv ethn_str using `stats_tbl', nogen

order ethn_dv ethn_str ///
      mean_2019_ghq_likert mean_CA_ghq_likert ///
      mean_d_ghq_likert sd_d_ghq_likert n

sort mean_d_ghq_likert

format mean_2019_ghq_likert mean_CA_ghq_likert mean_d_ghq_likert sd_d_ghq_likert %9.2f
list ethn_str mean_2019_ghq_likert mean_CA_ghq_likert ///
     mean_d_ghq_likert sd_d_ghq_likert n, noobs

* Save
save "${out}/Tables/descriptive table/ethnicity_mean_d_ghq_likert.dta", replace
export delimited using "${out}/Tables/descriptive table/ethnicity_mean_d_ghq_likert.csv", replace

****************************************************
* END
****************************************************
