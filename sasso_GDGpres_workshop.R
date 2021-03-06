#' ---
#' title: 'Implimenting Popular ML Algorithms in R: Workshop'
#' author: "Katie Sasso"
#' date: '`r format(Sys.Date(), "%B %d, %Y")`'
#' output: 
#'   html_document:
#'     toc: true
#'     toc_float: true
#'     #code_folding: hide
#' ---
#' 
#' ## The Boston Housing Dataset
#' 
#' This dataset contains information collected by the U.S Census Service concerning housing in the area of Boston Mass. 
#' 
#' <div class="column-left">
## ----message=FALSE, warning= FALSE, error=FALSE--------------------------

library(MASS)
library(caret)
boston <- Boston
str(boston)


#' 
#' The Boston data frame conaints the following variables:
#' 
#' - **crim**: per capita crime rate by town.
#' - **zn**:  proportion of residential land zoned for lots over 25,000 sq.ft.
#' - **indus**: proportion of non-retail business acres per town.
#' - **chas**: Charles River dummy variable (= 1 if tract bounds river; 0 otherwise).
#' - **nox**: nitrogen oxides concentration (parts per 10 million).
#' - **rm**: average number of rooms per dwelling.
#' - **age**: proportion of owner-occupied units built prior to 1940.
#' - **dis**: weighted mean of distances to five Boston employment centres.
#' - **rad**: index of accessibility to radial highways.
#' - **tax**: full-value property-tax rate per \$10,000.
#' - **ptratio**: pupil-teacher ratio by town.
#' - **black**: 1000(Bk - 0.63)^2 where Bk is the proportion of African-Americans by town.
#' - **lstat**: lower status of the population (percent).
#' - **medv**: median value of owner-occupied homes in \$1000s.
#'     + Prices are not in error - data is from the 70s
#'     
#'    
#' **We will use various methods to predict the median value of owner-occupied homes in $1000s (medv)**
#' 
#' ### Data Checks
## ----message=FALSE, warning= FALSE, error=FALSE--------------------------

library(purrr)
map_dbl(boston, ~sum(is.na(.)))
# if there were NAs we would need to deal with this in an appropriate manner (list-wise deletion, multiple imputation, etc.)

#Inspect the range of medv
summary(boston$medv)
library(ggplot2)
ggplot(boston, aes(medv)) + geom_histogram(bins = 30)


#' 
#' ## Tools
#' 
#' One quick and easy way to start tackling various machine learning problems is to use a package, like Caret or Scikit (Python) that provide a uniform interface to functions from many different ML libraries/packages:
#' 
#' - These packages provide standardized functions for common tasks (i.e., training, prediction, tuning, variable importance)
#' - Allow you to quickly and easily compare the performance of multiple algorithms
#' 
#' **Cost of Convenience**:
#' 
#' - All tuning parameters available for a given model (i.e., function) may not be immediately obvious when called from packages like these
#'     + e.g., ntree in randomForest package - you can tune it from within caret but have to do so somewhat manually
#' - Important data pre-processing steps for various models/functions may not be as apparent as they are in the source package documentation
#'     + e.g., pre-processing of factor/categorical variables in xgboost
#' - Always wise to be familiar with the function's source documentation
#' 
#' 
#' ### The Caret Package in R
#' 
#' <iframe src = "https://topepo.github.io/caret/index.html", style = "width:900px; height:700px"></iframe>
#' 
#' 
#' ### Scikit in Python
#' 
#' <iframe src = "http://scikit-learn.org/stable/index.html", style = "width:900px; height:700px"></iframe>
#' 
#' ## Data Splitting and Pre-processing
## ----message=FALSE, warning= FALSE, error=FALSE--------------------------
# configure multicore - OPTIONAL
# if parallel backend is loaded and available functions that use it will do so.
# can turn this off in "trainControl" function or simply do  no load parallel backend into session
library(caret)
library(doParallel)
cl <- makeCluster(detectCores()-1)
registerDoParallel(cl)


# use caret’s createDataPartition() function to partition the data into training (70%) and test sets (30%).

seed = set.seed(42)
# ?createDataPartition
index <- createDataPartition(boston$medv, p = 0.7, list = FALSE)
#multiple arguments we can use to customize and create balanced splits of the data. I.e., we can could change the groups argument to adjust the percentile based section that sampling is done within
#We could split based on the predictors, customize splitting for timeseries, or split with consideration to important groups
train <- boston[index, ]
test  <- boston[-index, ]


#' 
#' Several other pre-processing steps may be needed depending on your data and the model used. Caret, for example, provides a broad overview of the usual [pre-processing essentials](https://topepo.github.io/caret/pre-processing.html#creating-dummy-variables). 
#' 
#' Some common cases to look out for:
#' 
#' - Zero- and Near Zero-Variance Predictors
#' - Transforming predictors
#' - Correlated predictors
#' - Converting factors/categorical variables to Dummy Variables (i.e., one-hot encoding)
#'     + If your categorical variable happens to be type integer or numeric (i.e., chas, rad in boston) this may or may not be necessary depending on the number of categories, your question of interest, and what the integer reflects 
#'     + _chas_ variable in our examples is already set up as a dummy variable
#'     + We are going to choose to treat the _rad_ variable (i.e., index of accessibility to radial highways) as numeric since it reflects incremental levels of accessibility to the highway
#'     + if the numbers were not meaningful (i.e., value of 2 was not further from highway than 1) we would want to dummy code this variable
#' 
## ----message=FALSE, warning= FALSE, error=FALSE--------------------------
# several functions available for dummy coding - here is one from Caret package 
# NOTE we would want to do this before train/test split 
library(dplyr)
table(boston$rad)
boston_dummy <- boston %>% 
  mutate(rad = as.factor(rad))

dummies <- dummyVars(medv ~., data = boston_dummy) 
boston_dummy <- as.data.frame(predict(dummies, newdata = boston_dummy))

head(boston_dummy)

#' 
#' ## Bagging & Random Forest
#' 
## ----message=FALSE, warning= FALSE, error=FALSE--------------------------

#Recalling that bagging is a special case of a random forest (with m = p), the randomForest() function can be used to perform both random forests and bagging.
# set m = p (i.e., bagging)

tunegrid <- expand.grid(mtry=ncol(boston)-1)

rf_fit <- train(medv ~ .,
                  data = train,
                  method = "rf",
                  tuneGrid = tunegrid,
                  trControl = trainControl(method = "repeatedcv", # could've also done oob resampling here instead 
                                                  number = 10,  # number of folds
                                                  repeats = 3,  # # of repeats (i.e., 10-fold cross validation with 3 repeats)
                                                  verboseIter = FALSE),
                importance = TRUE) # we don't want to print training log
print(rf_fit)
varImp(rf_fit)


#let's try the typical setting of m - i.e., a random forest 

tunegrid <- expand.grid(mtry=sqrt(ncol(boston))) # just creating a dataframe from all combinations of factor variables. Could've just done data.frame here but should use expand.grid in the event of more than one tuning parameter

#could've also done this
#tunegrid <- data.frame(mtry=sqrt(ncol(boston))) 

rf_fit <- train(medv ~ .,
                  data = train,
                  method = "rf",
                  tuneGrid = tunegrid,
                  trControl = trainControl(method = "repeatedcv", # could've also done oob resampling here instead 
                                                  number = 10,  # number of folds
                                                  repeats = 3,  # repeats
                                                  verboseIter = FALSE),
                importance = TRUE) # we don't want to print training log
print(rf_fit)
varImp(rf_fit)


#visualizing variable importance
imp_df <- bind_rows(varImp(rf_fit)[1]) %>% 
  mutate(var = names(boston[1:13]))
  

imp_df %>%  
  ggplot2::ggplot(aes(x = reorder(var, Overall),Overall)) + 
  geom_bar(stat = "density") +
  coord_flip()

#how good is performance on test set? pretty good!
yhat_rf = predict(rf_fit,newdata=test)
plot(yhat_rf, test$medv)
abline(0,1)


# could've set ntree as well but ability to do so not as apparent as in the source randomForest package - in my opinion
# In caret, could also do a random search for turning parameters (random values within a range)

rf_fit <- train(medv ~ .,
                  data = train,
                  method = "rf",
                  tuneLength = 10,
                  trControl = trainControl(method = "oob", #could've used resampling here instead
                                           number = 10,  
                                           verboseIter = FALSE,# we don't want to print training log
                                           search = 'random'),
                ntree = 25) #try random tuning parameters for all available tuning options. We will set the max number of tuning parameter combos generated from random search with tuneLength

#looks like the sqrt with resampling may have been the best!
print(rf_fit)
#lastly - could've written some of our own code to try several different values of ntree with the optimal mtry value we've identified 

control <- trainControl(method="repeatedcv", number=10, repeats=3, search="grid")
tunegrid <- expand.grid(mtry=c(sqrt(ncol(boston))))
modellist <- list()
for (ntree in c(1000, 1500, 2000, 2500)) {
	set.seed(seed)
	fit <- train(medv ~ ., data=train, method="rf", tuneGrid=tunegrid, trControl=control, ntree=ntree)
	key <- toString(ntree)
	modellist[[key]] <- fit
}
# compare results

results <- resamples(modellist)
summary(results)

#Looks like ntree = 2000 outperforms the default value of 500. 


#' 
#' ### eXtreme Gradient Boosting
## ----message=FALSE, warning= FALSE, error=FALSE--------------------------
# could use library(xgboost) as well in R. 
# impliment the extreme gradient boosting algorithm. Very high predictive accuracy - often used by winners of Kaggle competitions

# it is extremely fast allowing the user to manually specify the number of threads
# includes support for a range of languages including Scala, Java, R, Python, Julia and C++

#Supports distributed and widespread training on many machines that encompass GCE, AWS, Azure and Yarn clusters. XGBoost can also be integrated with Spark, Flink and other cloud dataflow systems with a built in cross validation at each iteration of the boosting process.

#learn more here : https://www.analyticsvidhya.com/blog/2016/03/complete-guide-parameter-tuning-xgboost-with-codes-python/.

#source cred on the above: https://www.analyticsvidhya.com/blog/2017/09/common-machine-learning-algorithms/

# ?xgboost::xgboost


xgb_fit <- train(medv ~ .,
                 data = train, 
                 method = "xgbTree",
                  trControl = trainControl(method = "repeatedcv", 
                                                  number = 10, 
                                                  repeats = 3, 
                                                  verboseIter = FALSE),
                 importance = TRUE)
print(xgb_fit)
varImp(xgb_fit)

 #rm (avg. number of rooms per dwelling) is still by far the most important

#eta is our learning rate or "shrinkage parameter" from slides
# max_depth - number of splits in each tree
# nrounds  - number of iterations (i.e., trees to fit )

#could've tuned variables like before
tunegrid <- expand.grid(nrounds=500, max_depth = 4,eta = 0.3, gamma = 0, colsample_bytree = 1, 
                        min_child_weight = 1, subsample = 1)

xgb_fit <- train(medv ~ .,
                 data = train, 
                 method = "xgbTree",
               #  tuneGrid = tunegrid,
                  trControl = trainControl(method = "repeatedcv", 
                                                  number = 10, 
                                                  repeats = 2, 
                                                  verboseIter = FALSE),
                 importance = TRUE)
print(xgb_fit)

  
	

#' 
#' 
#' ### Neural Net
#' 
## ----message=FALSE, warning= FALSE, error=FALSE--------------------------

#just accepting the defaults

fit_nn <- train(medv ~ .,
                         data = train,
                         method = "neuralnet",
                         trControl = trainControl(method = "repeatedcv", 
                                                  number = 10, 
                                                  repeats = 3, 
                                                  verboseIter = FALSE))
print(fit_nn)
#not a great fit!

#going back to base for layer tweaking ( can do in Caret as well)
n <- names(train)
f <- as.formula(paste("medv ~", paste(n[!n %in% "medv"], collapse = " + ")))
nn <- neuralnet(f,data=train,hidden=c(5,3),linear.output=T)

plot(nn)


#' 
