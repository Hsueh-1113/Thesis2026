****************************************************
* framework:
* April 2020 respondent population as target
* - use CA weight for all linked historical observations
* - month adjustment based on pre-Covid data, weighted by CA weight
* - standardize across all waves, then invert
****************************************************

use "${work}/GHQ_longpanel_UKHLS_w1w11_plus_COVID_2020_2021_withIDs.dta", clear

*-----------------------------
* 0) Build time_label (ensure it exists)
*-----------------------------
capture drop time_label
gen str10 time_label = ""
replace time_label = string(endyear) if study=="UKHLS" & inrange(endyear,2009,2019)
replace time_label = upper(waveid)   if study=="COVID"
keep if time_label != ""

*-----------------------------
* 1) Merge CA design vars + CA weight onto ALL waves for same pidp
*    Target population = April 2020 Covid respondents
*-----------------------------
tempfile ca_design
preserve
    use "${p8644}/ca_indresp_w.dta", clear
    keep pidp ca_betaindin_xw psu strata
    rename ca_betaindin_xw wgt_ca
    rename psu psu_ca
    rename strata strata_ca
    drop if missing(wgt_ca) | wgt_ca<=0
    save `ca_design', replace
restore

* keep(match): keep all April 2020 Covid respondents only
merge m:1 pidp using `ca_design', keep(match) nogen

*-----------------------------
* 2) Clean GHQ negative codes -> missing
*-----------------------------
capture drop ghq_likert0 ghq_case0
gen double ghq_likert0 = ghq_likert
replace ghq_likert0 = . if ghq_likert0 < 0

gen double ghq_case0 = ghq_case
replace ghq_case0 = . if ghq_case0 < 0

*-----------------------------
* 3) Compute month deltas (April equivalents) using pre-Covid UKHLS,
*    but weighted by April 2020 Covid weights
*-----------------------------
preserve
    keep if study=="UKHLS" & endyear<=2019 & inrange(endmonth,1,12)
    keep if !missing(wgt_ca) & (!missing(ghq_likert0) | !missing(ghq_case0))

    collapse (mean) m_likert=ghq_likert0 m_case=ghq_case0 [pw=wgt_ca], by(endmonth)

    quietly summarize m_likert if endmonth==4, meanonly
    scalar apr_l = r(mean)
    quietly summarize m_case if endmonth==4, meanonly
    scalar apr_c = r(mean)

    gen double delta_likert = m_likert - apr_l
    gen double delta_case   = m_case   - apr_c

    keep endmonth delta_likert delta_case
    tempfile deltas_ca
    save `deltas_ca', replace
restore

merge m:1 endmonth using `deltas_ca', nogen

*-----------------------------
* 4) Apply April-equivalent adjustment to ALL observations
*-----------------------------
capture drop ghq_likert_apr ghq_case_apr
gen double ghq_likert_apr = ghq_likert0
replace ghq_likert_apr = ghq_likert_apr - delta_likert ///
    if !missing(ghq_likert_apr, delta_likert)

gen double ghq_case_apr = ghq_case0
replace ghq_case_apr = ghq_case_apr - delta_case ///
    if !missing(ghq_case_apr, delta_case)

*-----------------------------
* 5) Standardize across ALL waves, weighted by CA weight
*    then invert so lower = worse well-being in paper's convention
*-----------------------------
capture drop wx wx2
capture drop ghq_likert_stdinv ghq_case_stdinv

* ---- likert ----
gen double wx  = wgt_ca * ghq_likert_apr
gen double wx2 = wgt_ca * (ghq_likert_apr^2)

quietly summarize wgt_ca if !missing(wgt_ca, ghq_likert_apr), meanonly
scalar sw  = r(sum)
quietly summarize wx if !missing(wgt_ca, ghq_likert_apr), meanonly
scalar swx = r(sum)
quietly summarize wx2 if !missing(wgt_ca, ghq_likert_apr), meanonly
scalar swx2 = r(sum)

scalar mu_l  = swx/sw
scalar var_l = swx2/sw - mu_l^2
scalar sd_l  = sqrt(var_l)

gen double ghq_likert_stdinv = .
replace ghq_likert_stdinv = -((ghq_likert_apr - mu_l) / sd_l) ///
    if sd_l>0 & !missing(ghq_likert_apr)

drop wx wx2

* ---- case ----
gen double wx  = wgt_ca * ghq_case_apr
gen double wx2 = wgt_ca * (ghq_case_apr^2)

quietly summarize wgt_ca if !missing(wgt_ca, ghq_case_apr), meanonly
scalar sw  = r(sum)
quietly summarize wx if !missing(wgt_ca, ghq_case_apr), meanonly
scalar swx = r(sum)
quietly summarize wx2 if !missing(wgt_ca, ghq_case_apr), meanonly
scalar swx2 = r(sum)

scalar mu_c  = swx/sw
scalar var_c = swx2/sw - mu_c^2
scalar sd_c  = sqrt(var_c)

gen double ghq_case_stdinv = .
replace ghq_case_stdinv = -((ghq_case_apr - mu_c) / sd_c) ///
    if sd_c>0 & !missing(ghq_case_apr)

drop wx wx2
drop delta_likert delta_case ghq_likert0 ghq_case0

*-----------------------------
* 6) Save replication-style file for April-2020 respondent population
*-----------------------------
save "${work}/GHQ_longpanel_CArespondents_aprEq_stdinv_CAWGT.dta", replace

****************************************************
* OPTIONAL: if you want the change-analysis sample
* (2019 baseline + April 2020 response)
****************************************************
use "${work}/GHQ_longpanel_CArespondents_aprEq_stdinv_CAWGT.dta", clear

bys pidp: egen has2019 = max(time_label=="2019")
bys pidp: egen hasCA   = max(time_label=="CA")

keep if has2019==1 & hasCA==1
drop has2019 hasCA

save "${work}/GHQ_longpanel_CArespondents_bal2019CA_aprEq_stdinv_CAWGT.dta", replace
****************************************************
* END
****************************************************
