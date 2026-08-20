use "${work}/GHQ_longpanel_UKHLS_w1w11_plus_COVID_2020_2021_withIDs.dta", clear

* treat negative as missing (as you did in python)
gen double ghq_likert0 = ghq_likert
replace ghq_likert0 = . if ghq_likert0 < 0
gen double ghq_case0   = ghq_case
replace ghq_case0   = . if ghq_case0   < 0

*-----------------------------
* 1) compute month deltas using UKHLS pre-2020 (<=2019)
*-----------------------------
preserve
    keep if upper(study)=="UKHLS" & endyear<=2019 & inrange(endmonth,1,12)
    keep if !missing(wgt, ghq_likert0) | !missing(wgt, ghq_case0)

    collapse (mean) m_likert=ghq_likert0 m_case=ghq_case0 [pw=wgt], by(endmonth)

    quietly summarize m_likert if endmonth==4, meanonly
    scalar apr_l = r(mean)
    quietly summarize m_case if endmonth==4, meanonly
    scalar apr_c = r(mean)

    gen double delta_likert = m_likert - apr_l
    gen double delta_case   = m_case   - apr_c

    keep endmonth delta_likert delta_case
    tempfile deltas
    save `deltas', replace
restore

merge m:1 endmonth using `deltas', nogen

*-----------------------------
* 2) apply April-equivalent adjustment
*-----------------------------

gen double ghq_likert_apr = ghq_likert0
replace ghq_likert_apr = ghq_likert_apr - delta_likert if !missing(ghq_likert_apr, delta_likert)

gen double ghq_case_apr = ghq_case0
replace ghq_case_apr = ghq_case_apr - delta_case if !missing(ghq_case_apr, delta_case)

*-----------------------------
* 3) use 2019 UKHLS as the fixed reference distribution
*    then standardize ALL waves to that reference
*-----------------------------

* ---- likert: 2019 UKHLS reference ----
preserve
    keep if upper(study)=="UKHLS" & endyear==2019
    keep if !missing(wgt, ghq_likert_apr)

    gen double w   = wgt
    gen double wx  = w*ghq_likert_apr
    gen double wx2 = w*(ghq_likert_apr^2)

    quietly summarize w, meanonly
    scalar sw  = r(sum)
    quietly summarize wx, meanonly
    scalar swx = r(sum)
    quietly summarize wx2, meanonly
    scalar swx2 = r(sum)

    scalar mu_l  = swx/sw
    scalar var_l = swx2/sw - mu_l^2
    scalar sd_l  = sqrt(var_l)
restore

gen double ghq_likert_apr_zinv = .
replace ghq_likert_apr_zinv = -(ghq_likert_apr - mu_l)/sd_l if sd_l>0 & !missing(ghq_likert_apr)

* ---- case: 2019 UKHLS reference ----
preserve
    keep if upper(study)=="UKHLS" & endyear==2019
    keep if !missing(wgt, ghq_case_apr)

    gen double w   = wgt
    gen double wx  = w*ghq_case_apr
    gen double wx2 = w*(ghq_case_apr^2)

    quietly summarize w, meanonly
    scalar sw  = r(sum)
    quietly summarize wx, meanonly
    scalar swx = r(sum)
    quietly summarize wx2, meanonly
    scalar swx2 = r(sum)

    scalar mu_c  = swx/sw
    scalar var_c = swx2/sw - mu_c^2
    scalar sd_c  = sqrt(var_c)
restore

gen double ghq_case_apr_zinv = .
replace ghq_case_apr_zinv = -(ghq_case_apr - mu_c)/sd_c if sd_c>0 & !missing(ghq_case_apr)

drop delta_likert delta_case ghq_likert0 ghq_case0

* save a new analysis-ready file
save "${work}/GHQ_longpanel_UKHLS_w1w11_plus_COVID_2020_2021_withIDs_apr_zinv.dta", replace
