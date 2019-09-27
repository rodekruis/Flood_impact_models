# Impact data analysis Uganda:  

(This readme should be updated. This is the model as created by Veronique when writing her thesis. The model now is more region specific and using a simple decision tree.)

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
	- Stepwise logistic regression 
	- Support vector machine (with radial basis kernel)
	- Random forest 
4. Results
	- Lasso logistic regression 
	- Stepwise logistic regression 
	- Support vector machine (with radial basis kernel)
	- Random forest 
5. Conclusion 	
6. Future improvements
7. Presentation 
8. Extra 

## 1. Research question: 

The research question of this project was defined as followed: *“How accurate can we predict the impact of future floods at district-level based on historical data (i.e. the impact of historical floods and the amount of rainfall on the dates of the historical floods) and the Community Risk Assessment data?”*

## 2. Required datasets: 

To answer the research question I needed to obtain the following three datasets: 
1.	**Desinventar dataset**:  This dataset shows several variables which indicate the impact of  historical floods in Uganda. To give you an idea; there were impact-variables related to people (i.e. amount of deaths), impact-variables related to houses (i.e. amount of destroyed houses), impact-variables related to infrastructure (i.e. amount of roads affected) and impact-variables related to economics (i.e. amount of crops destroyed). For a more elaborate description of all the variables, click [here](https://www.desinventar.net/effects.html).  
2.	**GloFAS dataset**: this dataset shows information about the intensity of the historical floods based on weather indicators.   
3.	**Community Risk Assessment (CRA) dataset**: this dataset shows several variables which indicate the vulnerability of a district (i.e. the distance a district from a major hospital or the percentage of unemployed people in a district).

The desinventar dataset and the CRA dataset were open source and could therefore be downloaded easily from the web. However, I experienced some difficulties with obtaining the GloFAS dataset: the GloFAS data was not open source and it appears that there were some time-consuming steps which had to be performed before I could obtain the data. After discussing this with 510 we decided that, regarding my internship time, it would be better to use an alternative to the GloFAS data for now, namely historical rainfall data. 

4.	**Rainfall dataset**  (as replacement for GloFAS dataset): this dataset consists of historical rainfall (from 2000 until now) in mm per day per raster of Uganda.

![alt text](https://github.com/rodekruis/statistical_floodimpact_uganda/raw/master/pictures/datasets.png)

## 3. Explanation R-script: 

In this paragraph, I will give a step-by-step explanation of the R-script named *Impact_data_analysis_Uganda.R*. In the meantime, I will give some arguments to explain why I made certain decisions.

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
- Some reported dates of floods were not recognized ‘as.Date’ as the day or month of the flood was not given (i.e. ‘00’) and therefore those dates received a NA value. As I needed the dates of the historical floods (because otherwise I couldn’t merge the historical floods to the historical rainfall), I filled in the ‘00’-days and/or months with the day and/or month for which the mean rainfall was highest in the corresponding district. Sometimes, it occured that there was no rainfall data available for a particular district with a reported flood with '00' as day. When this happened, I set the day to the first day of the month (i.e. '01'). I am of course not sure if those filled in dates are correctly. However, I think this option is better than simply removing all the floods with a ‘00’ day and/or month (as we retained more data now). 

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

### Aggregate floods: 

It appeared that sometimes multiple floods in the same district on the same day or within several days were reported in the desinventar dataset (i.e. by multiple sources). As it is very rare that there occur more floods in the same district within 1 week of time, I decided to aggregate the floods within a district that have a difference in date less than 7 days. 

Before I could do this aggregation, I have performed several steps: First, I have created an extra column named ‘difference’. This column represents for each flood the amount of days between the flood and the next reported flood in the corresponding district. After that, I have made a for-loop that worked as followed: if the amount of days between the flood and the next flood was larger than 7 the original reported date of the flood was kept. But if the amount of days between the flood and the next flood was smaller than 7, the date was set to NA. Subsequently, I replaced all the NA-dates with the first non-NA-date that follows for the corresponding district. To give an example: suppose that there are three reported floods in district Abim, with three different reported dates: 27-09-2011, 28-09-2011 and 30-09-2011. By running the for loop, all reported floods will receive 30-09-2011 as date. 

After I had performed  those steps, I have aggregated all the floods that occurred within the same district and that had the exact same reported date. I did this aggregation by taking the mean of only the non-zero values. I decided to take the mean of only the non-zero values for the following reason: The (from origin) impact variables contained a lot of zero values. It was not clear if those zero’s mean that there was really no impact or that it was not known if there was any impact. As the probability was high that the last reasoning is true, aggregating floods by taking the mean of all values (also the zero values) will give biased results. 

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

### Prepare dataset: 

In the beginning, the idea was to make a separate prediction for all the impact variables in the desinventar data. However, after some data exploration (correlations/scatterplots/conditional density plots) it appears that often there was no relationship between an impact-variable and one of the rainfall predictors. This while it was expected that  amount of rainfall should be the most important predictor when predicting flood impact. Therefore, it was already expected by me that no model would be able to predict the separate impact-variables well. To get more feeling of the data, I nevertheless build a multiple linear regression model and extend on that with a zero-inflated Poisson regression, as I read in the literature that this model could be used to model count data with an excess of zero counts (remember: the impact variables contained a lot of zero values). But as expected, both models were not able at all to predict the several impact variables (therefore I removed those lines of codes from the R-script).  

Because of the above mentioned reason, I decided together with 510 to create one ‘total’ binary impact variable (impact yes/no) based on all/some of the impact variables. Subsequently, the idea was to make predictions for this single total impact variable instead of making predictions for all the impact variables separately. 

The desinventar dataset consists of 14 continuous impact variables and 9 binary/categorical impact variables. After several explorations, I decided to use only the 9 binary impact variables for creating a ‘total’ impact variable. I had several reasons for this. First of all, there was a lot more info (filled in/non-zero values) available for the binary variables (and therefore the data quality of those variables seems better) compared with the continuous variables. Second, based on correlations, conditional density plots and scatterplots, the binary variables seem to have a stronger (positive) relationship with the rainfall predictors compared with the continuous variables. Third, all the binary variables were quite highly correlated (which was expected), while they were not highly correlated with the continuous variables and while the continuous variables were not correlated with each other (see plot: health, education, agriculture, industry, aqueduct, sewerage, energy, communication and damaged roads are the 9 binary impact variables).  

![alt text]( https://github.com/rodekruis/statistical_floodimpact_uganda/raw/master/pictures/correlationmatrix_dependent.png)

I have created the total impact variable as follows: If a case/reported flood has at least one ‘1’ (= impact) on the nine binary impact variables, the flood gets a ‘1’ (= impact) on the total impact variable. If a flood has no ‘1’ on at least one of the nine binary impact variables, the flood gets a ‘0’ (= no impact) on the total impact variable (named ‘DEP_total_affect_binary’ in the dataset). I have removed all the other,  single impact variables from the dataset. 

After visualising the (amount of) missing values in the dataset, I have decided to remove the reported floods of 5 districts (total of 40 floods) as there were no rainfall predictors available for those districts (while the rainfall predictors should be the most important predictors of floodimpact). In addition, I removed two CRA variables as they had more than 85% missing values. There were 12 more CRA variables with any missing values, but the amount of missing values for those variables was less than 5%. I therefore decided not to remove those 12 variables, but to fill in the missing values using mean imputation. 

Furthermore, it appeared that 4 CRA variables had very few unique values (i.e. there were 4 unique values on the variable earthquake exposure, 16 unique values on the variable violent incidents). I decided to remove those variables, as they will probably not be good predictors due to the few amount of unique values. I also decided to remove the CRA variables population density and population as it appeared that the values on those variables were way to high (i.e. population number was sometimes in billions, which is not possible for Uganda). It looks like a comma was missing somewhere in the number. In was not problematic to remove those two variables, as it was not expected that those variables were valuable predictors. 

I have built four statistical models, namely a lasso logistic regression, a stepwise logistic regression, a support vector machine (with a radial basis kernel) and a random forest (more information about the models in the next paragraphs). I have fitted the models with the 10 RAIN variables and the remaining 23 CRA variables as independent variables and the total impact as dependent variable. Subsequently, I have explored which independent variables were seen as most important predictors for flood impact by each of the fitted models. For lasso logistic regression, the variables that were not shrunken to zero by the model were seen as most important. For stepwise logistic regression, the by the model selected variables were seen as most important. For random forest, the variables which provide the highest mean decrease in accuracy and/or the highest mean decrease in Gini were seen as the most important variables. 5 RAIN variables and 11 CRA variables were not seen as important by (most of) the fitted models. Also, when I examined the correlations, scatterplots and conditional density plots, it seems that there were no (or no high) relationships between total impact and each of those 16 independent variables. This again implies, that those variables are probably not important for the prediction of impact. Therefore, I decided to remove those 16 variables from the dataset as well. 

Last but not least, during the data preparation phase I have standardized all the (remaining) independent variables. This means that all variables will have a mean of zero and a standard deviation of one, so that all variables will be on a comparable scale. This way, you avoid the problem that in some models, variables that are measured on a large scale will have more influence on the classifier than variables that are on a small scale. 

### Examine dataset: 

After the data preparation, the dataset consists of a total impact variable, which is the dependent variable and 5 RAIN variables and 12 CRA variables, which are the independent variables (and 3 general variables which are not going to play a part in the data modelling). To get more feeling of this final dataset, I summarized some descriptive statistics and visualized some correlation matrices, conditional density plots, scatterplots, histograms and boxplots. 

### Lasso logistic regression: 

I have used nested 5-fold cross-validation to get estimates of several performance metrics for the lasso logistic regression model. This approach randomly divides the set of observations into five groups, or outer-folds, of approximately equal size. One outer-fold is treated as testset, and the model is trained on the remaining four outer-folds (trainingset). In a lasso logistic regression, the only parameter which you could tune is the lambda parameter. Instead of arbitrarily choosing a lambda value, I did a 10-fold cross-validation to choose the optimal value of the parameter lambda: the outer trainingset (the four outer-folds) were therefore split into ten new inner-folds (one inner fold is treated as validationset and the remaining nine inner-folds are treated as trainingset). Different lambda values (the lambda sequence is chosen by the function ‘glmnet’) are fitted on the (inner) trainingset and the classification error rate of each lambda value is calculated on the (inner) validation set. This is repeated ten times; each time a different inner fold of observations was treated as inner validationset. We then selected the lambda value for which the mean classification error was smallest. The lambda that results in the smallest classification error was used to fit the model on the outer trainingset, and the Area Under the Curve (AUC), the confusion matrix, the accuracy and the F1-score were computed on the outer testset. This whole procedure was repeated five times; each time, a different outer-fold of observations was treated as the testset. So, this process resulted in five estimates of the AUC, the confusion matrix, the accuracy and the F1-score. Each one calculated using (possibly) a different lambda value. An overall estimate of each performance metric was calculated by averaging the 5 values on the particular performance metric. 

![alt text]( https://github.com/rodekruis/statistical_floodimpact_uganda/raw/master/pictures/nested_crossvalidation.png)

### Stepwise logistic regression: 

I have used 5-fold cross-validation to get estimates of several performance metrics for the stepwise logistic regression model. This approach randomly divides the set of observations into five groups, or outer-folds, of approximately equal size. One outer-fold is treated as testset, and the model is trained on the remaining four outer-folds (trainingset). In a stepwise logistic regression, there are no parameters which you could tune (so we had no nested cross-validaiton). The stepwise logistic regression is fitted on the outer trainingset, and the Area Under the Curve (AUC), the confusion matrix, the accuracy and the F1-score were computed on the outer testset. This whole procedure was repeated five times; each time, a different outer-fold of observations was treated as the testset. So, this process resulted in five estimates of the AUC, the confusion matrix, the accuracy and the F1-score. An overall estimate of each performance metric was calculated by averaging all the 5 values on the particular performance metric. 

### Support vector machine (with radial basis kernel): 

I have used nested 5-fold cross-validation to get estimates of several performance metrics for the support vector machine (with radial basis kernel). This approach randomly divides the set of observations into five groups, or outer-folds, of approximately equal size. One outer-fold is treated as testset, and the model is trained on the remaining four outer-folds (trainingset). In a support vector machine with a radial basis kernel, you can tune two parameters: a cost parameter and a sigma parameter. I have kept the tuning parameter ‘sigma’  constant by the model. However, instead of choosing the default ‘cost’ value, I did a 10-fold cross-validation to choose the optimal value of the cost parameter: the outer trainingset (the four outer-folds) were therefore split into ten new inner-folds (one inner fold is treated as validationset and the remaining nine inner-folds are treated as trainingset). Three different cost values (0.25, 0.5 and 1) are fitted on the (inner) trainingset and the classification error rate of each cost value is calculated on the (inner) validation set. This is repeated ten times; each time a different inner fold of observations was treated as inner validationset. We then selected the cost value for which the mean classification error was smallest. The cost value that results in the smallest classification error was used to fit the model on the outer trainingset, and the Area Under the Curve (AUC), the confusion matrix, the accuracy and the F1-score were computed on the outer testset. This whole procedure was repeated five times; each time, a different outer-fold of observations was treated as the testset. So, this process resulted in five estimates of the AUC, the confusion matrix, the accuracy and the F1-score. Each one calculated using (possibly) a different cost value. An overall estimate of each performance metric was calculated by averaging all the 5 values on the particular performance metric. 

### Random forest: 

I have used 5-fold cross-validation to get estimates of several performance metrics for the random forest model. This approach randomly divides the set of observations into five groups, or outer-folds, of approximately equal size. One outer-fold is treated as testset, and the model is trained on the remaining four outer-folds (trainingset). In a random forest you can tune different parameters: for example, the number of trees (ntree), tree size (maxdepth) and the number of predictor variables used for split selection (mtry). I didn’t tuned the parameters of this model yet (using a nested cross-validation), but just used the default settings of the parameters . So the model (with the default settings) is fitted on the outer trainingset, and the Area Under the Curve (AUC), the confusion matrix, the accuracy and the F1-score were computed on the outer testset. This whole procedure was repeated five times; each time, a different outer-fold of observations was treated as the testset. So, this process resulted in five estimates of the AUC, the confusion matrix, the accuracy and the F1-score. An overall estimate of each performance metric was calculated by averaging all the 5 values on the particular performance metric. 

## 4. Results: 
I have runned the 4 (above described) models with total impact as dependent variable and the remaining 5 RAIN variables and 12 CRA variables as independent variables. The results of each of the models are reported below: 

### Lasso logistic regression: 

The mean values (mean over five folds) on the performance metrics are as followed for the lasso logistic regression model: 
- AUC: 0.675437
- Accuracy: 0.6712444
- F1 score: 0.7795756
- Confusion matrix: 

<i></i>   | Actual: no impact (0) | Actual: impact (1) 
--- | --- | ---
**Predicted: no impact (0)** | 10 | 7
**Predicted: impact (1)** | 31 | 67

### Stepwise logistic regression: 

The mean values (mean over five folds) on the performance metrics are as followed for the stepwise logistic regression model: 
- AUC: 0.6661027
- Accuracy: 0.6746927
- F1 score: 0.7740094
- Confusion matrix: 

<i></i>   | Actual: no impact (0) | Actual: impact (1) 
--- | --- | ---
**Predicted: no impact (0)** | 13 | 10
**Predicted: impact (1)** | 28 | 65

### Support vector machine (with radial basis kernel):  

The mean values (mean over five folds) on the performance metrics are as followed for the support vector machine (with radial basis kernel):
- AUC: 0.641227
- Accuracy: 0.6782009
- F1 score: 0.7944005
- Confusion matrix: 

<i></i>   | Actual: no impact (0) | Actual: impact (1) 
--- | --- | ---
**Predicted: no impact (0)** | 6 | 3
**Predicted: impact (1)** | 35 | 72

### Random forest:   

The mean values (mean over five folds) on the performance metrics are as followed for the random forest: 
- AUC: 0.6439278
- Accuracy: 0.6522189
- F1 score: 0.7480458
- Confusion matrix: 

<i></i>   | Actual: no impact (0) | Actual: impact (1) 
--- | --- | ---
**Predicted: no impact (0)** | 15 | 15
**Predicted: impact (1)** | 25 | 60

## 5. Conclusion: 

The results show that the performance of the four models don’t differ very much from each other. However, the AUC of the lasso logistic regression is clearly somewhat higher compared with the other 3 models. As a (lasso) logistic regression is also a model that is quite easy to understand and interpret (especially compared to a support vector machine and a random forest which are black boxes), I decided together with 510 that the lasso logistic regression is (for now) the best model to use when predicting the impact of floods. The model is able to predict impact with 67% accuracy. 

To keep in mind: I have made this conclusion based on comparing the lasso logistic regression which was completely tuned with a support vector machine which was only a bit tuned (only the cost parameter was tuned) and a random forest which was not tuned at all. Therefore, it could be that the random forest or support vector machine would have perform (way) better if I tune those two models (even further). I have written already a code (the lines starting with #) which you have to add to the support vector machine and the random forest to tune the models (even further). 

## 6. Future improvements: 

- Use the GloFAS dataset instead or in addition to the rainfall dataset or try to find other data which could be useful to predict flood impact. 
- Use the mean rainfall per catchment area of a district instead of the mean rainfall per district to create the RAIN variables (see elaborate explanation for this at paragraph ‘Extra’. 
- Try to collect more and/or more accurate impact data (i.e. try to collect the correct dates of the flood and try to be clear if a zero value in the dataset means that there was actually no impact or that it is unknown if there was impact). 
- Create the total impact variable not only based on findings in the data, but also based on expertise knowledge. 
- Split the total impact variable in for example four impact variables: impact related to people, impact related to houses, impact related to infrastructure and impact related to economics and make separate predictions for those 4 variables (this improvement can only be done after there is collected more and more accurate impact data). 
- Use a more sophisticated technique to handle the missing values in the dataset, for example multiple imputation. 
- Select the most important predictor variables not only based on findings in the data, but also based on expertise knowledge. 
- Try to resample the minority class in the data (impact = 1) so the dataset gets more balanced.  
- Tune the parameters of the support vector machine (with radial basis kernel)and the parameters of the random forest and see if the lasso logistic regression has still the best model performance.  
- Make the R-script more reproducible (i.e. that it could be used for other countries as well). 

## 7. Presentation: 

I have presented the entire project during a lunch meeting at 510. You will find the presentation here: https://github.com/rodekruis/statistical_floodimpact_uganda/raw/master/PresentationProject.pdf

## 8. Extra: 

The relationships between the created total impact variable and the different RAIN variables were not as high as was expected. This is possibly also the main reason why the model is not performing very well. At 510, they expected that the model performance would be better if I could take the mean rainfall per catchment area of a district instead of per district and use this rainfall to create the RAIN predictors. A colleague of 510 was therefore assigned to visualise the catchment areas of all the districts of Uganda using Geographic Information System (GIS) analyses. However, as it proved to be more complex and time-consuming than expected for my colleague to visualise the catchment areas, she decided to visualize the catchment areas of only 3 of the 128 districts of Uganda (namely Moyo, Sironko and Soroti). 

When I received the catchment boundaries of the three districts, I prepared two separate datasets (named *data_districtRAIN.txt* and *data_catchmentRAIN.txt*) with two seperate R-scripts (named *relationships_districtRAIN.R* and *relationships_catchmentRAIN.R*. You can find those R-scripts and belonging datasets in the folder named 'extra' (C:\Users\*Username*\Documents\GitHub\statistical_floodimpact_uganda\extra).  
The dataset called *data_catchmentRAIN.txt* represents the total impact of each reported flood in the 3 districts and the corresponding RAIN predictors to that flood, which were created based on the mean rainfall of the catchment area of the district. And the dataset called *data_districtRAIN.txt* represents the total impact of each reported flood in the 3 districts and the corresponding RAIN predictors to that flood, which were created based on the mean rainfall of the district. Subsequently, I could compare the relationships between total impact and each RAIN predictor between the two datasets.  

It appears that the correlations between the total impact and each RAIN predictors was higher when creating the RAIN predictors using the mean rainfall per catchment area of a district instead of using the mean rainfall per district. (To give you an idea: the correlation between impact and rain_at_day was R = 0.13 vs. R = 0.09, between impact and rain_1_day_before was R = 0.17 vs. R = 0.12, between impact and rain_2_days_before was R = 0.15 vs. R = 0.09, between impact and rain_3_days_before was R = 0.16 vs. R = 0.14 and between impact and Rain_4_days_before was R = 0.16 vs. R = 0.14).  In addition, I have made conditional density plots and scatterplots which again visualize that the relationship between total impact and each RAIN predictor based on mean rainfall per catchment area of a district is a bit stronger (see plots): 

![alt text](https://github.com/rodekruis/statistical_floodimpact_uganda/raw/master/pictures/relationships_districtRAIN.png)
![alt text](https://github.com/rodekruis/statistical_floodimpact_uganda/raw/master/pictures/relationships_catchmentRAIN.png)

To keep in mind: the relationships are based on floods that occurred in only 3 districts (40 observations). The difference in relationships could of course change when we compare the relationships that are based on the floods in all districts. But based on the results of only those 3 districts, it would probably be better to visualize the catchment areas of all the districts,  create the RAIN predictors based on the mean rainfall per catchment area of the district and use those predictors when predicting total impact of a flood. However, there was nobody at  510 who had sufficient time to visualize all the catchment areas within a short period of time. Therefore, we decided to stick with the old dataset (dataset with RAIN predictors created based on the mean rainfall per district) and we made predictions on this dataset (as described above). 








