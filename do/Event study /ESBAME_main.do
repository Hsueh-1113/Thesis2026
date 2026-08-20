use "${work}/GHQ_longpanel_UKHLS_w1w11_plus_COVID_2020_2021_withIDs_apr_zinv.dta", clear

* outcome: higher = better mental well-being
capture drop ghq_likert_apr_inv
gen double ghq_likert_apr_inv = -ghq_likert_apr

*----------------------------------------
* BAME
*----------------------------------------
capture confirm numeric variable ethn_dv
if _rc==0 {
    decode ethn_dv, gen(ethn_str)
}
else {
    gen strL ethn_str = ethn_dv
}

gen strL ethn_low = lower(strtrim(ethn_str))

gen byte bame = .
replace bame = 0 if strpos(ethn_low, "british/english/scottish/welsh/northern irish") > 0
replace bame = 1 if !missing(ethn_dv) & bame != 0
drop if missing(bame)

*----------------------------------------
* keep analysis sample
*----------------------------------------
keep if !missing(pidp, bame, ghq_likert_apr_inv)

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

* balanced-ish sample: must have 2019 and at least one post-COVID obs
bys pidp: egen has2019 = max(evt_cat==4)
bys pidp: egen haspost = max(inrange(evt_cat,5,13))
keep if has2019==1 & haspost==1
drop has2019 haspost

xtset pidp

*====================================================
* MAIN SPEC: unweighted FE event-study
*====================================================
reghdfe ghq_likert_apr_inv ib4.evt_cat##i.bame, ///
    absorb(pidp) vce(cluster pidp)

estimates store ES_main

* pre-trend test
test 1.bame#1.evt_cat 1.bame#2.evt_cat 1.bame#3.evt_cat
scalar pretrend_p_main = r(p)
display "Main spec pre-trend p-value = " pretrend_p_main
*====================================================
* Export coefficients for plotting
*====================================================
tempname memhold
postfile `memhold' int evt str12 period ///
    double est_nonbame se_nonbame lb_nonbame ub_nonbame ///
    double est_bame    se_bame    lb_bame    ub_bame ///
    using "${work}/esbame_plotdata.dta", replace

* 先把 baseline 2019 放進去：兩組都定義為 0
post `memhold' (4) ("2019") ///
    (0) (0) (0) (0) ///
    (0) (0) (0) (0)

* 其餘各期
foreach j in 1 2 3 5 6 7 8 9 10 11 12 13 {

    * ---------- non-BAME ----------
    lincom `j'.evt_cat
    local est_nb = r(estimate)
    local se_nb  = r(se)
    local lb_nb  = r(lb)
    local ub_nb  = r(ub)

    * ---------- BAME ----------
    lincom `j'.evt_cat + `j'.evt_cat#1.bame
    local est_b  = r(estimate)
    local se_b   = r(se)
    local lb_b   = r(lb)
    local ub_b   = r(ub)

    * label
    local lab : label evtlbl `j'

    post `memhold' (`j') ("`lab'") ///
        (`est_nb') (`se_nb') (`lb_nb') (`ub_nb') ///
        (`est_b')  (`se_b')  (`lb_b')  (`ub_b')
}

postclose `memhold'

preserve
    use "${work}/esbame_plotdata.dta", clear
    sort evt
    export delimited using "${work}/esbame_plotdata.csv", replace
    list, noobs
restore

*====================================================
* Supplementary table data: theta_k coefficients
*====================================================

estimates restore ES_main

* joint pre-trend test
test 1.bame#1.evt_cat 1.bame#2.evt_cat 1.bame#3.evt_cat
scalar pretrend_p = r(p)

tempname memhold3
postfile `memhold3' str20 period double theta pval str3 stars ///
    using "${work}/esbame_theta_table.dta", replace

* baseline row
post `memhold3' ("2019 (base)") (0) (.) ("")

* pre + post periods
foreach j in 1 2 3 5 6 7 8 9 10 11 12 13 {
    lincom `j'.evt_cat#1.bame
    
    local theta = r(estimate)
    local pval  = r(p)

    local stars ""
    if `pval' < 0.10 local stars "*"
    if `pval' < 0.05 local stars "**"
    if `pval' < 0.01 local stars "***"

    local lab : label evtlbl `j'
    post `memhold3' ("`lab'") (`theta') (`pval') ("`stars'")
}

* joint pre-trend row
post `memhold3' ("Joint pre-trend") (.) (pretrend_p) ("")

postclose `memhold3'

use "${work}/esbame_theta_table.dta", clear

format theta %9.3f
format pval %9.3f

gen str15 theta_display = cond(missing(theta), "", string(theta, "%9.2f") + stars)
gen str10 p_display     = cond(missing(pval), "", string(pval, "%9.2f"))

list period theta_display p_display, noobs

export delimited using "${out}/Event study/ESbame_theta_table.csv", replace
