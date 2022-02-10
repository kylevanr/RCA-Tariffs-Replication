** Kyle Van Rensselaer
** Empirical Research Paper - Tariffs and Revealed Comparative Advantage 
** Summer 2021

*************************************
*** DATA COMPILATION AND CLEANING ***
*************************************

capture program drop clean_productcode
program define clean_productcode
local vartype: type productcode
di "`vartype'"
if "`vartype'" == "str6" {
gen productcode1 = real(productcode)
replace productcode1 = 999999 if productcode1 == .
drop productcode 
rename productcode1 productcode
}
end

*** Append datasets for US export volume to Canada and Mexico between 1996 and 2020 
foreach nation in usa can mex {
	if "`nation'" == "usa" {
		local nation_cap1 = "USA"
		local nation_cap2 = "CAN"
		local nation_cap3 = "MEX"
	}
	else if "`nation'" == "can" {
		local nation_cap1 = "CAN"
		local nation_cap2 = "USA"
		local nation_cap3 = "MEX"
	}
	else {
		local nation_cap1 = "MEX"
		local nation_cap2 = "USA"
		local nation_cap3 = "CAN"
	}
	frame create `nation'export1
	frame change `nation'export1
	import delimited "${folderpath}/Raw_Data/`nation_cap1'`nation_cap2'19962010.csv"
	clean_productcode
	save "${folderpath}/`nation'exports.dta", replace
	frame create `nation'export2
	frame change `nation'export2
	import delimited "${folderpath}/Raw_Data/`nation_cap1'`nation_cap2'20112020.csv"
	clean_productcode
	append using `nation'exports
	save "${folderpath}/`nation'exports.dta", replace
	frame create `nation'export3
	frame change `nation'export3
	import delimited "${folderpath}/Raw_Data/`nation_cap1'`nation_cap3'19962010.csv"
	clean_productcode
	append using `nation'exports
	save "${folderpath}/`nation'exports.dta", replace
	frame create `nation'export4
	frame change `nation'export4
	import delimited "${folderpath}/Raw_Data/`nation_cap1'`nation_cap3'20112020.csv"
	clean_productcode
	append using `nation'exports
	save "${folderpath}/`nation'exports.dta", replace
}


frame create mainexports
frame change mainexports
use usaexports
append using canexports
append using mexexports

foreach nation in usa can mex {
	foreach num of numlist 1(1)4 {
		frame drop `nation'export`num'
	}
}

sort reportername year partnername productcode
rename reportername reporter
rename partnername partner
rename productcode product 
rename tradevaluein1000usd exportvalue_bilat
label variable exportvalue "Bilateral Export Value in 1000 USD"
egen dyad = group(reporter partner) // 1 is CAN/MEX, 2 is CAN/USA, 3 is MEX/CAN, 4 is MEX/USA, 5 is USA/CAN, 6 is USA/MEX
replace dyad = 1 if dyad == 3
replace dyad = 2 if dyad == 5
replace dyad = 3 if dyad == 4 | dyad == 6
label define dyadlabel 1 "Canada/Mexico" 2 "United States/Canada" 3 "Mexico/United States"
label values dyad dyadlabel
bysort year dyad product: egen exp_market_bilat = total(exportvalue_bilat) // correctly identified
label variable exp_market_bilat "Bilateral Commodity Export Market in 1000 USD"
bysort year dyad: egen bilat_total_exports = total(exportvalue_bilat)
label variable bilat_total_exports "All Bilateral Exports, Value in 1000 USD"
bysort year reporter dyad: egen bilat_exp_market = total(exportvalue_bilat)
label variable bilat_exp_market "Country's Total Exports to Dyadic Partner, Value in 1000 USD"


save "${folderpath}/exports.dta", replace // identifying variables: reporter (str13), year(int), product(double, HS6 code), partner


*** Now import data on total world exports by product code, 1996-2020
frame create world1
frame change world1
import delimited "${folderpath}/Raw_Data/WorldExports20142020.csv"
clean_productcode
save "${folderpath}/worldexports.dta", replace
frame create world2
frame change world2
import delimited "${folderpath}/Raw_Data/WorldExports20052013.csv"
clean_productcode
append using worldexports
save "${folderpath}/worldexports.dta", replace
frame create worldexports
frame change worldexports
import delimited "${folderpath}/Raw_Data/WorldExports19962004.csv"
clean_productcode
append using worldexports
save "${folderpath}/worldexports.dta", replace

frame drop world1
frame drop world2

sort productcode year

collapse (sum) tradevaluein1000usd, by(year productcode productdescription)
sort productcode year
gen nomenclature = "H1"
gen tradeflowname = "Export"
gen tradeflowcode = 6
rename productcode product
rename tradevaluein1000usd total_export_market
label variable total_export_market "Commodity's Total Export Market, Value in 1000 USD"
bysort year: egen world_total_exports = total(total_export_market)
label variable world_total_exports "All World Exports, Value in 1000 USD"

save "${folderpath}/worldexportscollapse.dta", replace



frame change mainexports 

merge m:1 year product using worldexportscollapse
sort reporter product year
drop _merge

*** Import data on countries' exports to the entire world 
frame create worldusa1
frame change worldusa1
import delimited "${folderpath}/Raw_Data/USAWorld19962010.csv"
clean_productcode
save "${folderpath}/exportstoworld.dta", replace
frame create worldusa2
frame change worldusa2
import delimited "${folderpath}/Raw_Data/USAWorld20112020.csv"
clean_productcode
append using exportstoworld
save "${folderpath}/exportstoworld.dta", replace
frame create worldcan1
frame change worldcan1
import delimited "${folderpath}/Raw_Data/CANWorld19962010.csv"
clean_productcode
append using exportstoworld
save "${folderpath}/exportstoworld.dta", replace
frame create worldcan2
frame change worldcan2
import delimited "${folderpath}/Raw_Data/CANWorld20112020.csv"
clean_productcode
append using exportstoworld
save "${folderpath}/exportstoworld.dta", replace
frame create worldmex1
frame change worldmex1
import delimited "${folderpath}/Raw_Data/MEXWorld19962010.csv"
clean_productcode
append using exportstoworld
save "${folderpath}/exportstoworld.dta", replace
frame create worldmex2
frame change worldmex2
import delimited "${folderpath}/Raw_Data/MEXWorld20112020.csv"
clean_productcode
append using exportstoworld

sort reportername year partnername productcode
rename reportername reporter
rename partnername partner
rename productcode product 
rename tradevaluein1000usd world_exports
label variable world_exports "Country Exports to World, Value in 1000 USD"
bysort year reporter: egen country_exp_market = total(world_exports)
label variable country_exp_market "Country's Total Export Market, Value in 1000 USD"
save "${folderpath}/exportstoworld.dta", replace



frame change mainexports
foreach oldframe in worldusa1 worldusa2 worldcan1 worldcan2 worldmex1 worldmex2 {
	frame drop `oldframe'
}

drop if reporter == "" // don't want data for which no country has export data

merge m:1 year product reporter using exportstoworld 
sort product reporter year
drop _merge
save "${folderpath}/exportsfull.dta", replace



frame create tariffs
frame change tariffs

import delimited "${folderpath}/Raw_Data/NAFTATariffs19962020.csv"
drop reporter partner nbrofdomesticpeaks nbrofinternationalpeaks bindingcoverage variance sumofrates sumofsavgrates count_of_savgrates_cases sum_of_squared_rates nbrofavelines nbrofnalines nbroffreelines nbrofdutiablelines nbrline0to5 nbrline5to10 nbrline10to20 nbrline20to50 nbrline50to100 nbrlinemorethan100 sumratebywghttrdvalue sumwghttrdvalue4notnull freeimportsin1000usd dutiableimportsin1000usd specificdutyimportsin1000usd nbroftotallines
rename reportername reporter
rename partnername partner
rename tradeyear year // tariff year and trade year are equivalent 
sort product reporter year partner
drop if reporter == partner

save "${folderpath}/tariffs1996_2020.dta", replace


frame create world_tariffs
frame change world_tariffs

import delimited "${folderpath}/Raw_Data/NAFTAWorldTariffs19962020.csv"
drop selectednomen nativenomen productname reporter partner partnername tradesource dutytype 
rename reportername reporter
rename tariffyear year // tariff year and trade year are equivalent 
foreach var in simpleaverage weightedaverage importsvaluein1000usd {
	rename `var' `var'_world
}

sort product reporter year

save "${folderpath}/worldtariffs1996_2020.dta", replace

frame change tariffs 
merge m:1 year product reporter using worldtariffs1996_2020
sort product reporter year partner
drop _merge

merge 1:1 year product reporter partner using exportsfull
sort product reporter year partner
drop _merge


*** Generate indicator for technology intensity
frame create technology
frame change technology
import excel "${folderpath}/Raw_Data/HS1996 to SITC2 Conversion and Correlation Tables.xls", sheet("STATA Format") firstrow
gen S2_three = substr(S2,1,3)
gen SITC = real(S2_three)
format SITC %03.0f

egen primary_goods = anymatch(SITC), values(001 011 022 025 034 036 041 042 043 044 045 054 057 071 072 074 075 081 091 121 211 212 222 223 232 244 245 246 261 263 268 271 273 274 277 278 281 286 287 289 291 292 322 333 341)
egen resource_goods = anymatch(SITC), values(012 014 048 056 112 122 269 423 634 635 411 511 532 551 681 682 689 023 024 058 061 233 247 424 431 641 282 514 515 592 661 683 684 035 037 046 047 062 073 098 111 248 251 264 265 621 625 628 633 288 323 334 335 516 522 523 531 662 663 664 667 685 686 687 688)
egen lowtech_goods = anymatch(SITC), values(611 612 657 658 846 847 674 675 694 695 895 897 613 651 659 831 848 851 676 677 696 697 898 899 652 654 655 656 842 843 844 845 642 665 666 673 679 691 692 693 699 821 893 894)
egen medtech_goods = anymatch(SITC), values(781 782 513 533 584 585 786 791 723 724 741 742 772 773 885 951 783 784 553 554 591 598 882 711 725 726 743 744 775 793 785 266 267 512 562 572 582 583 653 671 672 678 713 714 721 722 727 728 736 737 745 749 762 763 812 872 873 884)
egen hightech_goods = anymatch(SITC), values(716 718 774 776 874 881 751 752 778 524 759 761 764 771 541 712 792 871)
egen misc_goods = anymatch(SITC), values(351 883 892 896 911 931 941 961 971)

gen test = primary_goods + resource_goods + lowtech_goods + medtech_goods + hightech_goods + misc_goods
gen tech_class = 0 if primary_goods == 1
replace tech_class = 1 if resource_goods == 1
replace tech_class = 2 if lowtech_goods == 1
replace tech_class = 3 if medtech_goods == 1
replace tech_class = 4 if hightech_goods == 1 
replace tech_class = 5 if misc_goods == 1
drop test

label define techlabel 0 "Primary" 1 "Resource-Based Manufactures" 2 "Low-Tech" 3 "Medium-Tech" 4 "High-Tech" 5 "Miscellaneous Transactions"
label values tech_class techlabel
gen product = real(HS96)
keep product SITC tech_class

save "${folderpath}/tech_classif.dta", replace
frame change tariffs


merge m:1 product using tech_classif
sort product reporter year partner
drop _merge


*** Generate indicator for value chain position
frame create value_chain
frame change value_chain
import excel "${folderpath}/Raw_Data/HS1996 to BEC Conversion and Correlation Tables.xls", sheet("STATA Format") firstrow
gen BEC_code = real(BEC)

egen capital = anymatch(BEC_code), values(41 521)
egen intermediate = anymatch(BEC_code), values(111 121 21 22 31 322 42 53)
egen consumer = anymatch(BEC_code), values(112 122 321 522 61 62 63)

gen test = capital + intermediate + consumer
gen value_chain = 0 if capital == 1
replace value_chain = 1 if intermediate == 1
replace value_chain = 2 if consumer == 1
replace value_chain = 3 if capital != 1 & intermediate != 1 & consumer != 1
drop test

label define valuelabel 0 "Capital/Raw Goods" 1 "Intermediate Goods" 2 "Consumer Goods" 3 "Miscellaneous Value Chain"
label values value_chain valuelabel
gen product = real(HS96)
keep product BEC_code value_chain

save "${folderpath}/value_chain.dta", replace
frame change tariffs


merge m:1 product using value_chain
sort product reporter year partner
drop _merge

*** Generate RCA values for world trade
gen e_ij = world_exports
gen e_i = country_exp_market
gen e_j = total_export_market
gen e_total = world_total_exports
gen brca = (e_ij/e_j)/(e_i/e_total)
gen srca = (brca - 1)/(brca + 1) // symmetric RCA, wih 0 being comparatively neutral point 
gen arca = (e_ij/e_i) - (e_j/e_total) // additive RCA, with 0 being comparatively neutral point
gen nrca = (e_ij / e_total) - ((e_j*e_i)/(e_total^2)) // normalized RCA with 0 being comparatively neutral 



*** generate RCA values for dyadic trade
gen dyad_e_ij = exportvalue_bilat
gen dyad_e_i = bilat_exp_market 
gen dyad_e_j = exp_market_bilat
gen dyad_e_total = bilat_total_exports
gen brca_dyad = (dyad_e_ij/dyad_e_j)/(dyad_e_i/dyad_e_total)
gen srca_dyad = (brca_dyad - 1)/(brca_dyad + 1) // symmetric RCA, wih 0 being comparatively neutral point 
gen arca_dyad = (dyad_e_ij/dyad_e_i) - (dyad_e_j/dyad_e_total) // additive RCA, with 0 being comparatively neutral point
gen nrca_dyad = (dyad_e_ij / dyad_e_total) - ((dyad_e_j*dyad_e_i)/(dyad_e_total^2)) // normalized RCA with 0 being comparatively neutral 

***scale up nrca to improve interpretability
replace nrca = nrca*10000
replace nrca_dyad = nrca_dyad*10000

replace partner = "WTO" if partner == ""
egen panelid = group(reporter product partner)
egen cluster2 = group(reporter product)
drop if productname == "" & brca == .
xtset panelid year
gen brca_lag = l.brca
gen brca_dyad_lag = l.brca_dyad
gen nrca_lag = l.nrca
gen nrca_dyad_lag = l.nrca_dyad
rename simpleaverage tariffs
rename simpleaverage_world world_tariffs

*** For world tariffs, repeated values for the same country-product-year due to multiple dyadic partners - generate indicator for unique world tariffs
gen unique_world_tariffs = 0
bysort reporter product year: gen countnonmissing = sum(!missing(world_tariffs)) if !missing(world_tariffs)
replace unique_world_tariffs = 1 if countnonmissing == 1
drop countnonmissing



** Generate country factor variable
gen nation = 1 if(reporter == "United States")
replace nation = 2 if(reporter == "Canada")
replace nation = 3 if(reporter == "Mexico")
label define nationlabel 1 "United States" 2 "Canada" 3 "Mexico"
label values nation nationlabel


*** Generate indicator for high-level product classification code (2-digit HS 1996 level)
gen prod_group = 0 if product >= 0 & product < 60000
replace prod_group = 1 if product >= 60000 & product < 160000
replace prod_group = 2 if product >= 160000 & product < 250000
replace prod_group = 3 if product >= 250000 & product < 270000
replace prod_group = 4 if product >= 270000 & product < 280000
replace prod_group = 5 if product >= 280000 & product < 390000
replace prod_group = 6 if product >= 390000 & product < 410000
replace prod_group = 7 if product >= 410000 & product < 440000
replace prod_group = 8 if product >= 440000 & product < 500000
replace prod_group = 9 if product >= 500000 & product < 640000
replace prod_group = 10 if product >= 640000 & product < 680000
replace prod_group = 11 if product >= 680000 & product < 720000
replace prod_group = 12 if product >= 720000 & product < 840000
replace prod_group = 13 if product >= 840000 & product < 860000
replace prod_group = 14 if product >= 860000 & product < 900000
replace prod_group = 15 if product >= 900000 & product < 1000000
label define productgroup 0 "Animal" 1 "Vegetables" 2 "Food" 3 "Minerals" 4 "Fuels" 5 "Chemicals" 6 "Plastic or Rubber" 7 "Hides and Skins" 8 "Wood" 9 "Textiles and Clothing" 10 "Footwear" 11 "Stone and Glass" 12 "Metals" 13 "Machinery and Electrical" 14 "Transportation" 15 "Miscellaneous"
label values prod_group productgroup

*** Generate indicator for sectors (consumer goods, agricultural goods, industrial goods, miscellaneous)
gen sector = 0 if prod_group == 0 | prod_group == 1 | prod_group == 2
replace sector = 1 if prod_group == 9 | prod_group == 10 
replace sector = 2 if prod_group == 3 | prod_group == 4 | prod_group == 5 | prod_group == 6 | prod_group == 7 | prod_group == 8 | prod_group == 11 | prod_group == 12 | prod_group == 13 | prod_group == 14
replace sector = 3 if prod_group == 15
label define sectorlabel 0 "Agricultural" 1 "Consumer" 2 "Industrial" 3 "Miscellaneous"
label values sector sectorlabel

*** Generate a sector label for interacting with RCA in regressions, following value_chain but separating agric.
gen sector_reg = 0 if sector == 0
replace sector_reg = 1 if value_chain == 0 & sector != 0
replace sector_reg = 2 if value_chain == 1 & sector != 0
replace sector_reg = 3 if value_chain == 2 & sector != 0
replace sector_reg = 4 if value_chain == 3 & sector != 0
label define sectorreglabel 0 "Agricultural" 1 "Raw Non-Agricultural" 2 "Intermediate Non-Agricultural" 3 "Consumer Non-Agricultural" 4 "Miscellaneous, Non-Agricultural"
label values sector_reg sectorreglabel


save "${folderpath}/main_dataset.dta", replace

frame change default
foreach framename in mainexports tariffs world_tariffs technology value_chain worldexports {
	frame drop `framename'
}
