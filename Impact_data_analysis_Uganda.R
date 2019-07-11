#------------------------  Load required packages ------------------------------

# Load required packages: 
require(raster)
require(rgdal)
require(ncdf4)
library(R.utils)
library(rgdal)
library(rlang)
library(tibble)
library(rgdal)
library(maps)
library(ncdf4)
library(reshape2)
library(rasterVis)
library(RColorBrewer)
library(utils)
library(zoo)
library(dplyr)
library(readr)
library(utils)
library(readxl)
library(randomForest)
library(RFmarkerDetector)
library(AUCRF)
library(caret)
library(kernlab)
library(ROCR)
library(MASS)
library(glmnet)
library(pROC)
library(MLmetrics)
library(plyr)
library(psych)
library(corrplot)
library(visdat)
library(naniar)
library(tidyr)
library(lubridate)

#---------------------- Load in rainfall dataset -------------------------------

# Load in rainfall dataset 
rainfall <- read.delim("raw_data/rainfall.txt")

#---------------------- Load in Desinventar dataset ----------------------------

# Load in Desinventar dataset: 
DI_uga <- read_csv("raw_data/DI_uga.csv")

#------------------------ Load in  CRA dataset ---------------------------------

#Load in Community Risk Assessment dataset: 
CRA <- read_excel("raw_data/CRA Oeganda.xlsx")

#------------------- Prepare rainfall dataset for merging ----------------------

# Define projection: 
crs1 <- "+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0" 

# Working directory for uganda boundary to read districts: 
wshade <- readOGR("boundaries/districts.shp",layer = "districts") 

# Define similar projection:
wshade <- spTransform(wshade, crs1)

# Put the names of the districts in rainfall dataset:  
districtname <- as.data.frame(wshade$name)
rainfall <- cbind(rainfall, districtname)

# Remove ID from dataset (because now we have districtnames instead): 
rainfall$ID <- NULL

# Move 'wshade$name' variable to front of dataset: 
rainfall <- dplyr::select(rainfall, "wshade$name", everything())

# Make the districtnames uppercase (needed to merge all datasets together):    
rainfall[,1] <- toupper(rainfall[,1]) 

# Name the column of the districtnames "ID": 
colnames(rainfall)[1] <- "ID"

# Remove "chirps.v2.0" from date: 
colnames(rainfall) = gsub(pattern = "chirps.v2.0.", replacement = "", x = names(rainfall))

# Transpose the data frame: 
rainfall <- as.data.frame(t(rainfall))

# Make the district names header: 
colnames(rainfall) <- as.character(unlist(rainfall[1,]))
rainfall <- rainfall[-1, ]

# Make a column with the dates:  
rainfall <- cbind(rownames(rainfall), data.frame(rainfall, row.names=NULL))
colnames(rainfall)[1] <- "date"

# Make the date as.Date instead of a factor:
rainfall$date <- as.Date(rainfall$date, format = "%Y.%m.%d")

# Reshaping wide format to long format: 
rainfall <- rainfall %>% gather(district, rainfall, MASAKA:BUGWERI)

# Make the numeric variables as.numeric: 
# rainfall[3] <- data.frame(lapply(rainfall[3], function(x) as.numeric(as.character(x))))

rainfall <- rainfall %>%
  dplyr::rename(zero_shifts = rainfall) %>%
  mutate(
    zero_shifts = as.numeric(zero_shifts),
    one_shift = lag(zero_shifts, 1),
    two_shifts = lag(zero_shifts, 2),
    three_shifts = lag(zero_shifts, 3),
    four_shifts = lag(zero_shifts, 4),
    five_shifts = lag(zero_shifts, 5),
    rainfall_2days = zero_shifts + one_shift,
    rainfall_3days = rainfall_2days + two_shifts,
    rainfall_4days = rainfall_3days + three_shifts,
    rainfall_5days = rainfall_4days + four_shifts
  )

#----------------------- Prepare Desinventar dataset for merging----------------

DI_uga <- DI_uga %>%
  dplyr::rename(district = admin_level_0_name) %>%
  filter(event == "FLOOD",
         year >= 2000) %>%
  mutate(date = ymd(paste(year, month, day, sep = "-"))) %>%
  arrange(district, year, month, day)

# Correct missing rainfall as follows
# 1 check the day of the year-month with maximum rainfall, if it is available set flood date to that date
# 2 if no rainfall data is available set it the first day of the month
# Note by Timo: this is Veronique's original method automated, I'd maybe rather throw away the ones with no rainfall data
max_rainfall <- rainfall %>%
  mutate(year = year(date),
         month = month(date)) %>%
  group_by(year, month) %>%
  arrange(-zero_shifts) %>%
  slice(1) %>%
  dplyr::select(year, month, date) %>%
  dplyr::rename(max_rain_date = date)

DI_uga <- DI_uga %>%
  left_join(max_rainfall, by = c("year", "month")) %>%
  mutate(date = if_else(is.na(date), max_rain_date, date)) %>%  # Rule 1
  mutate(date = if_else(is.na(date), ymd(paste(year, month, "1", sep = "-")), date)) %>%  # Rule 2
  dplyr::select(-max_rain_date)

#-------------------- Prepare CRA dataset for merging --------------------------

# Make the districtnames uppercase (is needed to merge all datafiles together): 
CRA <- as.data.frame(sapply(CRA, toupper))

# Rename first column "district" (needed to merge all datasets together): 
colnames(CRA)[1] <- "district"

# Make the numeric variables as.numeric: 
CRA[4:56] <- data.frame(lapply(CRA[4:56], function(x) as.numeric(as.character(x))))

#------------------------ Merge the three datasets -----------------------------

# Merge the three datasets based on district and flooddate:

data <- DI_uga %>%
  inner_join(rainfall, by = c("district", "date")) %>%
  inner_join(CRA, by = "district")

# Write data to a file so not every time all the above steps have to be taken:
write.csv(data, "processed_data/mergeddataset.csv", row.names = FALSE)

data <- read_csv("processed_data/mergeddataset.csv")

#--------------------------- Aggregate floods ----------------------------------
# If floods are reported on dates too close to one another give them the same date (date_NA_filled)
data <- data %>%
  mutate(difference = difftime(lead(date, default = 999), date, units = "days"),
         date_NA_filled = if_else((difference <= 7 & difference >= 0), date(NA), date))

data$date_NA_filled <- na.locf(data$date_NA_filled, fromLast = TRUE)



# Remove some variables which I can't aggregate (as they are characters) and don't have to use anymore: 
data <- dplyr::select(data, -c("serial", "date", "admin_level_0_code", "admin_level_1_code", "admin_level_2_code", 
                                "admin_level_1_name", "admin_level_2_name", "event", "location", "sources", 
                                "year", "month", "day", "cause", "magnitude", "latitude", "longitude", 
                                "comments", "others", "pcode_parent", "difference", "pcode_level2"))

# Aggregate the floods in a district which have the same date (mean of filled-in/non-zero values):  
data_agg <- data %>%
  group_by(pcode, district, date_NA_filled) %>% 
  summarise_all(funs(mean), na.rm = TRUE) %>%
  ungroup()

#---------------------------Rename and define all variables---------------------

# Remove variables which have 0-10 in name (standardized variables):
data_agg <- dplyr::select(data_agg, -contains('0-10'))

# Rename all variables:
data_agg <- data_agg %>%
  dplyr::rename(GEN_pcode = pcode,
         GEN_district = district, 
         GEN_date = date_NA_filled, 
         DI_people_deaths = deaths, 
         DI_people_injured = injured, 
         DI_people_missing = missing, 
         DI_people_affected = affected, 
         DI_houses_houses_destroyed = houses_destroyed, 
         DI_houses_houses_damaged = houses_damaged, 
         DI_economic_losses_loc = `losses $loc`,
         DI_economic_losses_usd = `losses $usd`,
         DI_infra_health = health, 
         DI_infra_education = education, 
         DI_economic_agriculture = agriculture, 
         DI_infra_industry = industry,
         DI_infra_aqueduct = aqueduct,
         DI_infra_sewerage = sewerage,
         DI_infra_energy = energy,
         DI_infra_communication = communication,
         DI_infra_damaged_roads =  `damaged roads`,
         DI_infra_damaged_hospitals = `damaged hospitals`,
         DI_infra_damaged_education_centers = `damaged education centers`,
         DI_economic_damaged_crops = `damage in crops Ha.`,
         DI_economic_lost_cattle = `lost cattle`,
         DI_people_evacuated = evacuated, 
         DI_people_relocated = relocated, 
         RAIN_at_day = zero_shifts, 
         RAIN_1day_before = one_shift, 
         RAIN_2days_before = two_shifts, 
         RAIN_3days_before = three_shifts, 
         RAIN_4days_before = four_shifts, 
         RAIN_5days_before = five_shifts, 
         RAIN_1day_before_cumulative = rainfall_2days, 
         RAIN_2days_before_cumulative = rainfall_3days, 
         RAIN_3days_before_cumulative = rainfall_4days, 
         RAIN_4days_before_cumulative = rainfall_5days, 
         CRA_hazard_violent_incidents = `Violent incidents last year`,
         CRA_vulnerability_disability = `% persons with disability`,
         CRA_coping_drinking_water = `% Access to safe drinking water`,
         CRA_coping_educational_facilities = `Nr. of educational facilities per 10,000 people`,
         CRA_coping_electricity = `% Access to electricity`,
         CRA_vulnerability_employed = `% employed`,
         CRA_hazard_drought_exposure = `Drought exposure`,
         CRA_hazard_earthquake_exposure = `Earthquake exposure`,
         CRA_hazard_flood_exposure = `Flood exposure`,
         CRA_coping_health_facilities = `Nr. of health facilities per 10,000 people`,
         CRA_coping_sanitation = `% Access improved sanitation`,
         CRA_vulnerability_literacy = `% Literacy`,
         CRA_vulnerability_mosquito_nets = `% having mosquito nets`,
         CRA_vulnerability_orphans = `% of orphans under 18`,
         CRA_vulnerability_poverty = `Poverty incidence`,
         CRA_vulnerability_roof_type = `% permanent roof type`,
         CRA_vulnerability_subsistence_farming = `% Subsistence farming`,
         CRA_coping_time_to_city =  `Travel time to nearest city`,
         CRA_vulnerability_wall_type = `% permanent wall type`,
         CRA_coping_internet_access = `% with internet access`,
         CRA_coping_mobile_access =  `% with mobile access`,
         CRA_general_land_area = `Land area`,
         CRA_general_displaced_persons = `# of displaced persons`,
         CRA_general_displaced_local_population = `# of displaced / local population`,
         CRA_general_elevation = `Average elevation`,
         CRA_general_population_density = `Population density`,
         CRA_general_population = Population,
         CRA_general_coping = `Lack of Coping Capacity`,
         CRA_general_risk = `Risk score`,
         CRA_general_hazard = `Hazards exposure`,
         CRA_general_vulnerability = Vulnerability)

# Write data to a file so not every time all the above steps have to be taken:
write.csv(data_agg, "processed_data/aggregateddataset.csv", row.names = FALSE)

data_agg <- read_csv("processed_data/aggregateddataset.csv")

#---------------------- Prepare (and examine) dataset --------------------------

# Seperate dataframe into dependent and independent variables:
data_agg_dep <- data_agg[c(1:3, 4:26)]
data_agg_indep <- data_agg[c(1:3, 27:67)]

# Make all values on dependent variables absolute:
data_agg_dep[4:26] <- abs(data_agg_dep[4:26])

# If value on dependent variables is above 0.5 make it a 1, otherwise a 0:
data_agg_dep[4:26][data_agg_dep[4:26] > 0.01] <- 1
data_agg_dep[4:26][data_agg_dep[4:26] <= 0.01] <- 0

# # # Correlations between dependent variables:
# correlations <- round(cor(data_agg_dep[,4:24]),2)
# corrplot(correlations)

# Take only the 9 binary variables into account when creating the impact variable: 
data_agg_dep <- data_agg_dep[c(1:3, 12:20)]

# Sum all the dependent variable values together: 
data_agg_dep$DEP_total_affect <- rowSums(data_agg_dep[4:12])

# Make total affect variable binary:
data_agg_dep$DEP_total_affect_binary[data_agg_dep$DEP_total_affect >= 1] <- 1
data_agg_dep$DEP_total_affect_binary[data_agg_dep$DEP_total_affect < 1] <- 0

# Bind dependent variables to independent variables: 
data <- cbind(data_agg_dep$DEP_total_affect_binary, data_agg_indep)
colnames(data)[1] <- "DEP_total_affect_binary"

# Make the created binary variables as factor: 
data$DEP_total_affect_binary <- as.factor(data$DEP_total_affect_binary)

# # Vizualize missingness:
# vis_miss(data)
# gg_miss_var(data)

# Remove variables which have more than 85 % NA's:
data <- dplyr::select(data, -c(CRA_general_displaced_persons, CRA_general_displaced_local_population))

# Remove 5 districts (Isingiro, Namayingo, Kaabong, Kabale, Ntoroko), of which no rainfall data is available: 
data <- data %>% drop_na(RAIN_at_day)

# Do mean imputation for every remaining column that has a missing value:
data <- data %>% mutate_all(.funs = list(~ifelse(is.na(.), mean(., na.rm=TRUE), .)))

  # # Variables with few unique values:
# length(unique(data$CRA_hazard_earthquake_exposure)) # 4/91 unique values 
# length(unique(data$CRA_hazard_violent_incidents)) #16/91 unique values 
# length(unique(data$CRA_hazard_flood_exposure)) # 23/91 unique values 
# length(unique(data$CRA_coping_internet_access)) # 57/91 unique values

# Remove variables which few unique values: 
data <- dplyr::select(data, -c(CRA_hazard_earthquake_exposure, CRA_hazard_violent_incidents, 
                               CRA_hazard_flood_exposure, CRA_coping_internet_access))

# Remove population density variable and population variable as those variables values seem not correct (way to high): 
data <- dplyr::select(data, -c(CRA_general_population_density, CRA_general_population))

# # Correlations between independent variables: 
# correlations <- round(cor(data[,5:length(data)]),2)
# corrplot(correlations)

# # Conditional density plots of total impact vs each independent variable:  
# for (i in 5:length(data)) {
#   cdplot(DEP_total_affect_binary ~ data[,i], data = data, main = names(data[i]))
# }

# # Scatterplots of total impact vs each independent variable: 
# for (i in 5:length(data)) {
#   plot(data[,i], data$DEP_total_affect_binary, main = names(data[i]))
#   fit <- glm(DEP_total_affect_binary ~ data[,i], data = data, family = "binomial")
#   abline(fit)
# }

# Remove unimportant variables:
data <- dplyr::select(data, -c(CRA_general_land_area, CRA_vulnerability_employed, CRA_coping_educational_facilities,
                      CRA_coping_drinking_water, CRA_hazard_drought_exposure, CRA_coping_time_to_city, CRA_general_elevation, 
                      CRA_general_coping, CRA_general_hazard, RAIN_1day_before, RAIN_2days_before, RAIN_3days_before, RAIN_4days_before, 
                      RAIN_5days_before, CRA_vulnerability_poverty, CRA_coping_sanitation))

# Standardize the variables: 
data[,5:length(data)] <- scale(data[,5:length(data)])

#-------------------------Examine final dataset---------------------------------

# General information about the data:
summary(data)
str(data)

# Correlations between independent variables:
correlations <- round(cor(data[,5:length(data)]),2)
corrplot(correlations)

# Conditional density plots of total impact vs each independent variable: 
for (i in 5:length(data)) {
  cdplot(DEP_total_affect_binary ~ data[,i], data = data, main = names(data[i]))
}

# Scatterplots of total impact vs each independent variable: 
for (i in 5:length(data)) {
  plot(data[,i], data$DEP_total_affect_binary, main = names(data[i]))
  fit <- glm(DEP_total_affect_binary ~ data[,i], data = data, family = "binomial")
  abline(fit)
}

# Histogram of each numeric variable: 
multi.hist(data[,sapply(data, is.numeric)])

# Boxplot of each independent variable: 
for (i in 5:length(data)) {
  boxplot(data[,i], main=names(data[i]), type = "l")
}

# --------------------- Lasso logistic regression ------------------------------

# Initialize variables: 
nfolds <- 5 
set.seed(1)
folds <- sample(rep(1:nfolds, length=nrow(data), nrow(data)))
table(folds)
AUC.lasso <- matrix(NA, nfolds)
F1.lasso <- matrix(NA,  nfolds)
accuracy.lasso <- matrix(NA, nfolds)
coefs.lasso <- matrix(NA, 18, nfolds) 
cm.lasso <- matrix(NA, 4, 5)

# Set seed to make reproducible results:                                 
set.seed(1)
# Start for-loop for (nested) 5-fold crossvalidation: 
for(i in 1:nfolds) {
  # Create the train and testset: 
  train <- folds != i
  train <- data[train,]
  test <- folds == i
  test <- data[test,]
  xtrain <- as.matrix(train[,5:21])  
  ytrain <- as.matrix(train[,1]) 
  xtest <- as.matrix(test[,5:21])
  ytest <- as.matrix(test[,1])
  # Fit model on outertrain (with 10-fold cross-validation to determine optimal lambda): 
  cv.lasso <- cv.glmnet(xtrain, ytrain, alpha = 1, family="binomial") 
  betas <- coef(cv.lasso, cv.lasso$lambda.min)
  betas <- as.matrix(betas)
  coefs.lasso[,i] <- betas
  # Make predictions on outer testset: 
  lasso.predict.pr <- predict(cv.lasso, newx=xtest, s=cv.lasso$lambda.min, type = "response")
  # Calculate Area under the curve: 
  pred <- prediction(lasso.predict.pr, test$DEP_total_affect_binary) 
  auc <- performance(pred, measure= 'auc')
  AUC.lasso[i] <- auc@y.values[[1]]
  # Plot area under the curve: 
  perf <- performance(pred, measure = "tpr", x.measure = "fpr") 
  par(mfrow=c(1,2))
  plot(perf, col=rainbow(7), main="ROC curve", xlab="1-Specificity", 
       ylab="Sensitivity")    
  abline(0, 1) 
  # Plot confusion matrix:
  lasso.predict.pr[lasso.predict.pr >= "0.50"] <- 1
  lasso.predict.pr[lasso.predict.pr < "0.50"] <- 0
  confusionmatrix.lasso <- confusionMatrix(as.factor(lasso.predict.pr), as.factor(ytest))
  fourfoldplot(confusionmatrix.lasso$table, main = "Confusion matrix")
  cm.lasso1 <- as.data.frame(confusionmatrix.lasso[["table"]])[,3]
  cm.lasso[,i] <- as.matrix(cm.lasso1)
  # Calculate accuracy: 
  accuracy.lasso[i] <- confusionmatrix.lasso[["overall"]][["Accuracy"]]
  # Calculate F1 score: 
  F1.lasso[i] <- F1_Score(test$DEP_total_affect_binary, lasso.predict.pr, positive = "1")
}

# Results of performance metrics: 
apply(AUC.lasso, 2, mean)
apply(F1.lasso, 2, mean)
apply(accuracy.lasso, 2, mean)
rowMeans(cm.lasso) # mean confusion matrix 

# -------------------------- Stepwise logistic regression -----------------------

# Initialize variables: 
nfolds <- 5 
set.seed(1)
folds <- sample(rep(1:nfolds, length=nrow(data), nrow(data)))
table(folds)
AUC.step.lr <- matrix(NA, nfolds)
accuracy.step.lr <- matrix(NA, nfolds)
F1.step.lr <- matrix(NA, nfolds)
cm.step.lr <- matrix(NA, 4, 5)

# Set seed to make reproducible results:                                 
set.seed(1)
# Start for-loop for 5-fold crossvalidation: 
for(i in 1:nfolds) {
  # Create the train and testset: 
  train <- folds != i
  train <- data[train,]
  test <- folds == i
  test <- data[test,]
  train <- train[,c(1, 5:21)] 
  test <- test[,c(1, 5:21)]
  # Fit model on trainset: 
  step.lr <- glm(DEP_total_affect_binary ~ ., data = train, family =  "binomial") %>% stepAIC(trace = FALSE)
  # Make predictions on testset: 
  step.lr.pr <- predict(step.lr, newdata = test, type = "response")
  # Calculate Area under the curve: 
  pred <- prediction(step.lr.pr, test$DEP_total_affect_binary) 
  auc <- performance(pred, measure='auc')
  AUC.step.lr[i] <- auc@y.values[[1]]
  # Plot area under the curve: 
  perf <- performance(pred, measure = "tpr", x.measure = "fpr") 
  par(mfrow=c(1,2))
  plot(perf, col=rainbow(7), main="ROC curve", xlab="1-Specificity", 
       ylab="Sensitivity")    
  abline(0, 1) 
  # Plot confusion matrix:
  step.lr.pr[step.lr.pr >= "0.5"] <- 1 
  step.lr.pr[step.lr.pr < "0.5"] <- 0 
  confusionmatrix.step.lr <- confusionMatrix(as.factor(step.lr.pr), as.factor(test$DEP_total_affect_binary))
  fourfoldplot(confusionmatrix.step.lr$table, main = "Confusion matrix")
  cm.step.lr1 <- as.data.frame(confusionmatrix.step.lr[["table"]])[,3]
  cm.step.lr[,i] <- as.matrix(cm.step.lr1)
  # Calculate accuracy: 
  accuracy.step.lr[i] <- confusionmatrix.step.lr[["overall"]][["Accuracy"]]
  # Calculate F1 score: 
  F1.step.lr[i] <- F1_Score(test$DEP_total_affect_binary, step.lr.pr, positive = "1")
} 

# Results of performance metrics: 
apply(AUC.step.lr, 2, mean)
apply(F1.step.lr, 2, mean)
apply(accuracy.step.lr, 2, mean)
rowMeans(cm.step.lr) # mean confusion matrix

# -------------------- Support Vector Machine-----------------------------------

# Initialize variables: 
nfolds <- 5 
set.seed(1)
folds <- sample(rep(1:nfolds, length=nrow(data), nrow(data)))
table(folds)
AUC.svm <- matrix(NA, nfolds)
F1.svm <- matrix(NA,  nfolds)
accuracy.svm <- matrix(NA, nfolds)
coefs.svm <- matrix(NA, 17, nfolds)
cm.svm <- matrix(NA, 4, 5)

# Set seed to make reproducible results:                                 
set.seed(1)
# Start for-loop for (nested) 5-fold crossvalidation: 
for(i in 1:nfolds) {
  # Create the train and testset: 
  train <- folds != i
  train <- data[train,]
  test <- folds == i
  test <- data[test,]
  train <- train[,c(1, 5:21)]
  test <- test[,c(1, 5:21)]
  # Code which you should add when you want to tune the parameters: 
  #grid <- expand.grid(sigma = c(.25, .50, 1, 2, 4), C = c(.001, .01, .1, 1, 5, 10, 100))
  # 10 fold cross validation on outer trainset to determine optimal cost: 
  tune.out <- train(DEP_total_affect_binary ~ ., data = train, method = "svmRadial", trControl = trainControl(method = "cv")) #, tuneGrid = grid) 
  importance <- varImp(tune.out, scale = FALSE)$importance[,2]
  importance <- as.matrix(importance)
  coefs.svm[,i] <- importance 
  # Fit model on outer trainset (with optimal cost parameter): 
  model.svm <- ksvm(DEP_total_affect_binary~.,data=train,kernel="rbfdot", prob.model = TRUE, 
                    kpar=list(sigma=tune.out$bestTune[,1]),C=tune.out$bestTune[,2])
  # Make predictions on outer testset: 
  svm.predict <- predict(model.svm, test, type="probabilities")
  svm.predict <- as.numeric(svm.predict[,2])
  # Calculate Area under the curve: 
  pred <- prediction(svm.predict, test$DEP_total_affect_binary) 
  pred <- prediction(svm.predict, test$DEP_total_affect_binary) 
  auc <- performance(pred, measure= c('auc'))
  AUC.svm[i] <- auc@y.values[[1]]
  # Plot area under the curve: 
  perf <- performance(pred, measure = "tpr", x.measure = "fpr") 
  par(mfrow=c(1,2))
  plot(perf, col=rainbow(7), main="ROC curve", xlab="1-Specificity", 
       ylab="Sensitivity")    
  abline(0, 1) 
  # Plot confusion matrix:
  svm.predict[svm.predict >= "0.5"] <- 1
  svm.predict[svm.predict < "0.5"] <- 0
  confusionmatrix.svm <- confusionMatrix(as.factor(svm.predict), as.factor(test$DEP_total_affect_binary))
  fourfoldplot(confusionmatrix.svm$table, main = "Confusion matrix")
  cm.svm1 <- as.data.frame(confusionmatrix.svm[["table"]])[,3]
  cm.svm[,i] <- as.matrix(cm.svm1)
  # Calculate accuracy: 
  accuracy.svm[i] <- confusionmatrix.svm[["overall"]][["Accuracy"]]
  # Calculate F1 score: 
  F1.svm[i] <- F1_Score(test$DEP_total_affect_binary, svm.predict, positive = "1")
}

# Results of performance metrics: 
apply(AUC.svm, 2, mean)
apply(F1.svm, 2, mean)
apply(accuracy.svm, 2, mean)
rowMeans(cm.svm) #mean confusion matrix 

# -------------------------- Random Forest -------------------------------------

# Initialize variables: 
nfolds <- 5 
set.seed(1)
folds <- sample(rep(1:nfolds, length=nrow(data), nrow(data)))
table(folds)
AUC.rf <- matrix(NA, nfolds)
accuracy.rf <- matrix(NA, nfolds)
F1.rf <- matrix(NA, nfolds)
coefs.rf <- matrix(NA, 17, nfolds) 
cm.rf <- matrix(NA, 4, 5)

# # Code which you should add when you want to tune the parameters: 
# data$ID <- 1:nrow(data)
# data <- dplyr::select(data, "ID", everything())

# Set seed to make reproducible results:                                 
set.seed(1)
# Start for-loop for (nested) 5-fold crossvalidation: 
for(i in 1:nfolds) {
  # Create the train and testset: 
  train <- folds != i
  train <- data[train,]
  test <- folds == i
  test <- data[test,]
  #train1 <- train[,c(1, 2, 5:34)]
  train <- train[,c(1, 5:21)]
  test <- test[,c(1, 5:21)]
  # # Code which you should add when you want to tune the parameters: 
  #mtry <- tuneMTRY(train1, iterations = 2, mtry_length = 30, graph = TRUE)
  # Fit model on outer trainset:  
  ran.for <- randomForest(DEP_total_affect_binary ~., data = train, importance = TRUE) #, mtry = which.min(mtry$oob))  
  importance <- importance(ran.for)[,3]
  importance <- matrix(importance)
  coefs.rf[,i] <- importance
  # Make predictions on outer testset: 
  ran.for.pr <- predict(ran.for, newdata = test, type = "prob")
  ran.for.pr <- as.numeric(ran.for.pr[,2])
  # Calculate Area under the curve: 
  pred <- prediction(ran.for.pr, test$DEP_total_affect_binary)  
  auc <- performance(pred, measure='auc')
  AUC.rf[i] <- auc@y.values[[1]]
  # Plot area under the curve: 
  perf <- performance(pred, measure = "tpr", x.measure = "fpr") 
  par(mfrow=c(1,2))
  plot(perf, col=rainbow(7), main="ROC curve", xlab="1-Specificity", 
       ylab="Sensitivity")    
  abline(0, 1) 
  # Plot confusion matrix:
  ran.for.pr[ran.for.pr >= "0.5"] <- 1
  ran.for.pr[ran.for.pr < "0.5"] <- 0
  confusionmatrix.ran.for <- confusionMatrix(as.factor(ran.for.pr), as.factor(test$DEP_total_affect_binary))
  fourfoldplot(confusionmatrix.ran.for$table, main = "Confusion matrix")
  cm.rf1 <- as.data.frame(confusionmatrix.ran.for[["table"]])[,3]
  cm.rf[,i] <- as.matrix(cm.rf1)
  # Calculate accuracy: 
  accuracy.rf[i] <- confusionmatrix.ran.for[["overall"]][["Accuracy"]]
  # Calculate F1 score: 
  F1.rf[i] <- F1_Score(test$DEP_total_affect_binary, ran.for.pr, positive = "1")
}

# Results of performance metrics: 
apply(AUC.rf, 2, mean)
apply(F1.rf, 2, mean)
apply(accuracy.rf, 2, mean)
rowMeans(cm.rf) # mean confusion matrix 
