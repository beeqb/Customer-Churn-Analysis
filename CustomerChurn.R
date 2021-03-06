

# Data Preparation
```{r,message=FALSE}
library(readr)
library(corrplot)
library(datasets)
library(dplyr)

#setwd("~/Users/amaljoy/Study/Data")
#getwd()
RaceData <- read_csv("customer_segmentation_features2.csv", 
                     trim_ws = TRUE)

RaceData$customer_flag <- as.factor(RaceData$customer_flag)
RaceData$current_age <- as.factor(RaceData$current_age)
RaceData$DaysOfCustomer <- as.integer(Sys.Date()-as.Date(RaceData$account_open_date))

#summary(RaceData)
#str(RaceData)

churn_extra_features <- read_csv("churn_extra_features.csv")

# using new method of spread
library(tidyr)
newDataSet <- churn_extra_features %>% 
  gather(variable, value, -(mapping_primary_account_id:period)) %>%
  unite(temp, period, variable) %>%
  spread(temp, value,fill = 0)

# summary(newDataSet)   # keep this in final report
newDataSet <- newDataSet[ , -which(names(newDataSet) %in% c("Last_To_Last_Month_prev_months_active","Last_Month_prev_months_active"))]

library(dplyr)
colnames(newDataSet)[1] <- "mapping_account_id"
colnames(newDataSet) <- make.names(colnames(newDataSet), unique=TRUE)
RaceData <- inner_join(RaceData,newDataSet,by="mapping_account_id")

nrow(filter(RaceData,RaceData$Previous.Months_prev_months_active<1))
# There are  1,946  entries where Previous.Months_prev_months_active = 0. These customers are those who are new to betfair and have been active for less than two months. For the purpose of this analysis we may remove those customers.

#RaceData <- filter(RaceData, Previous.Months_prev_months_active>0)
RaceData <- dplyr::filter(RaceData, revenue>2500)
RaceData <- dplyr::filter(RaceData, Previous.Months_prev_months_active>4)

#summary(RaceData)

RaceData$Previous.Months_lost_bets <- RaceData$Previous.Months_lost_bets/RaceData$Previous.Months_prev_months_active
RaceData$Previous.Months_num_of_days_bet <- RaceData$Previous.Months_num_of_days_bet/RaceData$Previous.Months_prev_months_active
RaceData$Previous.Months_profit_loss <- RaceData$Previous.Months_profit_loss/RaceData$Previous.Months_prev_months_active
RaceData$Previous.Months_revenue <- RaceData$Previous.Months_revenue/RaceData$Previous.Months_prev_months_active
RaceData$Previous.Months_total_bets <- RaceData$Previous.Months_total_bets/RaceData$Previous.Months_prev_months_active
RaceData$Previous.Months_turnover <- RaceData$Previous.Months_turnover/RaceData$Previous.Months_prev_months_active

rm(churn_extra_features,newDataSet)


RaceData$lost_bets1 <- (RaceData$Last_Month_lost_bets / RaceData$Previous.Months_lost_bets)
RaceData$lost_bets2 <- (RaceData$Last_To_Last_Month_lost_bets / RaceData$Previous.Months_lost_bets)
RaceData$num_of_days_bet1 <- (RaceData$Last_Month_num_of_days_bet / RaceData$Previous.Months_num_of_days_bet)
RaceData$num_of_days_bet2 <- (RaceData$Last_To_Last_Month_num_of_days_bet / RaceData$Previous.Months_num_of_days_bet)
RaceData$profit_loss1 <- (RaceData$Last_Month_profit_loss / RaceData$Previous.Months_profit_loss)
RaceData$profit_loss2 <- (RaceData$Last_To_Last_Month_profit_loss / RaceData$Previous.Months_profit_loss)
RaceData$revenue1 <- (RaceData$Last_Month_revenue  / RaceData$Previous.Months_revenue)
RaceData$revenue2 <- (RaceData$Last_To_Last_Month_revenue / RaceData$Previous.Months_revenue)
RaceData$total_bets1 <- (RaceData$Last_Month_total_bets  / RaceData$Previous.Months_total_bets)
RaceData$total_bets2 <- (RaceData$Last_To_Last_Month_total_bets / RaceData$Previous.Months_total_bets)
RaceData$turnover1 <- (RaceData$Last_Month_turnover  / RaceData$Previous.Months_turnover)
RaceData$turnover2 <- (RaceData$Last_To_Last_Month_turnover / RaceData$Previous.Months_turnover)


## Collecting required attributes
DataSet <-subset(RaceData, select= c(
  #                               current_age,
  #                      DaysOfCustomer,
  ###total_bets,
  ###lost_bets,
  ###revenue,
  #                      back_bets,
  #                      inplay_bets,
  ###back_turnover,
  ###inplay_turnover,
  #                       avg_discount_rate,
  #                      age_at_signup,
  
  
  #                        lost_bets1, 
  #                        lost_bets2, 
  num_of_days_bet1, 
  #                        num_of_days_bet2, 
  profit_loss1, 
  profit_loss2, 
  #                        revenue1, 
  #                        revenue2, 
  total_bets1, 
  total_bets2, 
  turnover1, 
  turnover2,
  
  customer_flag
))


#str(DataSet) # keep this in final report
table(is.na(DataSet))  # keep this in final report
rm(RaceData)

## check the source of NA
# table(is.na(DataSet$post_code))

## remove postcode from the model
# DataSet <-subset(DataSet, select= -post_code)

# table(is.na(DataSet)) # NO 'NA'!!! WOW




# MLR Package

library(mlr)
library(randomForest)
library(caret)
library(rpart)

DataSet$customer_flag <- as.factor(DataSet$customer_flag)


set.seed(5342)
rdesc <- makeResampleDesc("CV", iters = 2, predict = 'both')

## Creating training and Testing dataset

Split<-0.75
SplitIndex <- sample.int(nrow(DataSet), round(nrow(DataSet) * Split))
TrainingData <- DataSet[SplitIndex,]
TestingData <- DataSet[-SplitIndex,]

classif.task <- makeClassifTask(id = "customer_flag", data = TrainingData, target = "customer_flag",positive = "Active")


```

#  Modelling
```{r,message=FALSE,warning=FALSE}
## oversampling and undersampling the data
#task.over = oversample(classif.task, rate = 2)
#task.under = undersample(classif.task, rate = 1/2)
#table(getTaskTargets(classif.task))
#table(getTaskTargets(task.over))
#table(getTaskTargets(task.under))

#classif.task <- task.under # lets go with over-sampling now
#getTaskDesc(classif.task)
#rm(task.under,task.over)

## Making the learner
library(data.table)
lrns = as.data.table(listLearners())
#View(lrns)

library(kknn)
library(gbm)
library(e1071)
library(xgboost)

classif.lrn.knn <- makeLearner(cl = "classif.kknn", predict.type = "prob") # 57% accuracy
classif.lrn.ksvm <- makeLearner(cl = "classif.ksvm", predict.type = "prob") # 63% accuracy,  fp
classif.lrn.lda <- makeLearner(cl = "classif.lda", predict.type = "prob") # 57% accuracy
classif.lrn.gbm <- makeLearner(cl = "classif.gbm", predict.type = "prob")  # 58% accuracy
classif.lrn.nnet <- makeLearner(cl = "classif.nnet", predict.type = "prob") # 54% accuracy
classif.lrn.svm <- makeLearner(cl = "classif.svm", predict.type = "prob") # 62% accuracy, 989 fp
classif.lrn.xgb <- makeLearner(cl = "classif.xgboost", predict.type = "prob") # % accuracy need to convert to numerics
classif.lrn.rpart <- makeLearner(cl = "classif.rpart", predict.type = "prob") # 57% accuracy
classif.lrn.rf <- makeLearner(cl = "classif.randomForest", predict.type = "prob") # # 67% accuracy, 802 fp I trust the Forest

list <- c("kknn","ksvm","lda","Gradient Boosting Machine","neural network","svm","rpart","random Forest")

#set parallel backend
library(parallel)
library(parallelMap) 
parallelStartSocket(cpus = detectCores())

classif.lrn1 <- classif.lrn.knn
classif.lrn2 <- classif.lrn.ksvm
classif.lrn3 <- classif.lrn.lda
classif.lrn4 <- classif.lrn.gbm
classif.lrn5 <- classif.lrn.nnet
classif.lrn6 <- classif.lrn.svm
classif.lrn7 <- classif.lrn.rpart
classif.lrn8 <- classif.lrn.rf

j=1:8

library(foreach)
for (i in j) { 
  classif.lrn <- (get(paste("classif.lrn", i, sep=""))) 
  
  #head(lrns[c("class", "package")])
  
  ## Creating the model
  assign(paste("mod",i, sep=""), mlr::train( classif.lrn, classif.task))
  print(get(paste("mod", i, sep=""))) 
  
  ## Prediction
  # may be there is no need of this prediction now
  
  assign(paste("pred",i, sep=""), predict(get(paste("mod", i, sep="")), newdata = TestingData))
  
  #listMeasures( classif.task)
  
  print(performance(get(paste("pred", i, sep="")),measure = list(mlr::fp, mlr::auc, mlr::mmce)))
  print(calculateConfusionMatrix(get(paste("pred", i, sep=""))))
  
  #pred$threshold
  
  #pred <- setThreshold(pred, 0.5)
  #pred$threshold
  
  #d <- generateThreshVsPerfData(pred, measures = mmce)
  #plotThreshVsPerf(d)
  
}


# creating a data table of mmce values
mmce <- data.table(
  Model=list[j],
  Predictor=foreach (i = j, .combine="c") %do% 
    paste("pred", i, sep=""),
  mmce=foreach (i = j, .combine="c") %do% 
    print(performance(get(paste("pred", i, sep="")))),
  Accuracy=foreach (i = j, .combine="c") %do% 
    print(performance(get(paste("pred", i, sep="")),measure = mlr::acc)),
  False_Positive=foreach (i = j, .combine="c") %do% 
    print(performance(get(paste("pred", i, sep="")),measure = mlr::fp))
)

View(mmce)
```


# Resampling
```{r}
set.seed(509)
rdesc <- makeResampleDesc("CV", iters = 3, predict = 'both')

classif.task <- makeClassifTask(id = "customer_flag", data = DataSet, target = "customer_flag",positive = "Active")

r <- resample("classif.randomForest", classif.task, rdesc)
r$aggr
r$measures.test
r$measures.train
```
Data Set after calculations

# Hyper Parametric Tuning (rpart)
```{r}

library(mlrHyperopt)
res = hyperopt(classif.task, learner = "classif.rpart")
res

classif.task <- makeClassifTask(id = "customer_flag", data = TrainingData, target = "customer_flag",positive = "Active")
classif.lrn <- makeLearner(cl = "classif.rpart", predict.type = "prob")

# Setting the parameters to the learner
classif.lrn.hyper <- setHyperPars(learner = classif.lrn,par.vals = res$x)
mod1 <- mlr::train( classif.lrn.hyper, classif.task)

# Prediction
pred <- predict(mod1, newdata = TestingData)
# Performance Evaluation
performance(pred, measure = list(mlr::fp,mlr:: mmce))
calculateConfusionMatrix(pred)
# Resampling
set.seed(300)
rdesc <- makeResampleDesc("CV", iters = 3, predict = 'both')
r.Hyper <- resample("classif.randomForest", classif.task, rdesc)
r.Hyper$aggr
r.Hyper$measures.test
r.Hyper$measures.train

```


# Hyper Parametric Tuning (Random Forest)
```{r}

ps =  makeParamSet(
  makeIntegerParam("ntree",lower=100, upper=300),
  makeIntegerParam("mtry",lower=3, upper=30))

ctrl =  makeTuneControlRandom(maxit = 10L)
rdesc = makeResampleDesc("CV", iters = 3L,predict = 'both')

classif.task <- makeClassifTask(id = "customer_flag", data = TrainingData, target = "customer_flag",positive = "Active")
classif.lrn <- makeLearner(cl = "classif.randomForest", predict.type = "prob")

parallelStop() 
parallelStartSocket(4)

res =   tuneParams("classif.randomForest", 
                   task = classif.task, 
                   control = ctrl,
                   measures = list(mlr::mmce), 
                   resampling = rdesc, 
                   par.set = ps, show.info = TRUE)

generateHyperParsEffectData(res, trafo = T, include.diagnostics = FALSE)

# Setting the parameters to the learner
classif.lrn.hyper <- setHyperPars(learner = classif.lrn,par.vals = res$x)
mod1 <- mlr::train( classif.lrn.hyper, classif.task)

# Prediction
pred <- predict(mod1, newdata = TestingData)
# Performance Evaluation
performance(pred, measure = list(mlr::fp, mlr::mmce))
calculateConfusionMatrix(pred)
# Resampling
set.seed(200)
rdesc <- makeResampleDesc("CV", iters = 3, predict = 'both')
r.Hyper <- resample("classif.randomForest", classif.task, rdesc)
r.Hyper$aggr
r.Hyper$measures.test
r.Hyper$measures.train
```


```{r}
#lrns <- makeLearner(cl = "classif.rpart", predict.type = "prob")
lrns = c("classif.rpart", "classif.randomForest")
lrns = makeLearners(lrns)
tsk = classif.task
rr = makeResampleDesc('CV', stratify = TRUE, iters = 5)
lrns.tuned = lapply(lrns, function(lrn) {
  if (getLearnerName(lrn) == "xgboost") {
    # for xgboost we download a custom ParConfig from the Database
    pcs = downloadParConfigs(learner.name = getLearnerName(lrns))
    pc = pcs[[1]]
  } else {
    pc = getDefaultParConfig(learner = lrns)
  }
  ps = getParConfigParSet(pc)
  # some parameters are dependend on the data (eg. the number of columns)
  ps = evaluateParamExpressions(ps, dict = mlrHyperopt::getTaskDictionary(task = tsk))
  lrn = setHyperPars(lrn, par.vals = getParConfigParVals(pc))
  ctrl = makeTuneControlRandom(maxit = 3)
  makeTuneWrapper(learner = lrn, resampling = rr, par.set = ps, control = ctrl)
})
res = benchmark(learners = c(lrns, lrns.tuned), tasks = tsk, resamplings = cv5)
plotBMRBoxplots(res) 
```


# mlrHyperOpt
```{r}
## tuning in one line
# devtools::install_github("berndbischl/ParamHelpers") # version >= 1.11 needed.
# devtools::install_github("jakob-r/mlrHyperopt", dependencies = TRUE)
library(mlrHyperopt)
library(parallel)
library(parallelMap) 
parallelStartSocket(cpus = detectCores())
res = hyperopt(classif.task, learner = "classif.randomForest",show.info = TRUE)
res


## full configuration
pc = generateParConfig(learner = "classif.randomForest")
# The tuning parameter set:
getParConfigParSet(pc)
# Setting constant values:
pc = setParConfigParVals(pc, par.vals = list(mtry = 3))
hc = generateHyperControl(task = classif.task, par.config = pc)
# Inspecting the resamling strategy used for tuning
getHyperControlResampling(hc)
# Changing the resampling strategy
hc = setHyperControlResampling(hc, makeResampleDesc("Bootstrap", iters = 3))
# Starting the hyperparameter tuning
res = hyperopt(classif.task, par.config = pc, hyper.control = hc, show.info = TRUE)
res
```


## Try some XGBoost
```{r}
lrns = c("classif.xgboost", "classif.randomForest")
lrns = makeLearners(lrns)
tsk = classif.task
rr = makeResampleDesc('CV', stratify = TRUE, iters = 3)
lrns.tuned = lapply(lrns, function(lrn) {
  if (mlrHyperopt::getLearnerName(lrn) == "xgboost") {
    # for xgboost we download a custom ParConfig from the Database
    pcs = mlrHyperopt::downloadParConfigs(learner.name = mlrHyperopt::getLearnerName(lrn))
    pc = pcs[[1]]
  } else {
    pc = getDefaultParConfig(learner = lrn)
  }
  ps = getParConfigParSet(pc)
  # some parameters are dependend on the data (eg. the number of columns)
  ps = evaluateParamExpressions(ps, dict = mlrHyperopt::getTaskDictionary(task = tsk))
  lrn = setHyperPars(lrn, par.vals = getParConfigParVals(pc))
  ctrl = makeTuneControlRandom(maxit = 5)
  makeTuneWrapper(learner = lrn, resampling = rr, par.set = ps, control = ctrl)
})
TrainingData$current_age <- as.numeric(TrainingData$current_age)
TrainingData$customer_flag <- as.factor(TrainingData$customer_flag)
classif.task <- makeClassifTask(id = "customer_flag", data = TrainingData, target = "customer_flag")


res = benchmark(learners = c(lrns, lrns.tuned), tasks = tsk, resamplings = cv10)
plotBMRBoxplots(res)

```


```{r}
#set parallel backend
library(parallel)
library(parallelMap) 
parallelStartSocket(cpus = detectCores())

classif.task <- makeClassifTask(id = "customer_flag", data = TrainingData, target = "customer_flag")
task.over = oversample(classif.task, rate = 3)
classif.task <- task.over
classif.task
classif.lrn <- makeLearner(cl = "classif.randomForest", predict.type = "prob")
classif.lrn$par.set

# spliting using mlr
set.seed(300)
n = getTaskSize(classif.task)
train.set = sample(n, size = n*3/4)

TrainingData <- DataSet[train.set,]
TestingData <- DataSet[-train.set,]

#mod <- mlr::train( classif.lrn, classif.task,subset = train.set)
mod <- mlr::train( classif.lrn, classif.task)

pred <- predict(mod, newdata = TestingData)

performance(pred, measure = list(fp, mmce))
calculateConfusionMatrix(pred)

rdesc <- makeResampleDesc("CV", iters = 3, predict = 'both')

r <- resample("classif.randomForest", classif.task, rdesc)
r$aggr
r$measures.test
r$measures.train

ps = makeParamSet(
  makeNumericParam("mtry", lower = -5, upper = 5, trafo = function(x) 2^x)
)
ctrl = makeTuneControlRandom(maxit = 3L)
rdesc = makeResampleDesc("CV", iters = 2L,predict = 'both')
res = tuneParams("classif.randomForest", task = classif.task, control = ctrl,
                 measures = list(acc, mmce), resampling = rdesc, par.set = ps, show.info = FALSE)
generateHyperParsEffectData(res, trafo = T, include.diagnostics = FALSE)


```


## Random Search
```{r}
# Random Search
control <- trainControl(method="repeatedcv", number=10, repeats=3, search="random")
set.seed(300)
mtry <- sqrt(ncol(TrainingData))
rf_random <- train(customer_flag~., data=TrainingData, method="rf", metric=metric, tuneLength=15, trControl=control)
print(rf_random)
plot(rf_random)

```


## Dealing with the data imbalance
```{r}
# Smote
parallelStartSocket(cpus = detectCores())

task.smote = smote(classif.task, rate = 3, nn = 5)
table(getTaskTargets(classif.task))
table(getTaskTargets(task.smote))
classif.lrn <- makeLearner(cl = "classif.randomForest", predict.type = "prob")
modSmote <- mlr::train( classif.lrn, task.smote)
pred <- predict(modSmote, newdata = TestingData)

performance(pred, measure = list(fp, mmce))
calculateConfusionMatrix(pred)


# Smote Wrapper
classif.lrn <- makeLearner(cl = "classif.randomForest", predict.type = "prob")
lrn.smote = makeSMOTEWrapper(classif.lrn, sw.rate = 3, sw.nn = 5)
modSmoteWrapper <- mlr::train( lrn.smote, classif.task)
performance(predict(modSmoteWrapper, newdata = TestingData), measures = list(mmce, ber, auc))


# Overbagging
classif.lrn = setPredictType(classif.lrn, "response")
obw.lrn = makeOverBaggingWrapper(classif.lrn, obw.rate = 3, obw.iters = 3)
classif.lrn = setPredictType(classif.lrn, "prob")
obw.lrn = setPredictType(classif.lrn, "prob")
rOverbagging = resample(learner = obw.lrn, task = classif.task, resampling = rdesc, show.info = TRUE,
                        measures = list(mmce, ber,auc))
rOverbagging$aggr

```

# Correlation Diagrams for checking the Data
```{r}
## Plotting the correlation
require(psych)

#NumericalSet <-subset(DataSet, select= -c(current_age))
NumericalSet <-DataSet
NumericalSet$ActiveStatus <- ifelse(NumericalSet$customer_flag=='Active',1,0)
NumericalSet <-subset(NumericalSet, select= -c(customer_flag))

#colnames(NumericalSet) = c("back_bets", "inplay_bets", "avg_dis_rt", "L.M_lst_bet", "L.L.M_lst_bet", "P.M_lst_bets", "L.M_days", "L.L.M_days", "P.M_days", "L.M_p/l", "L.L.M_p/l", "P.M_p/l", "L.M_rev", "L.L.M_rev", "P.M_rev", "L.M_tot_bet", "L.L.M_tot_bet", "P.M_tot_bet", "L.M_t/o", "L.L.M_t/o", "P.M_t/o", "P.M_act", "ActStatus")

cor_data <- cor(NumericalSet)

## Customizing the correlogram
col <- colorRampPalette(c("#BB4444", "#EE9988", "#FFFFFF", "#77AADD", "#4477AA"))
p.mat <- cor.mtest(cor_data)$p
corrplot(cor_data, method = "color", col = col(200),
         type = "upper", order = "hclust", number.cex = .7,
         addCoef.col = "black", # Add coefficient of correlation
         tl.col = "black", tl.srt = 90, # Text label color and rotation
         # Combine with significance
         p.mat = p.mat, sig.level = 0.01, insig = "blank", 
         # hide correlation coefficient on the principal diagonal
         diag = FALSE)

rm(p.mat,col)

## Removing unwanted variables

## checking correlation again


rm(NumericalSet,cor_data)

```


