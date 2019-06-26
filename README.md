# Impact data analysis Uganda:  

This project is based on creating statistical models that are able to predict the impact of future floods in Uganda (part of the Impact Based Forecasting process). 

In this readme file, I will discuss the following: 
1. Research question 
2. Required datasets
3. Explanation R-script 
	- Load in rainfall dataset
	- Load in desinventar dataset 
	- Load in CRA dataset 
	- Prepare rainfall dataset for merging 
	- Prepare desinventar dataset for merging 
	- Prepare CRA dataset for merging 
	- Merge the three datasets 
	- Aggregate floods
	- Rename and define variables
	- Prepare dataset
	- Examine dataset 
	- Lasso logistic regression 
	- Support vector machine (with radial basis kernel)
	- Random forest 
	- Stepwise logistic regression 
4. Results 
5. Future improvements
6. Presentation 

## 1. Research question: 

The research question of this project was defined as followed: *“How accurate can we predict the impact of future floods at district-level based on historical data (i.e. the impact of historical floods and the amount of rainfall on the dates of the historical floods) and the Community Risk Assessment data?”*

## 2. Required datasets: 

To answer the research question I needed to obtain the following three datasets: 
1.	**Desinventar dataset**:  This dataset shows several variables which indicate the impact of  historical floods in Uganda. To give you an idea; there were impact-variables related to people (i.e. amount of deaths), impact-variables related to houses (i.e. amount of destroyed houses), impact-variables related to infrastructure (i.e. amount of roads affected) and impact-variables related to economics (i.e. amount of crops destroyed). For a more elaborate description of all the variables, click [here](https://www.desinventar.net/effects.html).  
2.	**GloFAS dataset**: this dataset shows information about the intensity of the historical floods based on weather indicators.   
3.	**Community Risk Assessment (CRA) dataset**: this dataset shows several variables which indicate the vulnerability of a district (i.e. the distance a district from a major hospital or the percentage of unemployed people in a district).

The desinventar dataset and the CRA dataset were open source and could therefore be downloaded easily from the web. However, I experienced some difficulties with obtaining the GloFAS dataset: the GloFAS data was not open source and it appears that there were some time-consuming steps which had to be performed before I could obtain the data. After discussing this with 510 we decided that, regarding my internship time, it would be better to use an alternative to the GloFAS data for now, namely historical rainfall data. 

4.	**Rainfall dataset**  (as replacement for GloFAS dataset): this dataset consists of historical rainfall (from 2000 until now) in mm per day per raster of Uganda.

![alt text](https://github.com/rodekruis/statistical_floodimpact_uganda/raw/master/datasets.png)

## 3. Explanation R-script: 

In this paragraph, I will give a step-by-step explanation of my R-script. In the meantime, I will give some arguments to explain why I made certain decisions.

### Load in rainfall dataset:  

I downloaded the historical rainfall data from 2000 till now by running a Python script. The downloaded data consisted of historical rainfall in mm per day per raster of Uganda. To answer the research question (which was formulated on district-level), I obtained the mean historical rainfall in mm per day per district of Uganda (instead of per raster). 

### Load in desinventar dataset: 

I downloaded the desinventar dataset freely from [here](https://www.desinventar.net/DesInventar/download_base.jsp?countrycode=uga). 

### Load in CRA dataset: 

I downloaded the CRA dataset freely from [here](https://dashboard.510.global/#!/community_risk).

### Prepare rainfall dataset for merging: 

Before I could merge the rainfall dataset with the other two datasets I had taken the following steps:  
- The rainfall data had a column with ID numbers, I have renamed this column ‘district’ and changed the ID numbers to the corresponding  uppercase district names. 
- In the rainfall data a date was written down in the following form ‘chirps.v2.0.2000.01.01’, I have deleted the  ‘chirps.v2.0.’-part and made the dates of class ‘as.Date’ instead of class ‘numeric’. 
- In the rainfall data the dates were displayed in the columns and the districtnames in the rows. I have transposed this the other way around (i.e. dates were displayed in rows and districts in columns). Afterwards, I reshaped the wide format to a long format, so that each entry was equal to the mean rainfall in a certain district on a certain date (from 2000 till now).
- I have added 9 extra rainfall columns which might be informative predictors in the later analyses, namely: 
	- The mean rainfall of one day before 
	- The mean rainfall of two days before 
	- The mean rainfall of three days before 
	- The mean rainfall of four days before 
	- The mean rainfall of five days before 
	- The cumulative mean rainfall of the day itself and of one day before 
	- The cumulative mean rainfall of the day itself and of two days before 
	- The cumulative mean rainfall of the day itself and of three days before 
	- The cumulative mean rainfall of the day itself and of four days before 

 ### Prepare desinventar dataset for merging: 

Before I could merge the desinventar dataset with the other two datasets I had taken the following steps:  
- I have renamed the column with the (already uppercase) district-names (i.e. admin_level_0_name) ‘district’. 
- The desinventar dataset consisted of impact data of historical floods and impact data of historical droughts. I have selected only the rows that were flood-related (as my project focusses on historical flood) 
- The desinventar dataset consisted of some impact data of historical floods that occurred before the year 2000. I have selected only the rows of the historical floods that occurred from 2000 onwards (as my project focusses only on those historical floods).  
- The desinventar dataset consisted of three columns which represented respectively the year, month and day of the flood, I have added one extra column that represented the date of the flood (combination of the three columns) and have made those dates of class ‘as.Date’. 
- Some reported dates of floods were not recognized ‘as.Date’ as the day or month of the flood was not given (i.e. ‘00’) and therefore those dates received a NA value. As I needed the dates of the historical floods (because otherwise I couldn’t merge the historical floods to the historical rainfall), I filled in the ‘00’-days and/or months with the day and/or month for which the mean rainfall was highest in the corresponding district. I am of course not sure if those filled in dates are correctly. However, I think this option is better than simply removing all the floods with a ‘00’ day and/or month (as we retained more data now).  

### Prepare CRA dataset for merging: 

Before I could merge the CRA dataset with the other two datasets I have taken the following steps:  
- I have renamed the column with the district-names (i.e. name) ‘district’ and have made all the district-names uppercase. 
- I have made all the numeric variables of class ‘numeric’ since they were of class ‘factor’. 

### Merge the three datasets: 

The three datasets were now in such a format that they had at least one common column: 
- Desinventar dataset had a column named ‘date’ and a column named ‘district’ 
- Rainfall dataset had a column named ‘date’ and a column named ‘district’  
- CRA dataset had a column named ‘district’

Therefore, I was able to merge the rainfall dataset to the desinventar dataset by the common columns named ‘date’ and ‘district’. Subsequently, I have merged the CRA dataset to this by the common column called ‘district’. 

So eventually, I had one ‘final’ dataset (hereinafter referred to as dataset) were each entry was equal to a reported historical flood (in a specific district on a specific date) and for each reported flood several impact-variables of the flood were given (dependent variables), several rainfall-variables of the day and days before the flood were given (independent variable) and several CRA-variables of the district were the flood occurred were given (independent variables). 

### Rename and define variables: 

To get a more structured and understandable dataset, I have renamed and defined all the variables in the following way:  
- Variables starting with **GEN** represent general variables (i.e. the pcode, districtname and date of the historical floods).  
- Variables staring with **DI** represent the impact variables from the desinventar dataset.  
	- Variables starting with **DI_people** are impact variables related to people (i.e. amount of deaths, injured etc.) 
	- Variables starting with **DI_houses** are impact variables related to houses (i.e. amount of houses destroyed and houses damaged etc.) 
	- Variables starting with **DI_economic** are impact variables related to economics (i.e. amount of damaged crops, amount of lost cattle etc.) 
	- Variables starting with **DI_infra** are impact variables related to infrastructure (i.e. amount of damaged roads, amount of damaged hospitals etc.) 
- Variables starting with **RAIN** represent the rainfall variable (and the created rainfall variables, i.e. the cumulative ones) from the rainfall dataset. 
- Variables starting with **CRA** represent the CRA variables from the CRA dataset.  
	- Variables starting with **CRA_hazard** are CRA variables related to hazard exposure (i.e. flood exposure, violent incidents last year etc.) 
 	- Variables starting with **CRA_vulnerability** are CRA variables related to vulnerability (i.e. poverty incidence, % literacy etc.) 
	- Variables starting with **CRA_coping** are CRA variables related to coping capacity (i.e. % with mobile access, travel time to nearest city etc.) 
	- Variables starting with **CRA_general** are CRA variables that represent the overall hazard, vulnerability, coping capacity and risk scores + some remaining CRA variables that are not part of the risk framework but still relevant (i.e. average elevation, number of displaced persons etc.)

Before I renamed and defined all the variables, I removed all the (from origin) CRA variables ending on ‘0.10’ from the dataset. The reason for this was that it appeared that those variables were a kind of duplicate of the variables not ending on ‘0.10’. The only difference was that the ones ending on ‘0.10’ were scaled variables while the ones not ending on ‘0.10’ were unscaled variables. I removed the scaled ones (ending on ‘0.10’, as I will scale the variables later on by myself together with all the other (not CRA) variables. It's of course unnecessary work to define all those scaled variables when I already know that I am going to remove them anyway. 

