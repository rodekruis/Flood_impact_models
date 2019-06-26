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

I downloaded the historical rainfall data from 2000 till now by running a Python script. The downloaded data consisted of historical rainfall in mm per day per raster of Uganda. To answer the research question (which is formulated on district-level), I obtained the mean historical rainfall in mm per day per district of Uganda (instead of per raster). 

### Load in desinventar dataset: 

I downloaded the desinventar dataset freely from [here](https://www.desinventar.net/DesInventar/download_base.jsp?countrycode=uga). 

### Load in CRA dataset: 

I downloaded the CRA dataset freely from [here](https://dashboard.510.global/#!/community_risk).

