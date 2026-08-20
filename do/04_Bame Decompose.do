use "${work}/BASE_delta2019_CA_zinv_COVIDWGT.dta", clear

capture drop ca_hours_clean ca_blhours_clean hours_reduced furlough ///
             emp_change keyworker selfemp_only

gen double ca_hours_clean = ca_hours
replace ca_hours_clean = . if ca_hours_clean < 0

gen double ca_blhours_clean = ca_blhours
replace ca_blhours_clean = . if ca_blhours_clean < 0

gen byte hours_reduced = .
replace hours_reduced = (ca_hours_clean + 1 < ca_blhours_clean) ///
    if ca_blhours_clean>0 & !missing(ca_hours_clean, ca_blhours_clean)

gen byte furlough = .
replace furlough = (ca_furlough==1) if !missing(ca_furlough)

* emp_change:
* 1 = No change  (includes prework==0)
* 2 = Reduction
* 3 = Job loss
gen byte emp_change = .
replace emp_change = 3 if prework==1 & ca_sempderived==4
replace emp_change = 2 if prework==1 & inlist(ca_sempderived,1,2,3) ///
    & (furlough==1 | hours_reduced==1)
replace emp_change = 1 if prework==0
replace emp_change = 1 if prework==1 & inlist(ca_sempderived,1,2,3) ///
    & ((furlough==0 | missing(furlough)) & (hours_reduced==0 | missing(hours_reduced)))

label define empchg 1 "No change" 2 "Reduction" 3 "Job loss", replace
label values emp_change empchg

* keyworker:
* 1 only if prework==1 & stable employment & key worker
* 0 otherwise (including prework==0, reduction, job loss)
gen byte keyworker = .
replace keyworker = 1 if prework==1 & emp_change==1 & ca_keyworker==1
replace keyworker = 0 if prework==1 & emp_change==1 & ca_keyworker==2
replace keyworker = 0 if prework==0
replace keyworker = 0 if prework==1 & inlist(emp_change,2,3)
label define keyw 0 "No" 1 "Yes", replace
label values keyworker keyw

* selfemp_only:
* 1 only if prework==1 & self-employed only
* 0 otherwise
gen byte selfemp_only = .
replace selfemp_only = 1 if prework==1 & ca_blwork==2
replace selfemp_only = 0 if prework==1 & inlist(ca_blwork,1,3)
replace selfemp_only = 0 if prework==0
label define selfemp 0 "No" 1 "Yes", replace
label values selfemp_only selfemp




* 2) decomposition-ready dummies
* employment
gen byte emp_red  = (emp_change==2) if !missing(emp_change)
gen byte emp_loss = (emp_change==3) if !missing(emp_change)

gen byte key_yes = (keyworker==1) if !missing(keyworker)
replace key_yes = 0 if missing(key_yes) & !missing(emp_change)

gen byte selfemp_yes = (selfemp_only==1) if !missing(selfemp_only)
replace selfemp_yes = 0 if missing(selfemp_yes) & !missing(emp_change)


* financial
gen byte fin_base_yes = (fin_diff_base==1) if !missing(fin_diff_base)

gen byte fin_better = (fin_change==1) if !missing(fin_change)
gen byte fin_worse  = (fin_change==3) if !missing(fin_change)

* housing: continuous + square
gen double bedratio_sq = bedratio_base^2 if !missing(bedratio_base)
gen double rooms_sq    = hsrooms_base2^2 if !missing(hsrooms_base2)

* health
foreach v in covid_symp cc_resp cc_cardio cc_endo cc_arth cc_other {
    replace `v' = . if `v' < 0
}

* household composition: continuous version
capture drop kids_sq single_kids single_kids_sq

gen double kids_sq = base_ndep^2 if !missing(base_ndep)

gen double single_kids = .
replace single_kids = single_occ * base_ndep ///
    if !missing(single_occ, base_ndep)

gen double single_kids_sq = .
replace single_kids_sq = single_occ * kids_sq ///
    if !missing(single_occ, kids_sq)

* demographics
gen byte female = (sex_bin==2) if !missing(sex_bin)

gen byte age16_29 = (agegrp==1) if !missing(agegrp)
gen byte age30_49 = (agegrp==2) if !missing(agegrp)
gen byte age50_69 = (agegrp==3) if !missing(agegrp)
* agegrp==4 (70+) is omitted base

capture drop sample_c1 miss_c1
egen miss_c1 = rowmiss( ///
    d_ghq_likert bame ///
    emp_red emp_loss key_yes selfemp_yes ///
    fin_base_yes fin_better fin_worse ///
    bedratio_base bedratio_sq hsrooms_base2 rooms_sq ///
    covid_symp cc_resp cc_cardio cc_endo cc_arth cc_other ///
    single_occ base_ndep kids_sq single_kids single_kids_sq ///
    female age16_29 age30_49 age50_69 ///
    wgt_ca psu_ca strata_ca )
gen byte sample_c1 = (miss_c1==0)
keep if sample_c1==1

count
tab bame

svyset psu_ca [pweight=wgt_ca], strata(strata_ca) singleunit(scaled)


* Model 1
svy: regress d_ghq_likert ///
    i.bame ///
    emp_red emp_loss key_yes selfemp_yes ///
    fin_base_yes fin_better fin_worse ///
    c.bedratio_base c.bedratio_sq c.hsrooms_base2 c.rooms_sq ///
    covid_symp cc_resp cc_cardio cc_endo cc_arth cc_other ///
    single_occ c.base_ndep c.kids_sq c.single_kids c.single_kids_sq ///
    female age16_29 age30_49 age50_69


* Model 2
svy, subpop(if bame==1): regress d_ghq_likert ///
    emp_red emp_loss key_yes selfemp_yes ///
    fin_base_yes fin_better fin_worse ///
    c.bedratio_base c.bedratio_sq c.hsrooms_base2 c.rooms_sq ///
    covid_symp cc_resp cc_cardio cc_endo cc_arth cc_other ///
    single_occ c.base_ndep c.kids_sq c.single_kids c.single_kids_sq ///
    female age16_29 age30_49 age50_69

svy, subpop(if bame==0): regress d_ghq_likert ///
    emp_red emp_loss key_yes selfemp_yes ///
    fin_base_yes fin_better fin_worse ///
    c.bedratio_base c.bedratio_sq c.hsrooms_base2 c.rooms_sq ///
    covid_symp cc_resp cc_cardio cc_endo cc_arth cc_other ///
    single_occ c.base_ndep c.kids_sq c.single_kids c.single_kids_sq ///
    female age16_29 age30_49 age50_69


cap which oaxaca
if _rc ssc install oaxaca

oaxaca d_ghq_likert ///
    emp_red emp_loss key_yes selfemp_yes ///
    fin_base_yes fin_better fin_worse ///
    bedratio_base bedratio_sq hsrooms_base2 rooms_sq ///
    covid_symp cc_resp cc_cardio cc_endo cc_arth cc_other ///
    single_occ base_ndep kids_sq single_kids single_kids_sq ///
    female age16_29 age30_49 age50_69 ///
    [pw=wgt_ca], ///
    by(bame) pooled detail vce(cluster psu_ca)

* matrix list e(b)
* local cn : colfullnames e(b)
* display "`cn'


lincom _b[overall:difference]
lincom _b[overall:explained]
lincom _b[overall:unexplained]

****** explained
* employment + financial
lincom ///
    _b[explained:emp_red] + ///
    _b[explained:emp_loss] + ///
    _b[explained:key_yes] + ///
    _b[explained:selfemp_yes] + ///
    _b[explained:fin_base_yes] + ///
    _b[explained:fin_better] + ///
    _b[explained:fin_worse]

* Housing
lincom ///
    _b[explained:bedratio_base] + ///
    _b[explained:bedratio_sq] + ///
    _b[explained:hsrooms_base2] + ///
    _b[explained:rooms_sq]
	
* Household
lincom ///
    _b[explained:single_occ] + ///
    _b[explained:base_ndep] + ///
    _b[explained:kids_sq] + ///
    _b[explained:single_kids] + ///
    _b[explained:single_kids_sq] 


* health factors
lincom ///
    _b[explained:covid_symp] + ///
    _b[explained:cc_resp] + ///
    _b[explained:cc_cardio] + ///
    _b[explained:cc_endo] + ///
    _b[explained:cc_arth] + ///
    _b[explained:cc_other]


* sex
lincom _b[explained:female]

* age
lincom ///
    _b[explained:age16_29] + ///
    _b[explained:age30_49] + ///
    _b[explained:age50_69]



**** Unexplained
* employment + financial
lincom ///
    _b[unexplained:emp_red] + ///
    _b[unexplained:emp_loss] + ///
    _b[unexplained:key_yes] + ///
    _b[unexplained:selfemp_yes] + ///
    _b[unexplained:fin_base_yes] + ///
    _b[unexplained:fin_better] + ///
    _b[unexplained:fin_worse]

* housing 
lincom ///
    _b[unexplained:bedratio_base] + ///
    _b[unexplained:bedratio_sq] + ///
    _b[unexplained:hsrooms_base2] + ///
    _b[unexplained:rooms_sq] 

* Household
lincom ///
    _b[unexplained:single_occ] + ///
    _b[unexplained:base_ndep] + ///
    _b[unexplained:kids_sq] + ///
    _b[unexplained:single_kids] + ///
    _b[unexplained:single_kids_sq]


* health 
lincom ///
    _b[unexplained:covid_symp] + ///
    _b[unexplained:cc_resp] + ///
    _b[unexplained:cc_cardio] + ///
    _b[unexplained:cc_endo] + ///
    _b[unexplained:cc_arth] + ///
    _b[unexplained:cc_other]

* sex
lincom _b[unexplained:female]

* age 
lincom ///
    _b[unexplained:age16_29] + ///
    _b[unexplained:age30_49] + ///
    _b[unexplained:age50_69]

* constant
lincom _b[unexplained:_cons]


* Non-Bame price
oaxaca d_ghq_likert ///
    emp_red emp_loss key_yes selfemp_yes ///
    fin_base_yes fin_better fin_worse ///
    bedratio_base bedratio_sq hsrooms_base2 rooms_sq ///
    covid_symp cc_resp cc_cardio cc_endo cc_arth cc_other ///
    single_occ base_ndep kids_sq single_kids single_kids_sq ///
    female age16_29 age30_49 age50_69 ///
    [pw=wgt_ca], ///
    by(bame) weight(1) detail vce(cluster psu_ca)




lincom _b[overall:difference]
lincom _b[overall:explained]
lincom _b[overall:unexplained]

****** explained
* employment + financial
lincom ///
    _b[explained:emp_red] + ///
    _b[explained:emp_loss] + ///
    _b[explained:key_yes] + ///
    _b[explained:selfemp_yes] + ///
    _b[explained:fin_base_yes] + ///
    _b[explained:fin_better] + ///
    _b[explained:fin_worse]

* Housing 
lincom ///
    _b[explained:bedratio_base] + ///
    _b[explained:bedratio_sq] + ///
    _b[explained:hsrooms_base2] + ///
    _b[explained:rooms_sq] 
	
* Household
lincom ///
    _b[explained:single_occ] + ///
    _b[explained:base_ndep] + ///
    _b[explained:kids_sq] + ///
    _b[explained:single_kids] + ///
    _b[explained:single_kids_sq]

* health factors
lincom ///
    _b[explained:covid_symp] + ///
    _b[explained:cc_resp] + ///
    _b[explained:cc_cardio] + ///
    _b[explained:cc_endo] + ///
    _b[explained:cc_arth] + ///
    _b[explained:cc_other]


* sex
lincom _b[explained:female]

* age
lincom ///
    _b[explained:age16_29] + ///
    _b[explained:age30_49] + ///
    _b[explained:age50_69]

**** Unexplained
* employment + financial
lincom ///
    _b[unexplained:emp_red] + ///
    _b[unexplained:emp_loss] + ///
    _b[unexplained:key_yes] + ///
    _b[unexplained:selfemp_yes] + ///
    _b[unexplained:fin_base_yes] + ///
    _b[unexplained:fin_better] + ///
    _b[unexplained:fin_worse]

* housing
lincom ///
    _b[unexplained:bedratio_base] + ///
    _b[unexplained:bedratio_sq] + ///
    _b[unexplained:hsrooms_base2] + ///
    _b[unexplained:rooms_sq] 
	
* Household
lincom ///
    _b[unexplained:single_occ] + ///
    _b[unexplained:base_ndep] + ///
    _b[unexplained:kids_sq] + ///
    _b[unexplained:single_kids] + ///
    _b[unexplained:single_kids_sq]


* health 
lincom ///
    _b[unexplained:covid_symp] + ///
    _b[unexplained:cc_resp] + ///
    _b[unexplained:cc_cardio] + ///
    _b[unexplained:cc_endo] + ///
    _b[unexplained:cc_arth] + ///
    _b[unexplained:cc_other]

* sex
lincom _b[unexplained:female]

* age 
lincom ///
    _b[unexplained:age16_29] + ///
    _b[unexplained:age30_49] + ///
    _b[unexplained:age50_69]

****************** Experimental run **************************
******** only housing conditions
oaxaca d_ghq_likert ///
    bedratio_base bedratio_sq hsrooms_base2 rooms_sq ///
    [pw=wgt_ca], ///
    by(bame) pooled detail vce(cluster psu_ca)

	
lincom _b[overall:difference]
lincom _b[overall:explained]
lincom _b[overall:unexplained]



****** explained and unexplained housing 
* Housing 
lincom ///
    _b[explained:bedratio_base] + ///
    _b[explained:bedratio_sq] + ///
    _b[explained:hsrooms_base2] + ///
    _b[explained:rooms_sq] 
	
lincom ///
    _b[unexplained:bedratio_base] + ///
    _b[unexplained:bedratio_sq] + ///
    _b[unexplained:hsrooms_base2] + ///
    _b[unexplained:rooms_sq] 
	
	
	
	
	
******* housing + household composition + age + sex +
oaxaca d_ghq_likert ///
	bedratio_base bedratio_sq hsrooms_base2 rooms_sq ///
	single_occ base_ndep kids_sq single_kids single_kids_sq ///
    female age16_29 age30_49 age50_69 ///
    [pw=wgt_ca], ///
    by(bame) pooled detail vce(cluster psu_ca)

	
lincom _b[overall:difference]
lincom _b[overall:explained]
lincom _b[overall:unexplained]


* Housing
lincom ///
    _b[explained:bedratio_base] + ///
    _b[explained:bedratio_sq] + ///
    _b[explained:hsrooms_base2] + ///
    _b[explained:rooms_sq] 

* Household
lincom ///
    _b[explained:single_occ] + ///
    _b[explained:base_ndep] + ///
    _b[explained:kids_sq] + ///
    _b[explained:single_kids] + ///
    _b[explained:single_kids_sq]	
	
* sex
lincom _b[explained:female]

* age
lincom ///
    _b[explained:age16_29] + ///
    _b[explained:age30_49] + ///
    _b[explained:age50_69]
	
**Unexplained
* Housing
lincom ///
    _b[unexplained:bedratio_base] + ///
    _b[unexplained:bedratio_sq] + ///
    _b[unexplained:hsrooms_base2] + ///
    _b[unexplained:rooms_sq] 

* Household
lincom ///
    _b[unexplained:single_occ] + ///
    _b[unexplained:base_ndep] + ///
    _b[unexplained:kids_sq] + ///
    _b[unexplained:single_kids] + ///
    _b[unexplained:single_kids_sq]

* sex
lincom _b[unexplained:female]

* age 
lincom ///
    _b[unexplained:age16_29] + ///
    _b[unexplained:age30_49] + ///
    _b[unexplained:age50_69]	
	
	

******** Excluding Housing conditions

oaxaca d_ghq_likert ///
    emp_red emp_loss key_yes selfemp_yes ///
    fin_base_yes fin_better fin_worse ///
    covid_symp cc_resp cc_cardio cc_endo cc_arth cc_other ///
    single_occ base_ndep kids_sq single_kids single_kids_sq ///
    female age16_29 age30_49 age50_69 ///
    [pw=wgt_ca], ///
    by(bame) pooled detail vce(cluster psu_ca)

* matrix list e(b)
* local cn : colfullnames e(b)
* display "`cn'


lincom _b[overall:difference]
lincom _b[overall:explained]
lincom _b[overall:unexplained]

****** explained
* employment + financial
lincom ///
    _b[explained:emp_red] + ///
    _b[explained:emp_loss] + ///
    _b[explained:key_yes] + ///
    _b[explained:selfemp_yes] + ///
    _b[explained:fin_base_yes] + ///
    _b[explained:fin_better] + ///
    _b[explained:fin_worse]
	
* Household
lincom ///
    _b[explained:single_occ] + ///
    _b[explained:base_ndep] + ///
    _b[explained:kids_sq] + ///
    _b[explained:single_kids] + ///
    _b[explained:single_kids_sq] 


* health factors
lincom ///
    _b[explained:covid_symp] + ///
    _b[explained:cc_resp] + ///
    _b[explained:cc_cardio] + ///
    _b[explained:cc_endo] + ///
    _b[explained:cc_arth] + ///
    _b[explained:cc_other]


* sex
lincom _b[explained:female]

* age
lincom ///
    _b[explained:age16_29] + ///
    _b[explained:age30_49] + ///
    _b[explained:age50_69]



**** Unexplained
* employment + financial
lincom ///
    _b[unexplained:emp_red] + ///
    _b[unexplained:emp_loss] + ///
    _b[unexplained:key_yes] + ///
    _b[unexplained:selfemp_yes] + ///
    _b[unexplained:fin_base_yes] + ///
    _b[unexplained:fin_better] + ///
    _b[unexplained:fin_worse]

* Household
lincom ///
    _b[unexplained:single_occ] + ///
    _b[unexplained:base_ndep] + ///
    _b[unexplained:kids_sq] + ///
    _b[unexplained:single_kids] + ///
    _b[unexplained:single_kids_sq]


* health 
lincom ///
    _b[unexplained:covid_symp] + ///
    _b[unexplained:cc_resp] + ///
    _b[unexplained:cc_cardio] + ///
    _b[unexplained:cc_endo] + ///
    _b[unexplained:cc_arth] + ///
    _b[unexplained:cc_other]

* sex
lincom _b[unexplained:female]

* age 
lincom ///
    _b[unexplained:age16_29] + ///
    _b[unexplained:age30_49] + ///
    _b[unexplained:age50_69]

* constant
lincom _b[unexplained:_cons]
