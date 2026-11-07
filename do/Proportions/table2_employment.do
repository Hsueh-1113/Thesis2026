****************************************************
* Weighted proportions by ethnicity among FULL SAMPLE
* consistent with full-sample employment specification
****************************************************

use "${work}/BASE_delta2019_CA_zinv_COVIDWGT.dta", clear
keep if prework == 1
keep if !missing(wgt_ca)

*----------------------------------*
* 1. Build full-sample employment variables
*----------------------------------*
capture drop ca_hours_clean ca_blhours_clean hours_reduced furlough ///
             emp_change keyworker selfemp_only pre_nonwork

gen double ca_hours_clean = ca_hours
replace ca_hours_clean = . if ca_hours_clean < 0

gen double ca_blhours_clean = ca_blhours
replace ca_blhours_clean = . if ca_blhours_clean < 0

gen byte hours_reduced = .
replace hours_reduced = (ca_hours_clean + 1 < ca_blhours_clean) ///
    if ca_blhours_clean>0 & !missing(ca_hours_clean, ca_blhours_clean)

gen byte furlough = .
replace furlough = (ca_furlough==1) if !missing(ca_furlough)

* full-sample employment status
* 0 = Not working pre-COVID
* 1 = No change
* 2 = Reduction
* 3 = Job loss
gen byte emp_change = .
replace emp_change = 3 if prework==1 & ca_sempderived==4
replace emp_change = 2 if prework==1 & inlist(ca_sempderived,1,2,3) ///
    & (furlough==1 | hours_reduced==1)
replace emp_change = 1 if prework==1 & inlist(ca_sempderived,1,2,3) ///
    & ((furlough==0 | missing(furlough)) & (hours_reduced==0 | missing(hours_reduced)))

label define empchg 1 "No change" 2 "Reduction" 3 "Job loss", replace
label values emp_change empchg

* keyworker = 1 only for stable workers who are key workers
gen byte keyworker = .
replace keyworker = 1 if ca_keyworker == 1 & inlist(ca_sempderived,1,2,3) & /// 
((furlough==0 | missing(furlough)) & (hours_reduced==0 | missing(hours_reduced))) 
replace keyworker = 0 if ca_keyworker == 2 & inlist(ca_sempderived,1,2,3) & ///
((furlough==0 | missing(furlough)) & (hours_reduced==0 | missing(hours_reduced))) 
label define keyw 0 "No" 1 "Yes", replace 
label values keyworker keyw

* self-employed = 1 only for pre-pandemic self-employed only
gen byte selfemp_only = .
replace selfemp_only = (ca_blwork==2) if !missing(ca_blwork) 
label define selfemp 0 "No" 1 "Yes", replace 
label values selfemp_only selfemp

*----------------------------------*
* 2. Ethnicity labels
*----------------------------------*
capture decode ethn_dv, gen(ethn_str)
if _rc tostring ethn_dv, gen(ethn_str) usedisplayformat
gen strL ethn_low = strlower(strtrim(ethn_str))

gen str60 ethn_group = ""
replace ethn_group = "Pakistani" if ethn_low=="pakistani"
replace ethn_group = "Indian" if ethn_low=="indian"
replace ethn_group = "Bangladeshi" if ethn_low=="bangladeshi"
replace ethn_group = "Any other white background" if ethn_low=="any other white background"
replace ethn_group = "African" if ethn_low=="african"
replace ethn_group = "British/English/Scottish/Welsh/Northern Irish" ///
    if ethn_low=="british/english/scottish/welsh/northern irish"
replace ethn_group = "Caribbean" if ethn_low=="caribbean"

keep if ethn_group != ""

gen byte ethn_order = .
replace ethn_order = 1 if ethn_group=="British/English/Scottish/Welsh/Northern Irish"
replace ethn_order = 2 if ethn_group=="Indian"
replace ethn_order = 3 if ethn_group=="Pakistani"
replace ethn_order = 4 if ethn_group=="Bangladeshi"
replace ethn_order = 5 if ethn_group=="African"
replace ethn_order = 6 if ethn_group=="Caribbean"
replace ethn_order = 7 if ethn_group=="Any other white background"

*----------------------------------*
* 3. Build 0/1 indicators
*    denominator = FULL SAMPLE within ethnicity
*----------------------------------*
* Reduction 
gen byte reduction_ind = . 
replace reduction_ind = 1 if emp_change==2 
replace reduction_ind = 0 if inlist(emp_change,1,3) 

* Job loss 
gen byte jobloss_ind = . 
replace jobloss_ind = 1 if emp_change==3 
replace jobloss_ind = 0 if inlist(emp_change,1,2) 

* Keyworker share among all prework workers 
* = share who are classified as keyworkers 
gen byte keyworker_ind = . 
replace keyworker_ind = 1 if keyworker==1
replace keyworker_ind = 0 if prework==1 & keyworker!=1 & !missing(emp_change) 


* Self-employment share among all prework workers 
* = share who are self-employed and in reduction/job loss group 
gen byte selfemp_ind = . 
replace selfemp_ind = 1 if selfemp_only==1 
replace selfemp_ind = 0 if prework==1 & selfemp_only!=1 & !missing(emp_change)

*----------------------------------*
* 4. Collapse to ethnicity-level table
*----------------------------------*
collapse ///
    (mean) p_reduction   = reduction_ind ///
    (mean) p_jobloss     = jobloss_ind ///
    (mean) p_keyworker   = keyworker_ind ///
    (mean) p_selfemp     = selfemp_ind ///
    (count) n            = emp_change ///
    [pw=wgt_ca], by(ethn_order ethn_group)

* Convert to percentages
foreach v in p_reduction p_jobloss p_keyworker p_selfemp {
    replace `v' = 100*`v'
}

format p_reduction p_jobloss p_keyworker p_selfemp %9.2f
sort ethn_order

list ethn_group p_reduction p_jobloss p_keyworker p_selfemp n, noobs

* Save
save "${out}/Tables/employment_tables/ethnicity_employment_shares_prework.dta", replace
export delimited using "${out}/Tables/employment_tables/ethnicity_employment_shares_prework.csv", replace

****************************************************
* END
****************************************************
