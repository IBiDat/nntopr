################################
## Function that automatizes the full process of generating a performance example
## of the method with random normal data and several tunable parameters.
## Author: Pablo Morala
###############################

performExampleAuto <- function(n_sample, p, q_original, mean_range, beta_range, error_var, scale_method, h_1, fun, q_taylor, stepmax = 1e+05) {

  # Generate the data:
  data_generated <- generateNormalData(n_sample, p, q_original, mean_range, beta_range, error_var)
  data <- data_generated$data
  original_betas <- data_generated$original_betas

  #### Scale the data in the desired interval and separate train and test ####

  data_scaled <- scaleData(data, scale_method)
  
  aux <- divideTrainTest(data_scaled, train_proportion = 0.75)
  
  train <- aux$train
  test <- aux$test

  # To use neuralnet we need to create the formula as follows, Y~. does not work. This includes all the variables X:
  var.names <- names(train)
  formula <- as.formula(paste("Y ~", paste(var.names[!var.names %in% "Y"], collapse = " + ")))

  # train the net:
  nn <- neuralnet(formula, data = train, hidden = h_1, linear.output = T, act.fct = fun, stepmax = stepmax)

  # obtain the weights from the NN model:
  w <- t(nn$weights[[1]][[1]]) # we transpose the matrix to match the desired dimensions
  v <- nn$weights[[1]][[2]]

  # Obtain the vector with the derivatives of the activation function up to the given degree:
  g <- rev(taylor(fun, 0, q_taylor))

  # Apply the formula
  coeff <- obtainCoeffsFromWeights(w, v, g)

  # Obtain the predicted values for the test data with our Polynomial Regression
  n_test <- length(test$Y)
  PR.prediction <- rep(0, n_test)

  for (i in 1:n_test) {
    PR.prediction[i] <- evaluatePR(test[i, seq(p)], coeff)
  }

  # Obtain the predicted values with the NN
  NN.prediction <- predict(nn, test)

  # plots to compare results:

  df.plot <- data.frame(test$Y, PR.prediction, NN.prediction)

  plot1 <- ggplot(df.plot, aes(x = NN.prediction, y = test$Y)) +
    geom_point() +
    geom_abline(slope = 1, intercept = 0, color = "red") +
    labs(y = "Original Y") +
    labs(x = "Predicted Y with NN") +
    #ggtitle("NN vs Y") +
    theme(plot.title = element_text(hjust = 0.5)) +
    theme_cowplot(12)

  plot2 <- ggplot(df.plot, aes(x = PR.prediction, y = NN.prediction)) +
    geom_point() +
    geom_abline(slope = 1, intercept = 0, color = "red") +
    labs(y = "Predicted Y with NN") +
    labs(x = "Predicted Y with PR") +
    theme(plot.title = element_text(hjust = 0.5)) +
    #ggtitle("PR vs NN") +
    theme_cowplot(12)

  plot <- plot_grid(plot1, plot2, labels = c("A", "B"))

  # MSE:

  NN.MSE <- sum((test$Y - NN.prediction)^2) / n_test
  PR.MSE <- sum((test$Y - PR.prediction)^2) / n_test

  # MSE between NN and PR (because PR is actually approximating the NN, not the actual response Y)
  MSE.NN.vs.PR <- sum((NN.prediction - PR.prediction)^2) / n_test

  # R squared for the PR, using the train data:

  # Obtain the predicted values for the train data with our Polynomial Regression
  n_train <- length(train$Y)
  PR.prediction.train <- rep(0, n_train)

  for (i in 1:n_train) {
    PR.prediction.train[i] <- evaluatePR(train[i, seq(p)], coeff)
  }

  mean.Y <- mean(train$Y)
  SST <- sum((train$Y - mean.Y)^2)
  SSR <- sum((train$Y - PR.prediction.train)^2)

  PR.R2 <- 1 - (SSR / SST)

  terms <- length(coeff) - 1
  PR.R2.adjusted <- 1 - (1 - PR.R2) * (n_train - 1) / (n_train - terms - 1)



  # Output:

  output <- vector(mode = "list", length = 14)
  output[[1]] <- train
  output[[2]] <- test
  output[[3]] <- g
  output[[4]] <- nn
  output[[5]] <- coeff
  output[[6]] <- NN.prediction
  output[[7]] <- PR.prediction
  output[[8]] <- NN.MSE
  output[[9]] <- PR.MSE
  output[[10]] <- PR.prediction.train
  output[[11]] <- PR.R2
  output[[12]] <- PR.R2.adjusted
  output[[13]] <- plot
  output[[14]] <- MSE.NN.vs.PR
  output[[15]] <- original_betas


  names(output) <- c("train", 
                     "test", 
                     "g", 
                     "nn", 
                     "coeff", 
                     "NN.prediction", 
                     "PR.prediction", 
                     "NN.MSE", 
                     "PR.MSE", 
                     "PR.prediction.train", 
                     "PR.R2", 
                     "PR.R2.adjusted", 
                     "plot", 
                     "MSE.NN.vs.PR", 
                     "original_betas")

  return(output)
}
