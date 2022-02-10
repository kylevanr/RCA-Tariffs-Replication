** Kyle Van Rensselaer
** Paper - Tariffs and Revealed Comparative Advantage 
** Latest Revision: Summer 2021

clear all 
set more off 

//frame change default // I recommend using the default frame, or any empty frame while cleaning the data. 
*** Change this global macro to your own preferred directory before running code
global folderpath "/Users/kylevanr/Documents/Documents/Academics/Academic Miscellany/RCA Tariffs Empirical Paper/Replication_Files_RCA_Tariffs"
cd "${folderpath}"

** Install these packages if not already downloaded
//ssc install xtserial
//ssc install actest

qui do "${folderpath}/do_files/Clean_RCA_Tariffs_Data.do" // This do file returns you to the empty default frame. For analysis, a work frame titled RCA_tariffs is created below.


************************
*** EXPLORE THE DATA ***
************************
frame create RCA_tariffs
frame change RCA_tariffs
use main_dataset

** Summarize the RCA and tariff data by country and altogether
summarize tariffs world_tariffs brca nrca, detail
summarize tariffs world_tariffs brca nrca if(reporter == "Canada"), detail
summarize tariffs world_tariffs brca nrca if(reporter == "Mexico"), detail
summarize tariffs world_tariffs brca nrca if(reporter == "United States"), detail


mean world_tariffs if(nrca >= 0) // Average is 4.677 percent if good has comparative advantage
mean world_tariffs if(nrca < 0) // Average is 5.358 percent if good does not have comparative advantage 
mean world_tariffs if(nrca >= 0) & reporter == "United States" // Average is 2.059 percent if good has comparative advantage
mean world_tariffs if(nrca < 0) & reporter == "United States" // Average is 3.306 percent if good does not have comparative advantage 
mean world_tariffs if(nrca >= 0) & reporter == "Canada" // Average is 3.006 percent if good has comparative advantage
mean world_tariffs if(nrca < 0) & reporter == "Canada" // Average is 3.794 percent if good does not have comparative advantage
mean world_tariffs if(nrca >= 0) & reporter == "Mexico" // Average is 8.820 percent if good has comparative advantage
mean world_tariffs if(nrca < 0) & reporter == "Mexico" // Average is 9.831 percent if good does not have comparative advantage

*** See shares of the sample and average tariff rates by different cuts of the data
foreach var in prod_group sector_reg tech_class {
	foreach tar in tariffs world_tariff {
	tab `var' if `tar' != . & brca != .
	bysort `var': summ `tar' if brca != .
}
}

*** Investigate to what degree tariffs change over time by analyzing deviations 
gen sq_delta = (d.tariffs)^2
by panelid: egen tariff_changes = total(sq_delta)
replace tariff_changes = sqrt(tariff_changes)
summ tariff_changes if brca != . & tariffs != ., d 



*************************************
*** REGRESSIONS AND RELATED TESTS ***
*************************************

*** Run tests for heteroskedasticity and autocorrelation
xtserial world_tariffs brca if unique_world_tariffs == 1 // F stat = 48.81, p = 0., so can reject null of no first-order autocorrelation
xtserial tariffs brca_dyad  // F stat = 2.197, p = 0.1383, so cannot reject null of no first-order autocorrelation
xtserial world_tariffs nrca if unique_world_tariffs == 1 // F stat = , p = 0., so also can reject null of no FO autocorrelation
xtserial tariffs nrca_dyad // F stat = 2.194, p = 0.1386, so cannot reject null of no FO autocorrelation


qui reg world_tariffs c.brca##i.sector_reg i.tech_class nation##year prod_group##nation prod_group##year if unique_world_tariffs == 1
estat hettest // chi2(1) = 8.34e5, p = 0.0000, can reject null of homoskedasticity
qui reg tariffs c.brca_dyad##i.sector_reg i.tech_class nation##year prod_group##nation prod_group##year
estat hettest // chi2(1) = 1.28e6, p = 0.0000, can reject null of homoskedasticity

qui reg world_tariffs c.nrca##i.sector_reg i.tech_class nation##year prod_group##nation prod_group##year if unique_world_tariffs == 1
estat hettest // chi2(1) = 8.17e5, p = 0.0000, can reject null of homoskedasticity
qui reg tariffs c.nrca_dyad##i.sector_reg i.tech_class nation##year prod_group##nation prod_group##year
estat hettest // chi2(1) = 1.31e6, p = 0.0000, can reject null of homoskedasticity


** Run regressions of tariffs on RCA (Balassa and Normalized), clustering SEs by product given heteroskedasticity 
*** use productXcountry, productsXyear, and countryXyear fixed effects

//reg tariffs brca, vce(cluster panelid)
//reg tariffs brca nation##year prod_group##nation prod_group##year, vce(cluster panelid)
//reg tariffs brca i.tech_class nation##year prod_group##nation prod_group##year, vce(cluster panelid)
reg tariffs c.brca##i.sector_reg i.tech_class nation##year prod_group##nation prod_group##year, vce(cluster product)
xtpcse world_tariffs c.brca##i.sector_reg i.tech_class nation##year prod_group##nation prod_group##year if unique_world_tariffs == 1, corr(psar1) hetonly
reg tariffs c.brca_dyad##i.sector_reg i.tech_class nation##year prod_group##nation prod_group##year, vce(cluster panelid)

//reg tariffs nrca, vce(cluster panelid)
//reg tariffs nrca nation##year prod_group##nation prod_group##year, vce(cluster panelid)
//reg tariffs nrca i.tech_class nation##year prod_group##nation prod_group##year, vce(cluster panelid)
reg tariffs c.nrca##i.sector_reg i.tech_class nation##year prod_group##nation prod_group##year, vce(cluster product)
xtpcse world_tariffs c.nrca##i.sector_reg i.tech_class nation##year prod_group##nation prod_group##year if unique_world_tariffs == 1, corr(psar1) hetonly
reg tariffs c.nrca_dyad##i.sector_reg i.tech_class nation##year prod_group##nation prod_group##year, vce(cluster panelid)

/*** Run regressions of tariffs on RCA lagged by one year for plausible exogeneity
reg tariffs brca_lag, vce(cluster panelid)
reg tariffs brca_lag nation##year prod_group##nation prod_group##year, vce(cluster panelid)
reg tariffs c.brca_lag##i.sector nation##year prod_group##nation prod_group##year, vce(cluster panelid)

reg tariffs nrca_lag, vce(cluster panelid)
reg tariffs nrca_lag nation##year prod_group##nation prod_group##year, vce(cluster panelid)
reg tariffs c.nrca_lag##i.sector nation##year prod_group##nation prod_group##year, vce(cluster panelid)
*/

*** Instrumental Variables Approach - requires actual dummy variables for sectors, with agriculture as the omitted baseline
*** per Bellemare et al. (2017), best to use lags to rid explanatory variable of endogeneity when there is serial correlation in the potentially exogenous explanatory variable but no serial correlation in unobserved sources of endogeneity 
*** test for serial correlation in BRCA and NRCA 
actest brca, lags(5) // very small p-value, can reject null of no serial correlation 
actest nrca, lags(5) // very small p-value, can reject null of no serial correlation 
*** test for stationarity in BRCA and NRCA
xtunitroot fisher nrca, dfuller lags(1) demean // test takes too long to complete


ivregress 2sls tariffs i.tech_class nation##year prod_group##nation prod_group##year (brca = brca_lag), vce(cluster panelid) wmatrix(hac)
estat firststage 
ivregress 2sls tariffs i.tech_class nation##year prod_group##nation prod_group##year (nrca = nrca_lag), vce(cluster panelid) wmatrix(hac)
estat firststage

gen raw = 1 if sector_reg == 1
replace raw = 0 if sector_reg != 1
gen intermed = 1 if sector_reg == 2
replace intermed = 0 if sector_reg != 2
gen consum = 1 if sector_reg == 3
replace consum = 0 if sector_reg != 3
gen misc_prod = 1 if sector_reg == 4
replace misc_prod = 0 if sector_reg != 4

gen endo1 = brca*raw
gen endo2 = brca*intermed 
gen endo3 = brca*consum
gen endo4 = brca*misc_prod
gen iv1 = brca_lag*raw
gen iv2 = brca_lag*intermed 
gen iv3 = brca_lag*consum
gen iv4 = brca_lag*misc_prod

gen endo5 = brca_dyad*raw
gen endo6 = brca_dyad*intermed 
gen endo7 = brca_dyad*consum
gen endo8 = brca_dyad*misc_prod
gen iv5 = brca_dyad_lag*raw
gen iv6 = brca_dyad_lag*intermed 
gen iv7 = brca_dyad_lag*consum
gen iv8 = brca_dyad_lag*misc_prod


ivreg2 world_tariffs i.tech_class i.sector_reg nation##year prod_group##nation prod_group##year (brca endo1 endo2 endo3 endo4 = brca_lag iv1 iv2 iv3 iv4) if unique_world_tariffs == 1, gmm2s robust bw(2) savefirst savefprefix(first)
mat list e(first)

ivregress 2sls tariffs i.tech_class i.sector_reg nation##year prod_group##nation prod_group##year (brca_dyad endo5 endo6 endo7 endo8 = brca_dyad_lag iv5 iv6 iv7 iv8), vce(cluster panelid)
estat firststage, all

gen endo9 = nrca*raw
gen endo10 = nrca*intermed 
gen endo11 = nrca*consum
gen endo12 = nrca*misc_prod
gen iv9 = nrca_lag*raw
gen iv10 = nrca_lag*intermed 
gen iv11 = nrca_lag*consum
gen iv12 = nrca_lag*misc_prod

gen endo13 = nrca_dyad*raw
gen endo14 = nrca_dyad*intermed 
gen endo15 = nrca_dyad*consum
gen endo16 = nrca_dyad*misc_prod
gen iv13 = nrca_dyad_lag*raw
gen iv14 = nrca_dyad_lag*intermed 
gen iv15 = nrca_dyad_lag*consum
gen iv16 = nrca_dyad_lag*misc_prod

ivreg2 world_tariffs i.tech_class i.sector_reg nation##year prod_group##nation prod_group##year (nrca endo9 endo10 endo11 endo12 = nrca_lag iv9 iv10 iv11 iv12) if unique_world_tariffs == 1, gmm2s robust bw(2) savefirst savefprefix(first)
mat list e(first)

ivregress 2sls tariffs i.tech_class i.sector_reg nation##year prod_group##nation prod_group##year (nrca_dyad endo13 endo14 endo15 endo16 = nrca_dyad_lag iv13 iv14 iv15 iv16), vce(cluster panelid)
estat firststage, all


/** Lag by two years 
ivregress 2sls tariffs i.tech_class nation##year prod_group##nation prod_group##year (brca = l2.brca), vce(cluster panelid)
estat firststage
ivregress 2sls tariffs i.tech_class nation##year prod_group##nation prod_group##year (nrca = l2.nrca), vce(cluster panelid)
estat firststage


gen iv9 = l2.brca*raw
gen iv10 = l2.brca*intermed 
gen iv11 = l2.brca*consum
gen iv12 = l2.brca*misc_prod


ivregress 2sls tariffs i.tech_class nation##year prod_group##nation prod_group##year (brca endo1 endo2 endo3 endo4 = l2.brca iv9 iv10 iv11 iv12), vce(cluster panelid)
estat firststage, all


gen iv13 = l2.nrca*raw
gen iv14 = l2.nrca*intermed 
gen iv15 = l2.nrca*consum
gen iv16 = l2.nrca*misc_prod

ivregress 2sls tariffs i.tech_class nation##year prod_group##nation prod_group##year (nrca endo5 endo6 endo7 endo8 = l2.nrca iv13 iv14 iv15 iv16), vce(cluster panelid)
estat firststage, all
*/




/*** Scatterplots and Partial Regression plots - aren't very visually descriptive, so cut for revision

*** Format data for visualization
gen logbrca = ln(brca)
gen lognrca = ln(nrca)
gen logtar = ln(tariffs+1)
gen sinhtar = asinh(tariffs)

gen adv_b = logbrca if(brca >= 1)
gen disadv_b = logbrca if (brca < 1)
gen adv_n = nrca if(nrca >= 0)
gen disadv_n = nrca if (nrca < 0)
gen adv_sn = asinh(nrca) if(nrca >= 0)
gen disadv_sn = asinh(nrca) if (nrca < 0)

set scheme s1color
graph set window fontface "Garamond"

*** Graph tariffs vs BRCA
graph twoway (scatter sinhtar disadv_b, mcolor(erose)) (scatter sinhtar adv_b, mcolor(ltblue)) (lfit sinhtar disadv_b, lcolor(sienna) lwidth(0.75) lpattern(longdash)) (lfit sinhtar adv_b, lcolor(navy) lwidth(0.75) lpattern(dash)), xtitle("Log of Balassa RCA Index") ytitle("Log of Tariff Rates") legend(label(1 "Tariffs on Low BRCA") label(2 "Tariffs on High BRCA") label(3 "Fitted Line for Low BRCA") label(4 "Fitted Line for High BRCA")) note("Natural log of BRCA and [tariffs + 1] used for ease of visualization.")

** A greyscale version of this same graph but with local polynomial:
graph twoway (scatter logtar disadv_b, mcolor(gs12)) (scatter logtar adv_b, mcolor(gs9)) (lpoly logtar disadv_b, lcolor(gs6) lwidth(0.75) lpattern(longdash)) (lpoly logtar adv_b, lcolor(black) lwidth(0.75) lpattern(dash)), xtitle("Log of Balassa RCA Index") ytitle("Log of Tariff Rates") legend(label(1 "Tariffs on Low BRCA") label(2 "Tariffs on High BRCA") label(3 "Fitted Local Polynomial for Low BRCA") label(4 "Fitted Local Polynomial for High BRCA")) note("Natural log of BRCA and [tariffs + 1] used for ease of visualization.")

** A greyscale version of tariffs vs NRCA:
graph twoway (scatter sinhtar disadv_sn, mcolor(gs12)) (scatter sinhtar adv_sn, mcolor(gs9)) (lpoly sinhtar disadv_sn, lcolor(gs6) lwidth(0.75) lpattern(longdash)) (lpoly sinhtar adv_sn, lcolor(black) lwidth(0.75) lpattern(dash)), xtitle("Transformed NRCA Index") ytitle("Transformed Tariff Rates") legend(label(1 "Tariffs on Low NRCA") label(2 "Tariffs on High NRCA") label(3 "Fitted Polynomial, Low NRCA") label(4 "Fitted Polynomial, High NRCA")) note("Source: World Bank WITS Database, 2019""Inverse hyperbolic sine transformation applied to NRCA and tariffs for ease of visualization.")

** Look at individual countries:
** United States:

gen adv_us = asinh(nrca) if(nrca >= 0 & reporter == "United States")
gen disadv_us = asinh(nrca) if (nrca < 0 & reporter == "United States")

graph twoway (scatter sinhtar disadv_us, mcolor(gs12)) (scatter sinhtar adv_us, mcolor(gs9)) (lpoly sinhtar disadv_us, lcolor(gs6) lwidth(0.75) lpattern(longdash)) (lfit sinhtar adv_us, lcolor(black) lwidth(0.75) lpattern(dash)), xtitle("Transformed NRCA Index, US") ytitle("Transformed Tariff Rates, US") legend(label(1 "US Tariffs on Low RCA") label(2 "US Tariffs on High RCA") label(3 "Fitted Polynomial, Low RCA") label(4 "Fitted Polynomial, High RCA")) 


** Canada:

gen adv_can = asinh(nrca) if(nrca >= 0 & reporter == "Canada")
gen disadv_can = asinh(nrca) if (nrca < 0 & reporter == "Canada")

graph twoway (scatter sinhtar disadv_can, mcolor(gs12)) (scatter sinhtar adv_can, mcolor(gs9)) (lpoly sinhtar disadv_can, lcolor(gs6) lwidth(0.75) lpattern(longdash)) (lpoly sinhtar adv_can, lcolor(black) lwidth(0.75) lpattern(dash)), xtitle("Transformed NRCA Index, Canada") ytitle("Transformed Tariff Rates, Canada") legend(label(1 "Canadian Tariffs on Low RCA") label(2 "Canadian Tariffs on High RCA") label(3 "Fitted Polynomial, Low RCA") label(4 "Fitted Polynomial, High RCA"))


** Mexico:

gen adv_mex = asinh(nrca) if(nrca >= 0 & reporter == "Mexico")
gen disadv_mex = asinh(nrca) if (nrca < 0 & reporter == "Mexico")

graph twoway (scatter sinhtar disadv_mex, mcolor(gs12)) (scatter sinhtar adv_mex, mcolor(gs9)) (lpoly sinhtar disadv_mex, lcolor(gs6) lwidth(0.75) lpattern(longdash)) (lpoly sinhtar adv_mex, lcolor(black) lwidth(0.75) lpattern(dash)), xtitle("Transformed NRCA Index, Mexico") ytitle("Transformed Tariff Rates, Mexico") legend(label(1 "Mexican Tariffs on Low RCA") label(2 "Mexican Tariffs on High RCA") label(3 "Fitted Polynomial, Low RCA") label(4 "Fitted Polynomial, High RCA"))




** All countries
qui reg tariffs i.tech_class nation##year prod_group##nation prod_group##year, vce(cluster panelid)
predict tarest, xb
gen tarresids = tariffs - tarest
qui reg nrca i.tech_class nation##year prod_group##nation prod_group##year, vce(cluster panelid)
predict rcaest, xb
gen rcaresids = nrca - rcaest


gen tarresids2 = ln(tarresids)
gen rcaresids2 = ln(rcaresids)

correlate tarresids rcaresids // 0.0005
twoway (scatter tarresids rcaresids, mcolor("gs11")) (lpoly tarresids rcaresids, lwidth(0.7) lcolor("black")) if tarresids < 350, ytitle("Residuals for Tariff Rate") xtitle("Residuals for Normalized Revealed Comparative Advantage") legend(label(1 "Residuals") label(2 "Fitted Local Polynomial"))

** USA
qui reg tariffs nation##year prod_group##nation prod_group##year if(reporter == "United States"), vce(cluster panelid)
predict ustarest, xb
gen ustarresids = tariffs - ustarest if(reporter == "United States")
qui reg nrca nation##year prod_group##nation prod_group##year if(reporter == "United States"), vce(cluster panelid)
predict usrcaest, xb
gen usrcaresids = nrca - usrcaest if(reporter == "United States")

correlate ustarresids usrcaresids // -0.0608
twoway (scatter ustarresids usrcaresids, mcolor("gs11")) (lpoly ustarresids usrcaresids, lwidth(0.7) lcolor("black")), ytitle("Residuals for Tariff Rate") xtitle("Residuals for Normalized Revealed Comparative Advantage") legend(label(1 "Residuals, U.S.") label(2 "Fitted Local Polynomial"))

** Canada
xtgls logtar ag min1 lab cap1 cap2 cap3 raw inter consum if(reporter == "Canada"), panels(hetero) corr(psar1) force 
predict cantarest, xb
gen cantarresids = logtar - cantarest if(reporter == "Canada")
xtgls logrca ag min1 lab cap1 cap2 cap3 raw inter consum if(reporter == "Canada"), panels(hetero) corr(psar1) force
predict canrcaest, xb
gen canrcaresids = logrca - canrcaest if(reporter == "Canada")

correlate cantarresids canrcaresids // 0.0185
twoway (scatter cantarresids canrcaresids, mcolor("gs11")) (lpoly cantarresids canrcaresids, lwidth(0.7) lcolor("black")), ytitle("Residuals for Log MFN Tariff Rate") xtitle("Residuals for Log Revealed Comparative Advantage") legend(label(1 "Residuals, Canada") label(2 "Fitted Local Polynomial"))

** Mexico
xtgls logtar ag min1 lab cap1 cap2 cap3 raw inter consum if(reporter == "Mexico"), panels(hetero) corr(psar1) force 
predict mextarest, xb
gen mextarresids = logtar - mextarest if(reporter == "Mexico")
xtgls logrca ag min1 lab cap1 cap2 cap3 raw inter consum if(reporter == "Mexico"), panels(hetero) corr(psar1) force
predict mexrcaest, xb
gen mexrcaresids = logrca - mexrcaest if(reporter == "Mexico")

correlate mextarresids mexrcaresids // 0.0917
twoway (scatter mextarresids mexrcaresids, mcolor("gs11")) (lpoly mextarresids mexrcaresids, lwidth(0.7) lcolor("black")), ytitle("Residuals for Log MFN Tariff Rate") xtitle("Residuals for Log Revealed Comparative Advantage") legend(label(1 "Residuals, Mexico") label(2 "Fitted Local Polynomial"))*/
