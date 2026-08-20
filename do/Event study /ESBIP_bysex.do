cap mkdir "${out}/ESBIPbySex"
cap mkdir "${work}/ESBIPbySex"

use "${work}/GHQ_longpanel_UKHLS_w1w11_plus_COVID_2020_2021_withIDs_apr_zinv.dta", clear

* outcome: higher = better mental well-being
capture drop ghq_likert_apr_inv
gen double ghq_likert_apr_inv = -ghq_likert_apr

*====================================================
* 0) Sex variable
*====================================================

* If sex_dv is not already in the long file, merge it from xwavedat
capture confirm variable sex_dv
if _rc {
    merge m:1 pidp using "${p6614}/xwavedat.dta", ///
        keepusing(sex_dv) nogen keep(master match)
}

replace sex_dv = . if sex_dv < 0

capture drop female
gen byte female = .
replace female = 0 if sex_dv == 1   // male
replace female = 1 if sex_dv == 2   // female

label define femlbl 0 "Male" 1 "Female", replace
label values female femlbl

drop if missing(female)

*====================================================
* 1) Define BIP and White majority comparison sample
*====================================================

keep if !missing(ethn_dv)

capture drop ethn_str
capture confirm numeric variable ethn_dv

if !_rc {
    capture decode ethn_dv, gen(ethn_str)
    if _rc {
        tostring ethn_dv, gen(ethn_str) usedisplayformat force
    }
}
else {
    gen strL ethn_str = ethn_dv
}

capture drop ethn_low
gen strL ethn_low = lower(strtrim(ethn_str))

capture drop bip
gen byte bip = .

* White British / White majority = 0
replace bip = 0 if strpos(ethn_low, "british/english/scottish/welsh/northern irish") > 0

* BIP = 1
replace bip = 1 if strpos(ethn_low, "bangladeshi") > 0
replace bip = 1 if strpos(ethn_low, "indian") > 0
replace bip = 1 if strpos(ethn_low, "pakistani") > 0

* Keep only White majority and BIP
drop if missing(bip)

label define bip_lbl 0 "White British" 1 "BIP", replace
label values bip bip_lbl

*====================================================
* 2) Keep event-study analysis sample
*====================================================

keep if !missing(pidp, bip, female, ghq_likert_apr_inv)

* pre: UKHLS 2016-2019
* post: COVID waves
keep if (study=="UKHLS" & inrange(endyear, 2016, 2019)) | (study=="COVID")

capture drop evt_cat
gen byte evt_cat = .

replace evt_cat = 1 if study=="UKHLS" & endyear==2016
replace evt_cat = 2 if study=="UKHLS" & endyear==2017
replace evt_cat = 3 if study=="UKHLS" & endyear==2018
replace evt_cat = 4 if study=="UKHLS" & endyear==2019   // baseline

replace evt_cat = 5  if study=="COVID" & waveid=="ca"
replace evt_cat = 6  if study=="COVID" & waveid=="cb"
replace evt_cat = 7  if study=="COVID" & waveid=="cc"
replace evt_cat = 8  if study=="COVID" & waveid=="cd"
replace evt_cat = 9  if study=="COVID" & waveid=="ce"
replace evt_cat = 10 if study=="COVID" & waveid=="cf"
replace evt_cat = 11 if study=="COVID" & waveid=="cg"
replace evt_cat = 12 if study=="COVID" & waveid=="ch"
replace evt_cat = 13 if study=="COVID" & waveid=="ci"

drop if missing(evt_cat)

label define evtlbl ///
    1  "2016" ///
    2  "2017" ///
    3  "2018" ///
    4  "2019 (base)" ///
    5  "2020/04" ///
    6  "2020/05" ///
    7  "2020/06" ///
    8  "2020/07" ///
    9  "2020/09" ///
    10 "2020/11" ///
    11 "2021/01" ///
    12 "2021/03" ///
    13 "2021/09", replace
label values evt_cat evtlbl

* balanced-ish sample: must have 2019 and at least one post-COVID observation
bys pidp: egen has2019 = max(evt_cat==4)
bys pidp: egen haspost = max(inrange(evt_cat,5,13))
keep if has2019==1 & haspost==1
drop has2019 haspost

xtset pidp

* Save the analysis sample before subgroup estimation
tempfile analysis_sample
save `analysis_sample', replace

*====================================================
* Conditional event study by sex
* BIP vs White majority within male and female samples
*====================================================

forvalues s = 0/1 {

    use `analysis_sample', clear
    keep if female == `s'

    if `s' == 0 local sname "male"
    if `s' == 1 local sname "female"

    if `s' == 0 local slabel "Male"
    if `s' == 1 local slabel "Female"

    di "===================================================="
    di "Event study for `slabel': BIP vs White majority"
    di "===================================================="

    * Check subgroup sample size
    tab bip
    tab evt_cat bip

    *----------------------------------------------------
    * Main subgroup event-study model
    *----------------------------------------------------
    reghdfe ghq_likert_apr_inv ib4.evt_cat##i.bip, ///
        absorb(pidp) vce(cluster pidp)

    estimates store ES_bip_`sname'

    * Joint pre-trend test
    test 1.evt_cat#1.bip 2.evt_cat#1.bip 3.evt_cat#1.bip
    scalar pretrend_p_`sname' = r(p)
    display "`slabel' pre-trend p-value = " pretrend_p_`sname'

    *====================================================
    * Export group-specific paths for plotting
    *====================================================

    tempname memhold

    postfile `memhold' int evt str12 period ///
        double est_wm se_wm lb_wm ub_wm ///
        double est_bip se_bip lb_bip ub_bip ///
        using "${work}/ESBIPbySex/esbip_`sname'_plotdata.dta", replace

    * Baseline 2019: both groups normalized to zero
    post `memhold' (4) ("2019") ///
        (0) (0) (0) (0) ///
        (0) (0) (0) (0)

    foreach j in 1 2 3 5 6 7 8 9 10 11 12 13 {

        * White majority path, relative to 2019
        lincom `j'.evt_cat
        local est_wm = r(estimate)
        local se_wm  = r(se)
        local lb_wm  = r(lb)
        local ub_wm  = r(ub)

        * BIP path, relative to 2019
        lincom `j'.evt_cat + `j'.evt_cat#1.bip
        local est_b  = r(estimate)
        local se_b   = r(se)
        local lb_b   = r(lb)
        local ub_b   = r(ub)

        local lab : label evtlbl `j'

        post `memhold' (`j') ("`lab'") ///
            (`est_wm') (`se_wm') (`lb_wm') (`ub_wm') ///
            (`est_b')  (`se_b')  (`lb_b')  (`ub_b')
    }

    postclose `memhold'

    *====================================================
    * Export theta_k coefficients:
    * BIP-WM gap relative to 2019 within sex subgroup
    *====================================================

    estimates restore ES_bip_`sname'

    test 1.evt_cat#1.bip 2.evt_cat#1.bip 3.evt_cat#1.bip
    scalar pretrend_p = r(p)

    tempname memhold3

    postfile `memhold3' str8 sex str20 period double theta pval str3 stars ///
        using "${work}/ESBIPbySex/esbip_`sname'_theta_table.dta", replace

    * Baseline row
    post `memhold3' ("`slabel'") ("2019 (base)") (0) (.) ("")

    foreach j in 1 2 3 5 6 7 8 9 10 11 12 13 {

        lincom `j'.evt_cat#1.bip

        local theta = r(estimate)
        local pval  = r(p)

        local stars ""
        if `pval' < 0.10 local stars "*"
        if `pval' < 0.05 local stars "**"
        if `pval' < 0.01 local stars "***"

        local lab : label evtlbl `j'

        post `memhold3' ("`slabel'") ("`lab'") (`theta') (`pval') ("`stars'")
    }

    * Joint pre-trend row
    post `memhold3' ("`slabel'") ("Joint pre-trend") (.) (pretrend_p) ("")

    postclose `memhold3'

    *====================================================
    * Export CSV files
    *====================================================

    use "${work}/ESBIPbySex/esbip_`sname'_plotdata.dta", clear
    sort evt
    export delimited using "${work}/ESBIPbySex/esbip_`sname'_plotdata.csv", replace

    use "${work}/ESBIPbySex/esbip_`sname'_theta_table.dta", clear

    format theta %9.3f
    format pval %9.3f

    gen str15 theta_display = cond(missing(theta), "", string(theta, "%9.2f") + stars)
    gen str10 p_display     = cond(missing(pval), "", string(pval, "%9.2f"))

    list sex period theta_display p_display, noobs

    export delimited using "${out}/ESBIPbySex/ESbip_`sname'_theta_table.csv", replace
}

*====================================================
* Combined male/female theta table
*====================================================

use "${work}/ESBIPbySex/esbip_male_theta_table.dta", clear
append using "${work}/ESBIPbySex/esbip_female_theta_table.dta"

format theta %9.3f
format pval %9.3f

capture drop theta_display p_display
gen str15 theta_display = cond(missing(theta), "", string(theta, "%9.2f") + stars)
gen str10 p_display     = cond(missing(pval), "", string(pval, "%9.2f"))

list sex period theta_display p_display, noobs

export delimited using "${out}/Event study/ESBIPbySex/ESbip_bysex_theta_table_combined.csv", replace
