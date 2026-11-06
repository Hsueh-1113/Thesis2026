clear all
set maxvar 32767

* set up the path 
global p6614 "/Users/lishixue/Documents/Master thesis/Statafile/in/ukhls"
global p8644 "/Users/lishixue/Documents/Master thesis/Statafile/in/stata13_se"
global work  "/Users/lishixue/Documents/Master thesis/Statafile/work"
global out "/Users/lishixue/Documents/Master thesis/Statafile/Thesis2026/out"
tempfile panel
save `panel', emptyok replace


*============================================================
* A) UKHLS main survey: wave1~wave11  (a~k)
*    Adjust：if endmonth 0 or >12 → missing；use intdatm_dv to cover
*============================================================
local ukhls_waves "a b c d e f g h i j k"
local wnum = 1

foreach w of local ukhls_waves {

    di "=== UKHLS wave `wnum' (`w') ==="
    use "${p6614}/`w'_indresp.dta", clear

    gen byte wave = `wnum'
    gen str1 waveid = "`w'"
    gen str6 study = "UKHLS"

    gen int  endyear  = .
    gen byte endmonth = .
    gen double ghq_likert = .
    gen double ghq_case   = .

    * ---- endyear: use intdaty_dv only ----
    capture confirm variable `w'_intdaty_dv
    if !_rc replace endyear = `w'_intdaty_dv

    * ---- endmonth: use intdatm_dv only ----
    capture confirm variable `w'_intdatm_dv
    if !_rc replace endmonth = `w'_intdatm_dv

    * ---- clear invalid month values ----
    replace endmonth = . if endmonth < 1 | endmonth > 12

    * ---- GHQ (derived variables) ----
    capture confirm variable `w'_scghq1_dv
    if !_rc replace ghq_likert = `w'_scghq1_dv

    capture confirm variable `w'_scghq2_dv
    if !_rc replace ghq_case = `w'_scghq2_dv

    keep pidp study wave waveid endyear endmonth ghq_likert ghq_case

    * missing（UKHLS -1/-2/-7/-8…）
    replace endyear    = . if endyear    < 0
	replace endmonth   = . if endmonth   < 1 | endmonth > 12
    replace ghq_likert = . if ghq_likert < 0
    replace ghq_case   = . if ghq_case   < 0

    * ---- wave10(j) and wave11(k) ----
    if "`w'"=="j" keep if inrange(endyear, 2018, 2019)
    if "`w'"=="k" keep if endyear == 2019

    append using `panel'
    save `panel', replace

    local ++wnum
}


*============================================================
* B) COVID-19 Study (8644): 2020 (ca~cf) + 2021 (cg~ci)
*    Adjust：ca fixed 2020/04（not rely on surveyend）
*============================================================
local covid_waves "ca cb cc cd ce cf cg ch ci"

foreach cw of local covid_waves {

    capture confirm file "${p8644}/`cw'_indresp_w.dta"
    if _rc {
        di as txt "Skip (file not found): ${p8644}/`cw'_indresp_w.dta"
        continue
    }

    di "=== COVID `cw' (web) ==="
    use "${p8644}/`cw'_indresp_w.dta", clear

    gen str6 study = "COVID"
    gen byte wave  = .
    gen str2 waveid = "`cw'"

    gen int  endyear  = .
    gen byte endmonth = .
    gen double ghq_likert = .
    gen double ghq_case   = .

    * GHQ
    capture confirm variable `cw'_scghq1_dv
    if !_rc replace ghq_likert = `cw'_scghq1_dv

    capture confirm variable `cw'_scghq2_dv
    if !_rc replace ghq_case = `cw'_scghq2_dv

    * ---- appoint：ca fixed 2020/04 ----
    if "`cw'"=="ca" {
        replace endyear  = 2020
        replace endmonth = 4
    }
    else {
        capture confirm variable `cw'_surveyend
        if !_rc {
            capture confirm numeric variable `cw'_surveyend
            if !_rc {
                gen double _d = dofc(`cw'_surveyend)
                replace endyear  = year(_d)
                replace endmonth = month(_d)
                drop _d
            }
            else {
                gen double _dt = clock(`cw'_surveyend, "YMDhms")
                replace endyear  = year(dofc(_dt))  if _dt < .
                replace endmonth = month(dofc(_dt)) if _dt < .
                drop _dt
            }
        }

        * fixed if still missing
        replace endyear = 2020 if missing(endyear) & inlist("`cw'","cb","cc","cd","ce","cf")
        replace endyear = 2021 if missing(endyear) & inlist("`cw'","cg","ch","ci")

        replace endmonth = 5  if missing(endmonth) & "`cw'"=="cb"
        replace endmonth = 6  if missing(endmonth) & "`cw'"=="cc"
        replace endmonth = 7  if missing(endmonth) & "`cw'"=="cd"
        replace endmonth = 9  if missing(endmonth) & "`cw'"=="ce"
        replace endmonth = 11 if missing(endmonth) & "`cw'"=="cf"
        replace endmonth = 1  if missing(endmonth) & "`cw'"=="cg"
        replace endmonth = 3  if missing(endmonth) & "`cw'"=="ch"
        replace endmonth = 9  if missing(endmonth) & "`cw'"=="ci"
    }

    keep pidp study wave waveid endyear endmonth ghq_likert ghq_case

    replace endyear    = . if endyear    < 0
    replace endmonth   = . if endmonth   < 1 | endmonth > 12
    replace ghq_likert = . if ghq_likert < 0
    replace ghq_case   = . if ghq_case   < 0

    append using `panel'
    save `panel', replace
}

*============================================================
* C) finalize long panel + DE-DUP UKHLS by pidp-year
*    Goal: UKHLS -> max 1 obs per pidp×endyear (keep LAST month)
*          COVID -> keep all waves
*============================================================
use `panel', clear
sort pidp endyear endmonth study waveid

* --- keep only sensible year/month for ordering (do not drop COVID; just prep order var) ---
gen byte m_order = endmonth
replace m_order = 0 if missing(m_order)

* Mark last observation within pidp-year for UKHLS (by month; missing month treated as earliest)
bys pidp endyear (m_order): gen byte last_ukhls_in_year = (_n==_N) ///
    if study=="UKHLS" & !missing(endyear)

* Keep: all COVID + last UKHLS per pidp-year
keep if (study=="COVID") | (study=="UKHLS" & last_ukhls_in_year==1)

drop m_order last_ukhls_in_year

* check: after de-dup, UKHLS should have no pidp-year duplicates
preserve
keep if study=="UKHLS" & !missing(endyear)
duplicates tag pidp endyear, gen(dup)
tab dup
drop dup
restore

* check
tab study
tab endyear study
summ ghq_case ghq_likert

*============================================================
* D) merge xwavedat time-invariant variables
*============================================================
merge m:1 pidp using "${p6614}/xwavedat.dta", ///
    keepusing(bornuk_dv ethn_dv ethn_dv_source) ///
    gen(_m_xw)

tab _m_xw
drop _m_xw

replace bornuk_dv = . if bornuk_dv < 0
replace ethn_dv   = . if ethn_dv   < 0

gen byte ukborn_flag = (bornuk_dv==1) if !missing(bornuk_dv)
label define ukb 0 "Not UK-born" 1 "UK-born"
label values ukborn_flag ukb

* save
save "${work}/GHQ_longpanel_UKHLS_w1w11_plus_COVID_2020_2021_withIDs.dta", replace
tab bornuk_dv
tab ethn_dv
