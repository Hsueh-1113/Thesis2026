****************************************************
* STEP 1: Build BASE (person-level delta) from
*         COVID-weight-only standardized file
****************************************************
use "${work}/GHQ_longpanel_CArespondents_bal2019CA_aprEq_stdinv_CAWGT.dta", clear

* Here we only see for people in 2019 and CA
keep if inlist(time_label, "2019", "CA")

*-----------------------------
* bip
*-----------------------------
keep if !missing(ethn_dv)

capture decode ethn_dv, gen(ethn_str)
if _rc tostring ethn_dv, gen(ethn_str) usedisplayformat
gen strL ethn_low = strlower(strtrim(ethn_str))

capture drop bip
gen byte bip = .
replace bip = 1 if inlist(ethn_low, "indian","pakistani","bangladeshi")
replace bip = 0 if strpos(ethn_low, "british/english/scottish/welsh/northern irish") > 0
drop if missing(bip)

label define bip_lbl 0 "Non-BIP" 1 "BIP", replace
label values bip bip_lbl

*-----------------------------
* Tempfiles
*-----------------------------
tempfile ca_empraw fin_j fin_k fin_base fin_ca ///
         pid_hid_j pid_hid_k pid_hid_base ///
         hh_j hh_k hh_base ///
         ca_health

*-----------------------------
* Merge CA employment raw vars
*-----------------------------
preserve
    use "${p8644}/ca_indresp_w.dta", clear
    keep pidp ca_blwork ca_sempderived ca_furlough ca_hours ca_blhours ca_keyworker
    save `ca_empraw', replace
restore

merge m:1 pidp using `ca_empraw', keep(match) nogen

*-----------------------------
* Prepare financial raw vars
*-----------------------------

* j
preserve
    use "${p6614}/j_indresp.dta", clear
    keep pidp j_finnow
    rename j_finnow finnow_j
    replace finnow_j = . if finnow_j < 0 & !missing(finnow_j)
    save `fin_j', replace
restore

* k
preserve
    use "${p6614}/k_indresp.dta", clear
    keep pidp k_finnow
    rename k_finnow finnow_k
    replace finnow_k = . if finnow_k < 0 & !missing(finnow_k)
    save `fin_k', replace
restore

* baseline combine: k > j
preserve
    use `fin_j', clear
    merge 1:1 pidp using `fin_k', nogen

    gen double base_finnow = finnow_k
    replace base_finnow = finnow_j if missing(base_finnow) & !missing(finnow_j)

    keep pidp base_finnow
    save `fin_base', replace
restore

* CA finnow
preserve
    use "${p8644}/ca_indresp_w.dta", clear
    keep pidp ca_finnow
    replace ca_finnow = . if ca_finnow < 0 & !missing(ca_finnow)
    save `fin_ca', replace
restore

* merge financial raw vars into main file
merge m:1 pidp using `fin_base', keep(master match) nogen
merge m:1 pidp using `fin_ca',   keep(master match) nogen

*-----------------------------
* Prepare housing raw vars
*-----------------------------

* baseline hidp from k > j  indresp
preserve
    use "${p6614}/j_indresp.dta", clear
    keep pidp j_hidp
    rename j_hidp hidp_j
    duplicates drop pidp, force
    save `pid_hid_j', replace
restore

preserve
    use "${p6614}/k_indresp.dta", clear
    keep pidp k_hidp
    rename k_hidp hidp_k
    duplicates drop pidp, force
    save `pid_hid_k', replace
restore

preserve
    use `pid_hid_j', clear
    merge 1:1 pidp using `pid_hid_k', nogen

    gen long hidp = hidp_k
    replace hidp = hidp_j if missing(hidp) & !missing(hidp_j)

    keep pidp hidp
    save `pid_hid_base', replace
restore

* merge hidp into main file
merge m:1 pidp using `pid_hid_base', keep(master match) nogen

* j_hhresp
preserve
    use "${p6614}/j_hhresp.dta", clear
    keep j_hidp j_hsownd j_hsbeds j_hhsize j_hsrooms
    rename j_hidp hidp
    rename (j_hsownd j_hsbeds j_hhsize j_hsrooms) ///
           (hsownd_j hsbeds_j hhsize_j hsrooms_j)

    foreach v in hsownd_j hsbeds_j hhsize_j hsrooms_j {
        replace `v' = . if `v' < 0 & !missing(`v')
    }
    save `hh_j', replace
restore

* k_hhresp
preserve
    use "${p6614}/k_hhresp.dta", clear
    keep k_hidp k_hsownd k_hsbeds k_hhsize k_hsrooms
    rename k_hidp hidp
    rename (k_hsownd k_hsbeds k_hhsize k_hsrooms) ///
           (hsownd_k hsbeds_k hhsize_k hsrooms_k)

    foreach v in hsownd_k hsbeds_k hhsize_k hsrooms_k {
        replace `v' = . if `v' < 0 & !missing(`v')
    }
    save `hh_k', replace
restore


* combine j/k by hidp (prefer k > j)
preserve
    use `hh_j', clear
    merge 1:1 hidp using `hh_k', nogen

    gen double hsownd_base = hsownd_k
    replace hsownd_base = hsownd_j if missing(hsownd_base) & !missing(hsownd_j)

    gen double hsbeds_base = hsbeds_k
    replace hsbeds_base = hsbeds_j if missing(hsbeds_base) & !missing(hsbeds_j)

    gen double hhsize_base = hhsize_k
    replace hhsize_base = hhsize_j if missing(hhsize_base) & !missing(hhsize_j)

    gen double hsrooms_base = hsrooms_k
    replace hsrooms_base = hsrooms_j if missing(hsrooms_base) & !missing(hsrooms_j)

    * owner indicator
    gen byte owner_base = .
    replace owner_base = 1 if inlist(hsownd_base,1,2,3)
    replace owner_base = 0 if inlist(hsownd_base,4,5,97)
    label define ownerlbl 0 "Not owner" 1 "Owner", replace
    label values owner_base ownerlbl
	
	* space measures
    gen double bedratio_base = .
    replace bedratio_base = hsbeds_base / hhsize_base ///
        if !missing(hsbeds_base, hhsize_base) & hhsize_base > 0

    gen double hsrooms_base2 = hsrooms_base
	
	* grouped bed ratio
	capture drop bedratio_cat
	gen byte bedratio_cat = .
	replace bedratio_cat = 1 if !missing(bedratio_base) & bedratio_base < 1
	replace bedratio_cat = 2 if !missing(bedratio_base) & bedratio_base >= 1 & bedratio_base < 2
	replace bedratio_cat = 3 if !missing(bedratio_base) & bedratio_base >= 2

	label define bedr 1 "<1 per person" 2 "1-<2 per person" 3 ">=2 per person", replace
	label values bedratio_cat bedr
	label var bedratio_cat "Bedroom-per-person category (baseline)"

	* grouped number of other rooms
	capture drop hsrooms_cat
	gen byte hsrooms_cat = .
	replace hsrooms_cat = 1 if !missing(hsrooms_base2) & inrange(hsrooms_base2,0,1)
	replace hsrooms_cat = 2 if !missing(hsrooms_base2) & inrange(hsrooms_base2,2,3)
	replace hsrooms_cat = 3 if !missing(hsrooms_base2) & hsrooms_base2 >= 4

	label define roomc 1 "0-1 rooms" 2 "2-3 rooms" 3 "4+ rooms", replace
	label values hsrooms_cat roomc
	label var hsrooms_cat "Other rooms category (baseline)"
	
    keep hidp owner_base bedratio_base hsrooms_base2 bedratio_cat hsrooms_cat
    isid hidp
    save `hh_base', replace
restore


* merge housing vars into main file
merge m:1 hidp using `hh_base', keep(master match) nogen

*-----------------------------
* Prepare health raw vars
*-----------------------------
preserve
    use "${p8644}/ca_indresp_w.dta", clear

    keep pidp ca_hadsymp ca_chscnowcarer ///
        ca_hcond_cv1 ca_hcond_cv2 ca_hcond_cv3 ca_hcond_cv4 ca_hcond_cv5 ca_hcond_cv6 ca_hcond_cv7 ///
        ca_hcond_cv8 ca_hcond_cv10 ca_hcond_cv11 ca_hcond_cv12 ca_hcond_cv13 ca_hcond_cv14 ca_hcond_cv15 ///
        ca_hcond_cv16 ca_hcond_cv18 ca_hcond_cv19 ca_hcond_cv21 ca_hcond_cv22 ca_hcond_cv23 ///
        ca_hcond_cv24 ca_hcond_cv27

    * <0 -> missing for all kept vars
    foreach v of varlist ca_* {
        replace `v' = . if `v' < 0 & !missing(`v')
    }

    save `ca_health', replace
restore

merge m:1 pidp using `ca_health', keep(master match) nogen

*-----------------------------
* Compute person-level deltas (Likert & Case)
*-----------------------------
tempvar y2019 yca

* Likert
gen double `y2019' = .
replace `y2019' = ghq_likert_stdinv if time_label=="2019"

gen double `yca' = .
replace `yca' = ghq_likert_stdinv if time_label=="CA"

bys pidp: egen ghqL_2019 = max(`y2019')
bys pidp: egen ghqL_CA   = max(`yca')

* Case
replace `y2019' = .
replace `y2019' = ghq_case_stdinv if time_label=="2019"

replace `yca' = .
replace `yca' = ghq_case_stdinv if time_label=="CA"

bys pidp: egen ghqC_2019 = max(`y2019')
bys pidp: egen ghqC_CA   = max(`yca')

* keep if CA
keep if time_label=="CA"

* balanced outcome
drop if missing(ghqL_2019, ghqL_CA)

gen double d_ghq_likert = ghqL_CA - ghqL_2019
gen double d_ghq_case   = ghqC_CA - ghqC_2019 

*-----------------------------
* People who is working in the pre-pandemic
*-----------------------------
capture drop prework
gen byte prework = .
replace prework = inlist(ca_blwork,1,2,3) if !missing(ca_blwork)

*-----------------------------
* Financial status classifications
*-----------------------------

* (1) baseline financial difficulties: base_finnow==3, 4 or 5
capture drop fin_diff_base
gen byte fin_diff_base = .
replace fin_diff_base = 1 if inlist(base_finnow,3,4,5)
replace fin_diff_base = 0 if inlist(base_finnow,1,2)
label define findif 0 "No " 1 "Yes", replace
label values fin_diff_base findif
label var fin_diff_base "Financial difficulties at baseline (base_finnow=3/4/5)"

* (2) change: better / no change / worse (lower=better)
capture drop fin_change
gen byte fin_change = .
replace fin_change = 1 if !missing(base_finnow, ca_finnow) & ca_finnow < base_finnow
replace fin_change = 2 if !missing(base_finnow, ca_finnow) & ca_finnow == base_finnow
replace fin_change = 3 if !missing(base_finnow, ca_finnow) & ca_finnow > base_finnow
label define finchg 1 "Better" 2 "No change" 3 "Worse", replace
label values fin_change finchg
label var fin_change "Change in financial status: CA vs baseline (lower=better)"



*-----------------------------
* Health factors
*-----------------------------

* (1) COVID symptoms: Yes=1, No=0
capture drop covid_symp
gen byte covid_symp = .
replace covid_symp = 1 if ca_hadsymp==1
replace covid_symp = 0 if ca_hadsymp==2
label define yn 0 "No" 1 "Yes", replace
label values covid_symp yn
label var covid_symp "COVID symptoms (ca_hadsymp)"

* (2) Change in health services/care
* 1/4/5 = No change; 2 = Reduce; 3 = Increase
capture drop hs_change
gen byte hs_change = .
replace hs_change = 1 if inlist(ca_chscnowcarer,1,4,5)
replace hs_change = 2 if ca_chscnowcarer==2
replace hs_change = 3 if ca_chscnowcarer==3
label define hschg 1 "No change" 2 "Reduce" 3 "Increase", replace
label values hs_change hschg
label var hs_change "Change in health services/care (ca_chscnowcarer)"

* Chronic conditions
local resp   ca_hcond_cv1 ca_hcond_cv8 ca_hcond_cv11 ca_hcond_cv21
local cardio ca_hcond_cv3 ca_hcond_cv4 ca_hcond_cv5 ca_hcond_cv6 ca_hcond_cv7 ca_hcond_cv16
local endo   ca_hcond_cv10 ca_hcond_cv14
local other  ca_hcond_cv12 ca_hcond_cv13 ca_hcond_cv15 ca_hcond_cv22 ca_hcond_cv19 ///
             ca_hcond_cv23 ca_hcond_cv24 ca_hcond_cv27 ca_hcond_cv18

* --- Respiratory ---
capture drop cc_resp
gen byte cc_resp = .
local resp_m ""
foreach v of local resp {
    capture confirm variable `v'
    if !_rc {
        capture drop m_`v'
        gen byte m_`v' = .
        replace m_`v' = 1 if `v'==1
        replace m_`v' = 0 if inlist(`v',0)
        local resp_m "`resp_m' m_`v'"
    }
}
if "`resp_m'" != "" {
    egen byte _cc_resp = rowmax(`resp_m')
    replace cc_resp = _cc_resp
    drop _cc_resp
}
drop `resp_m'
label values cc_resp yn
label var cc_resp "Chronic condition: Respiratory"

* --- Cardiovascular ---
capture drop cc_cardio
gen byte cc_cardio = .
local cardio_m ""
foreach v of local cardio {
    capture confirm variable `v'
    if !_rc {
        capture drop m_`v'
        gen byte m_`v' = .
        replace m_`v' = 1 if `v'==1
        replace m_`v' = 0 if inlist(`v',0)
        local cardio_m "`cardio_m' m_`v'"
    }
}
if "`cardio_m'" != "" {
    egen byte _cc_cardio = rowmax(`cardio_m')
    replace cc_cardio = _cc_cardio
    drop _cc_cardio
}
drop `cardio_m'
label values cc_cardio yn
label var cc_cardio "Chronic condition: Cardiovascular"

* --- Endocrine ---
capture drop cc_endo
gen byte cc_endo = .
local endo_m ""
foreach v of local endo {
    capture confirm variable `v'
    if !_rc {
        capture drop m_`v'
        gen byte m_`v' = .
        replace m_`v' = 1 if `v'==1
        replace m_`v' = 0 if inlist(`v',0)
        local endo_m "`endo_m' m_`v'"
    }
}
if "`endo_m'" != "" {
    egen byte _cc_endo = rowmax(`endo_m')
    replace cc_endo = _cc_endo
    drop _cc_endo
}
drop `endo_m'
label values cc_endo yn
label var cc_endo "Chronic condition: Endocrine"

* --- Arthritis ---
capture drop cc_arth
gen byte cc_arth = .
replace cc_arth = 1 if ca_hcond_cv2==1
replace cc_arth = 0 if inlist(ca_hcond_cv2,0)
label values cc_arth yn
label var cc_arth "Chronic condition: Arthritis"

* --- Other conditions ---
capture drop cc_other
gen byte cc_other = .
local other_m ""
foreach v of local other {
    capture confirm variable `v'
    if !_rc {
        capture drop m_`v'
        gen byte m_`v' = .
        replace m_`v' = 1 if `v'==1
        replace m_`v' = 0 if inlist(`v',0)
        local other_m "`other_m' m_`v'"
    }
}
if "`other_m'" != "" {
    egen byte _cc_other = rowmax(`other_m')
    replace cc_other = _cc_other
    drop _cc_other
}
drop `other_m'
label values cc_other yn
label var cc_other "Chronic condition: Other"

*-----------------------------
* Household composition (baseline 2019; prefer k>j)
*-----------------------------
tempfile comp_j comp_k comp_base

* j
preserve
    use "${p6614}/j_indresp.dta", clear
    keep pidp j_hhtype_dv j_ndepchl_dv
    rename j_hhtype_dv  hhtype_j
    rename j_ndepchl_dv ndep_j

    replace hhtype_j = . if hhtype_j < 0 & !missing(hhtype_j)
    replace ndep_j   = . if ndep_j   < 0 & !missing(ndep_j)

    isid pidp
    save `comp_j', replace
restore

* k
preserve
    use "${p6614}/k_indresp.dta", clear
    keep pidp k_hhtype_dv k_ndepchl_dv
    rename k_hhtype_dv  hhtype_k
    rename k_ndepchl_dv ndep_k

    replace hhtype_k = . if hhtype_k < 0 & !missing(hhtype_k)
    replace ndep_k   = . if ndep_k   < 0 & !missing(ndep_k)

    isid pidp
    save `comp_k', replace
restore

* combine j/k (prefer k > j)
preserve
    use `comp_j', clear
    merge 1:1 pidp using `comp_k', nogen

    gen double base_hhtype = hhtype_k
    replace base_hhtype = hhtype_j if missing(base_hhtype) & !missing(hhtype_j)

    gen double base_ndep = ndep_k
    replace base_ndep = ndep_j if missing(base_ndep) & !missing(ndep_j)

    label var base_hhtype "Baseline hhtype_dv (k>j)"
    label var base_ndep   "Baseline ndepchl_dv (k>j)"

    * (1) Single / Multi-occupancy
    gen byte single_occ = .
    replace single_occ = 1 if inlist(base_hhtype,1,2,3,4,5)
    replace single_occ = 0 if base_hhtype > 0 & !inlist(base_hhtype,1,2,3,4,5)

    label define occ 0 "Multi-occupancy" 1 "Single", replace
    label values single_occ occ
    label var single_occ "Single vs Multi-occupancy (baseline; hhtype_dv)"

    * (2) Children category
    gen byte kids_cat = .
    replace kids_cat = 0 if base_ndep == 0
    replace kids_cat = 1 if inlist(base_ndep,1,2)
    replace kids_cat = 2 if base_ndep >= 3 & !missing(base_ndep)

    label define kidsc 0 "No kids" 1 "1-2 dep kids" 2 ">=3 dep kids", replace
    label values kids_cat kidsc
    label var kids_cat "Dependent children category (baseline; ndepchl_dv)"

    * consistency checks
    assert missing(base_ndep) == missing(kids_cat)
    assert kids_cat==0 if base_ndep==0
    assert kids_cat==1 if inlist(base_ndep,1,2)
    assert kids_cat==2 if base_ndep>=3 & !missing(base_ndep)

    keep pidp base_hhtype base_ndep single_occ kids_cat
    isid pidp
    save `comp_base', replace
restore

* avoid stale values in master if re-running partially
capture drop base_hhtype base_ndep single_occ kids_cat
merge m:1 pidp using `comp_base', keep(master match) nogen

* post-merge checks
count if !missing(base_ndep)
count if !missing(kids_cat)
assert missing(base_ndep) == missing(kids_cat)

*-----------------------------
* Demographics (baseline 2019; prefer k > j)
*-----------------------------
tempfile demo_j demo_k demo_base

* j
preserve
    use "${p6614}/j_indresp.dta", clear
    keep pidp j_sex_dv j_age_dv
    rename j_sex_dv sex_j
    rename j_age_dv age_j
    replace sex_j = . if sex_j < 0 & !missing(sex_j)
    replace age_j = . if age_j < 0 & !missing(age_j)
    isid pidp
    save `demo_j', replace
restore

* k
preserve
    use "${p6614}/k_indresp.dta", clear
    keep pidp k_sex_dv k_age_dv
    rename k_sex_dv sex_k
    rename k_age_dv age_k
    replace sex_k = . if sex_k < 0 & !missing(sex_k)
    replace age_k = . if age_k < 0 & !missing(age_k)
    isid pidp
    save `demo_k', replace
restore

* combine (k > j)
preserve
    use `demo_j', clear
    merge 1:1 pidp using `demo_k', nogen

    gen double base_sex = sex_k
    replace base_sex = sex_j if missing(base_sex) & !missing(sex_j)

    gen double base_age = age_k
    replace base_age = age_j if missing(base_age) & !missing(age_j)

    * (1) Sex
    gen byte sex_bin = .
    replace sex_bin = 1 if base_sex==1
    replace sex_bin = 2 if base_sex==2
    label define sexlbl 1 "Male" 2 "Female", replace
    label values sex_bin sexlbl
    label var sex_bin "Sex (baseline; k>j sex_dv)"

    * (2) Age groups
    gen byte agegrp = .
    replace agegrp = 1 if inrange(base_age,16,29)
    replace agegrp = 2 if inrange(base_age,30,49)
    replace agegrp = 3 if inrange(base_age,50,69)
    replace agegrp = 4 if base_age>=70 & !missing(base_age)

    label define agelbl 1 "16-29" 2 "30-49" 3 "50-69" 4 "70+", replace
    label values agegrp agelbl
    label var agegrp "Age group (baseline; k>j age_dv)"

    keep pidp base_sex base_age sex_bin agegrp
    isid pidp
    save `demo_base', replace
restore

* avoid stale values in master if re-running partially
capture drop base_sex base_age sex_bin agegrp
merge m:1 pidp using `demo_base', keep(master match) nogen
*-----------------------------
* Save BASE
*-----------------------------
keep pidp hidp bip ethn_dv d_ghq_likert d_ghq_case ///
     wgt_ca psu_ca strata_ca ///
     ca_blwork ca_sempderived ca_furlough ca_hours ca_blhours ca_keyworker prework ///
     base_finnow ca_finnow fin_diff_base fin_change ///
     owner_base bedratio_base hsrooms_base2 bedratio_cat hsrooms_cat ///
     covid_symp hs_change cc_resp cc_cardio cc_endo cc_arth cc_other ///
     base_hhtype base_ndep single_occ kids_cat ///
     base_sex base_age sex_bin agegrp

save "${work}/BASE_delta2019_CA_zinv_COVIDWGT_bip.dta", replace
****************************************************
* END STEP 1
****************************************************
