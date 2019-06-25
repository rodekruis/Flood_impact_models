# Impact data analysis Uganda:  

For my internship assignment, I helped 510 with making a statistical model that could predict the impact of floods in Uganda (part of the Impact Based Forecasting process). 

By explaining my R-code, I will explain all the steps I have taken to master this project (every paragraph in the read me file refers to a paragraph in my R-code). Also I will explain why I have made certain decisions, the results, and some recommendations of steps that have to be undertaken to improve upon the predictions. 

## Research question: 

The research question was as followed: *“How accurate can we predict the impact of future floods at district-level based on historical data (i.e. the impact of historical floods and the amount of rainfall of the historical floods) and the Community Risk Assessment data?”*

## Required datasets: 

To answer the research question I needed to obtain the following three datasets: 
1.	**Desinventar dataset**:  This dataset shows several variables which indicate the impact of  historical floods in Uganda. To give you an idea; there were impact-variables related to people (i.e. amount of deaths), impact-variables related to houses (i.e. amount of destroyed houses), impact-variables related to infrastructure (i.e. amount of roads affected) and impact-variables related to economic (i.e. amount of crops destroyed). To see a description of all the variables, click [here](https://www.desinventar.net/effects.html).
2.	**GloFAS dataset**: this dataset shows information about the intensity of the historical floods based on weather forecasts.  
3.	**Community Risk Assessment (CRA) dataset**: this dataset shows several variables which indicate the vulnerability of a district (i.e. the distance a district from a major hospital, the percentage of unemployed people in a district etc.).

The Desinventar dataset and the CRA dataset were open source and could therefore be downloaded easily from the web. However, I experienced some difficulties with obtaining the GloFAS dataset: the GloFAS data was not open source and it appears that there were some time-consuming steps which had to be performed before I could obtain the dataset. After discussing this with 510 we decided that, regarding my internship time, it would be better to use an alternative to the GloFAS data for now, namely historical rainfall data. 

4.	**Rainfall dataset**  (as replacement for GloFAS dataset): this dataset consists of historical rainfall in mm per day per raster of Uganda.

## Explanation R-code: 

### Load in rainfall dataset:  

I downloaded the historical rainfall data from 2000 till now by running a Python script. The downloaded data consists of historical rainfall in mm per day per raster of Uganda. To answer the research question (which is formulated on district-level), I obtained the mean historical rainfall in mm per day per district of Uganda (instead of per raster). 

### Load in Desinventar dataset: 

I have downloaded the Desinventar dataset freely from [here](https://www.desinventar.net/DesInventar/download_base.jsp?countrycode=uga). 

### Load in CRA dataset: 

I have downloaded the CRA dataset freely from [here](https://dashboard.510.global/#!/community_risk). 

### Prepare the rainfall dataset for merging: 

To merge the rainfall dataset with the other two datasets I had taken the following steps:  
- Rainfall data has a column with ID numbers, I have renamed the column ‘district’ and changed the ID numbers to the corresponding  uppercase district names. 
- In the rainfall data a date has the following form ‘chirps.v2.0.2000.01.01’, I have deleted the  ‘chirps.v2.0.’-part and made the dates as class ‘as.Date’ in instead of class ‘numeric’. 
- The rainfall data has the dates in the columns and the districtnames in the rows, but I have transposed this forms (dates in rows and districts in columns). Afterwards, I reshaped the wide format to a long format. So now each entry is equal to the mean rainfall in a certain district on a certain date (from 2000 till now).
- I added 9 extra rainfall predictors/columns which might be informative for the later analyses, namely: 
	- The mean rainfall of one day before 
	- The mean rainfall of two days before 
	- The mean rainfall of three days before 
	- The mean rainfall of four days before 
	- The mean rainfall of five days before 
	- The cumulative mean rainfall of the day itself and one day before 
	- The cumulative mean rainfall of the day itself and two days before 
	- The cumulative mean rainfall of the day itself and three days before 
	- The cumulative mean rainfall of the day itself and four days before 

<i></i>   | Actual: no impact (0) | Actual: impact (1) 
--- | --- | ---
**Predicted: no impact (0)** | 12 | 9
**Predicted: impact (1)** | 29 | 66
