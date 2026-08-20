use "${work}/GHQ_longpanel_UKHLS_w1w11_plus_COVID_2020_2021_withIDs.dta", clear
keep if !missing(ukborn_flag)

* month
capture drop ym 
gen int ym = ym(endyear, endmonth)
format ym %tm

* time label
capture drop time_label
gen str10 time_label = ""
replace time_label = string(endyear) if study=="UKHLS" & inrange(endyear,2009,2019)
replace time_label = upper(waveid)   if study=="COVID"
keep if time_label != ""

*------------------------------------------------------------
* Weight + PSU + Strata
*------------------------------------------------------------
capture drop wgt
capture drop psu_dv
capture drop strata_dv
gen double wgt = .
gen long  psu_dv = .
gen long  strata_dv = .

* UKHLS: wave a uses a_indscus_xw
foreach w in a {

    local wgtvar "a_indscus_xw"
    local stratavar "a_strata"
    local psuvar    "a_psu"

    merge m:1 pidp using "${p6614}/`w'_indresp.dta", ///
        keepusing(`wgtvar' `stratavar' `psuvar') nogen

    replace wgt       = `wgtvar'    if study=="UKHLS" & waveid=="`w'"
    replace strata_dv = `stratavar' if study=="UKHLS" & waveid=="`w'"
    replace psu_dv    = `psuvar'    if study=="UKHLS" & waveid=="`w'"

    drop `wgtvar' `stratavar' `psuvar'
}

* UKHLS: wave b-e use *_indscub_xw
foreach w in b c d e {

    local wgtvar "`w'_indscub_xw"
    local stratavar "`w'_strata"
    local psuvar    "`w'_psu"

    merge m:1 pidp using "${p6614}/`w'_indresp.dta", ///
        keepusing(`wgtvar' `stratavar' `psuvar') nogen

    replace wgt       = `wgtvar'    if study=="UKHLS" & waveid=="`w'"
    replace strata_dv = `stratavar' if study=="UKHLS" & waveid=="`w'"
    replace psu_dv    = `psuvar'    if study=="UKHLS" & waveid=="`w'"

    drop `wgtvar' `stratavar' `psuvar'
}

* UKHLS: wave f-k use *_indscui_xw
foreach w in f g h i j k {

    local wgtvar "`w'_indscui_xw"
    local stratavar "`w'_strata"
    local psuvar    "`w'_psu"

    merge m:1 pidp using "${p6614}/`w'_indresp.dta", ///
        keepusing(`wgtvar' `stratavar' `psuvar') nogen

    replace wgt       = `wgtvar'    if study=="UKHLS" & waveid=="`w'"
    replace strata_dv = `stratavar' if study=="UKHLS" & waveid=="`w'"
    replace psu_dv    = `psuvar'    if study=="UKHLS" & waveid=="`w'"

    drop `wgtvar' `stratavar' `psuvar'
}

* COVID: cw_betaindin_xw（web-only），design vars: strata / psu
foreach cw in ca cb cc cd ce cf cg ch ci {

    local wgtvar "`cw'_betaindin_xw"
    local stratavar "strata"
    local psuvar    "psu"

    merge m:1 pidp using "${p8644}/`cw'_indresp_w.dta", ///
        keepusing(`wgtvar' `stratavar' `psuvar') nogen

    replace wgt       = `wgtvar'    if study=="COVID" & waveid=="`cw'"
    replace strata_dv = `stratavar' if study=="COVID" & waveid=="`cw'"
    replace psu_dv    = `psuvar'    if study=="COVID" & waveid=="`cw'"

    drop `wgtvar' `stratavar' `psuvar'
}


* clean
drop if missing(wgt) | wgt<=0
drop if missing(psu_dv) | missing(strata_dv)
save "${work}/GHQ_longpanel_UKHLS_w1w11_plus_COVID_2020_2021_withIDs.dta", replace
