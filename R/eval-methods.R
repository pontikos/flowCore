##===========================================================================
## Eval methods for evaluating transformation objects 
## ---------------------------------------------------------------------------


## Helper function to fully resolve all transformationReferences
resolve <- function(x, df)
{
    if(!is(x, "transformReference"))
        eval(x)(df) else resolveTransformReference(x, df)  
}



## ===========================================================================
## Unity transformation
## ---------------------------------------------------------------------------
setMethod("eval",
          signature=signature(expr="unitytransform", envir="missing"),
          definition=function (expr, envir = parent.frame(),
              enclos=if (is.list(envir) ||
                is.pairlist(envir)) parent.frame() else baseenv())
          {        
              function(df) 
              {
                  df <- flowFrameToMatrix(df)
                  return(df[, expr@parameters, drop=FALSE]) 
              }
          })


## ===========================================================================
## Polynomial transformation of degree 1
## ---------------------------------------------------------------------------

setMethod("eval",
	  signature=signature(expr="dg1polynomial", envir="missing"),
          definition=function (expr, envir = parent.frame(),
              enclos=if (is.list(envir) ||
                is.pairlist(envir)) parent.frame() else baseenv())
          {    
            function(df)
              {   
                par <- expr@parameters
                temp <- sapply(par,function(i){
                  if(is(i, "function")) return(i)
                  resolve(i, df)
                })
                temp <- flowFrameToMatrix(temp)
                coeff <- expr@a
                res <- 0
                for(i in seq_along(expr@parameters))
                  res <- res + temp[,i,drop=FALSE]*coeff[i]
                res <- res+expr@b
              }
          })


## ===========================================================================
## Ratio transformation of two arguments
## ---------------------------------------------------------------------------
setMethod("eval", 
          signature=signature(expr="ratio", envir="missing"),
          definition=function (expr, envir = parent.frame(),
              enclos=if (is.list(envir) ||
                is.pairlist(envir)) parent.frame() else baseenv())
      { 
          function(df)
          {  
              num <- resolve(expr@numerator, df)
              den <- resolve(expr@denominator, df)
			  num <- flowFrameToMatrix(num)
			  den <- flowFrameToMatrix(den)
              num/den
          }
      })


## ===========================================================================
## Quadratic transformation 
## ---------------------------------------------------------------------------
setMethod("eval", 
	  signature=signature(expr="quadratic", envir="missing"),
          definition=function (expr, envir = parent.frame(),
              enclos=if (is.list(envir) ||
                is.pairlist(envir)) parent.frame() else baseenv())
      {    
          function(df)
          {      
              parameter <- resolve(expr@parameters, df)
			  parameter <- flowFrameToMatrix(parameter)
              expr@a*(parameter^2)
          }
      })


## ===========================================================================
## Squareroot transformation 
## ---------------------------------------------------------------------------
setMethod("eval", 
	  signature=signature(expr="squareroot", envir="missing"),
          definition=function (expr, envir = parent.frame(),
              enclos=if (is.list(envir) ||
                is.pairlist(envir)) parent.frame() else baseenv())
      {
          function(df)
          {
              parameter <- resolve(expr@parameters, df)
			  parameter <- flowFrameToMatrix(parameter)
              sqrt(abs(parameter/(expr@a)))
          }
      })



## ===========================================================================
## Log transformation 
## ---------------------------------------------------------------------------
setMethod("eval", 
	  signature=signature(expr="logarithm", envir="missing"),
          definition=function (expr, envir = parent.frame(),
              enclos=if (is.list(envir) ||
                is.pairlist(envir)) parent.frame() else baseenv())
      {    
          function(df)
          {
              parameter <- resolve(expr@parameters, df)
			  parameter <- flowFrameToMatrix(parameter)
              temp <- expr@a*parameter
              result <- vector(mode="numeric", length=length(temp))
              result[temp>0] <- log(temp[temp>0])*expr@b
              return(result)
          }
      })  


## ===========================================================================
## Exponential transformation 
## ---------------------------------------------------------------------------
setMethod("eval", 
          signature=signature(expr="exponential", envir="missing"),
          definition=function (expr, envir = parent.frame(),
              enclos=if (is.list(envir) ||
                is.pairlist(envir)) parent.frame() else baseenv())
      {
          function(df)
          {
              parameter <- resolve(expr@parameters, df)
			  parameter <- flowFrameToMatrix(parameter)
              exp(parameter/expr@b)/expr@a
          }
      })


## ===========================================================================
## Inverse hyperbolic sin transformation 
## ---------------------------------------------------------------------------
setMethod("eval", 
          signature=signature(expr="asinht", envir="missing"),
          definition=function (expr, envir = parent.frame(),
              enclos=if (is.list(envir) ||
                is.pairlist(envir)) parent.frame() else baseenv())
      {    
          function(df)
          {
              parameter <- resolve(expr@parameters, df)
			  parameter <- flowFrameToMatrix(parameter)
              expr@b*asinh(expr@a*parameter)
          }
      })

## ================================================================================
## Inverse hyperbolic sin transformation parametrized according to Gating-ML 2.0 
## --------------------------------------------------------------------------------
setMethod(
    "eval", 
    signature = signature(expr = "asinhtGml2", envir = "missing"),
    definition = function(
        expr, 
        envir = parent.frame(),
        enclos = if (is.list(envir) || is.pairlist(envir)) parent.frame() else baseenv())
    {    
        function(df)
        {
            if(is(df, "flowFrame")){
              parameter <- resolve(expr@parameters, df)
              parameter <- flowFrameToMatrix(parameter)  
            }else
              parameter <- df
            
            # Gating-ML 2.0 fasinh is defined as
            # (asinh(x * sinh(M * log(10)) / T) + A * log(10)) / ((M + A) * log(10))
            #
            # (asinh(parameter * sinh(expr@M * log(10)) / expr@T) + expr@A * log(10)) / ((expr@M + expr@A) * log(10))
            #
            # The previous 'direct' implementation seems to work just fine for me; however,
            # Wayne Moore suggested, that following calculation may be more stable:
            # (it is giving the same results based on my tests)
            myB = (expr@M + expr@A) * log(10)
            myC = expr@A * log(10)
            myA = expr@T / sinh(myB - myC)
            x = parameter / myA
            # This formula for the arcsinh loses significance when x is negative
            # Therefore we take advantage of the fact that sinh is an odd function
            negative = x < 0
            x[negative] = -x[negative]
            asinhx = log(x + sqrt(x * x + 1))
            res = rep(NA, times=length(asinhx))
            res[negative] = (myC - asinhx[negative]) / myB
            res[!negative] = (asinhx[!negative] + myC) / myB

            # New in Gating-ML 2.0: this transformation has an optional boundary, i.e.,
            # if the result is less than boundMin, then let it be boundMin; if the
            # result is more than boundMax, then let it be boundMax. Defaults for
            # boundMin and boundMax are -Inf and Inf.
            if(!is.infinite(expr@boundMax)||!is.infinite(expr@boundMin))
              res <- sapply(res, function(x) max(min(x,expr@boundMax),expr@boundMin))
            
            res
        }
    }
)

## ================================================================================
## Logicle transformation parametrized according to Gating-ML 2.0
## --------------------------------------------------------------------------------
setMethod(
    "eval",
    signature = signature(expr = "logicletGml2", envir = "missing"),
    definition = function(
        expr,
        envir = parent.frame(),
        enclos = if (is.list(envir) || is.pairlist(envir)) parent.frame() else baseenv())
    {
        function(df)
        {
            parameter <- resolve(expr@parameters, df)
            parameter <- flowFrameToMatrix(parameter)
            # We are calling the externa logicle transformation, but we are also
            # dividing the result by M so that "reasonable" values are scaled [0,1]
            # rather than [0,M]. This is how logicle in Gating-Ml 2.0 is defined.
            res <- .Call("logicle_transform", as.double(parameter), as.double(expr@T),
                as.double(expr@W), as.double(expr@M), as.double(expr@A)) / expr@M

            # New in Gating-ML 2.0: this transformation has an optional boundary, i.e.,
            # if the result is less than boundMin, then let it be boundMin; if the
            # result is more than boundMax, then let it be boundMax. Defaults for
            # boundMin and boundMax are -Inf and Inf.
        
            if(!is.infinite(expr@boundMax)||!is.infinite(expr@boundMin))
              res <- sapply(res, function(x) max(min(x,expr@boundMax),expr@boundMin))
            
            res
        }
    }
)


## ================================================================================
## Hyperlog transformation parametrized according to Gating-ML 2.0
## --------------------------------------------------------------------------------
setMethod(
    "eval",
    signature = signature(expr = "hyperlogtGml2", envir = "missing"),
    definition = function(
        expr,
        envir = parent.frame(),
        enclos = if (is.list(envir) || is.pairlist(envir)) parent.frame() else baseenv())
    {
        function(df)
        {
            parameter <- resolve(expr@parameters, df)
            parameter <- flowFrameToMatrix(parameter)
            res <- .Call("hyperlog_transform", as.double(parameter), as.double(expr@T),
                as.double(expr@W), as.double(expr@M), as.double(expr@A))

            # New in Gating-ML 2.0: this transformation has an optional boundary, i.e.,
            # if the result is less than boundMin, then let it be boundMin; if the
            # result is more than boundMax, then let it be boundMax. Defaults for
            # boundMin and boundMax are -Inf and Inf.
            if(!is.infinite(expr@boundMax)||!is.infinite(expr@boundMin))
              res <- sapply(res, function(x) max(min(x,expr@boundMax),expr@boundMin))
            
            res
        }
    }
)


## ================================================================================
## Linear transformation parametrized according to Gating-ML 2.0
## --------------------------------------------------------------------------------
setMethod(
    "eval",
    signature = signature(expr = "lintGml2", envir = "missing"),
    definition = function(
        expr,
        envir = parent.frame(),
        enclos = if (is.list(envir) || is.pairlist(envir)) parent.frame() else baseenv())
    {
        function(df)
        {
            parameter <- resolve(expr@parameters, df)
            parameter <- flowFrameToMatrix(parameter)
            # Gating-ML 2.0 flin is defined as
            # (x + A) / (T + A)
            res <- (parameter + expr@A) / (expr@T + expr@A)

            # New in Gating-ML 2.0: this transformation has an optional boundary, i.e.,
            # if the result is less than boundMin, then let it be boundMin; if the
            # result is more than boundMax, then let it be boundMax. Defaults for
            # boundMin and boundMax are -Inf and Inf.
            if(!is.infinite(expr@boundMax)||!is.infinite(expr@boundMin))
              res <- sapply(res, function(x) max(min(x,expr@boundMax),expr@boundMin))
            
            res
        }
    }
)

## ================================================================================
## Log transformation parametrized according to Gating-ML 2.0
## --------------------------------------------------------------------------------
setMethod(
    "eval",
    signature = signature(expr = "logtGml2", envir = "missing"),
    definition = function(
        expr,
        envir = parent.frame(),
        enclos = if (is.list(envir) || is.pairlist(envir)) parent.frame() else baseenv())
    {
        function(df)
        {
            parameter <- resolve(expr@parameters, df)
            parameter <- flowFrameToMatrix(parameter)
            # Gating-ML 2.0 flog is defined as
            # (1/M) * log_10(x/T) + 1
            res <- ((1/expr@M) * log((parameter/expr@T), base=10)) + 1

            # New in Gating-ML 2.0: this transformation has an optional boundary, i.e.,
            # if the result is less than boundMin, then let it be boundMin; if the
            # result is more than boundMax, then let it be boundMax. Defaults for
            # boundMin and boundMax are -Inf and Inf.
            if(!is.infinite(expr@boundMax)||!is.infinite(expr@boundMin))
              res <- sapply(res, function(x) max(min(x,expr@boundMax),expr@boundMin))
            
            res
        }
    }
)


## ===========================================================================
## Ratio transformation parametrized according to Gating-ML 2.0
## ---------------------------------------------------------------------------
setMethod(
    "eval",
    signature = signature(expr = "ratiotGml2", envir="missing"),
    definition = function(
        expr,
        envir = parent.frame(),
        enclos = if(is.list(envir) || is.pairlist(envir)) parent.frame() else baseenv())
    {
        function(df)
        {
            num <- resolve(expr@numerator, df)
            den <- resolve(expr@denominator, df)
            num <- flowFrameToMatrix(num)
            den <- flowFrameToMatrix(den)
            # Gating-ML 2.0 fratio is defined as
            # fratio(x, y, A, B, C) = A * (x - B) / (y - C)
            res <- expr@pA * (num - expr@pB) / (den - expr@pC)

            # New in Gating-ML 2.0: this transformation has an optional boundary, i.e.,
            # if the result is less than boundMin, then let it be boundMin; if the
            # result is more than boundMax, then let it be boundMax. Defaults for
            # boundMin and boundMax are -Inf and Inf.
            if(!is.infinite(expr@boundMax)||!is.infinite(expr@boundMin))
              res <- sapply(res, function(x) max(min(x,expr@boundMax),expr@boundMin))
            
            res
        }
    }
)


## ===========================================================================
## Hyperbolic sin transformation 
## ---------------------------------------------------------------------------
setMethod("eval", 
          signature=signature(expr="sinht", envir="missing"),
          definition=function (expr, envir = parent.frame(),
              enclos=if (is.list(envir) ||
                is.pairlist(envir)) parent.frame() else baseenv())
      {
          function(df)
          {
              parameter <- resolve(expr@parameters, df)
			  parameter <- flowFrameToMatrix(parameter)
              sinh(parameter/(expr@b))/expr@a
          }
      }) 


## ===========================================================================
## Hyperlog transformation 
## ---------------------------------------------------------------------------


setMethod("eval", 
	  signature=signature(expr="hyperlog", envir="missing"),
          definition=function (expr, envir = parent.frame(),
              enclos=if (is.list(envir) ||
                is.pairlist(envir)) parent.frame() else baseenv())
	  {    
            function(df)
              {  
                  parameter <- resolve(expr@parameters, df)
				  parameter <- flowFrameToMatrix(parameter)
                  solveEH(parameter , expr@a ,expr@b)
               }
	  })

## ===========================================================================
## EH transformation 
## ---------------------------------------------------------------------------

setMethod("eval", 
	  signature=signature(expr="EHtrans", envir="missing"),
          definition=function (expr, envir = parent.frame(),
              enclos=if (is.list(envir) ||
                is.pairlist(envir)) parent.frame() else baseenv())
	  {    
            function(df)
              {  
                  parameter <- resolve(expr@parameters, df)
				  parameter <- flowFrameToMatrix(parameter)
                  result=0
                  result[parameter>=0]=10^(parameter/expr@a)+ (expr@b*parameter)/expr@a-1
                  result[parameter<0]= -1*(10^(-parameter/expr@a))+ (expr@b*parameter)/expr@a+1
                  return(matrix(result))
              }
	  })


## ===========================================================================
## Splitscale transformation 
## ---------------------------------------------------------------------------
setMethod("eval", 
          signature=signature(expr="splitscale", envir="missing"),
          definition=function (expr, envir = parent.frame(),
              enclos=if (is.list(envir) ||
                is.pairlist(envir)) parent.frame() else baseenv())
      {    
          function(df)
          {
              parameter <- resolve(expr@parameters, df)
			  parameter <- flowFrameToMatrix(parameter)
              transitionChannel <- expr@transitionChannel
              r <- expr@r
              maxValue <- expr@maxValue
              b <- transitionChannel/2
              d <- 2*r*log10(2.71828)/transitionChannel
              log10t <- -2*log10(2.71828)*r/transitionChannel +log10(maxValue)
              t <- 10^(log10t)
              a <- transitionChannel/(2*t)
              log10ct <- (a*t+b)*d/r
              c <- (10^log10ct)/t
              idx <- which(parameter <= t)
              idx2 <- which(parameter > t)
              if(length(idx2)>0)
                  parameter[idx2] <- log10(c*parameter[idx2])*r/d
              if(length(idx)>0)
                  parameter[idx] <- a*parameter[idx]+b
              parameter
          }
      })


## ===========================================================================
## Inverse Splitscale transformation 
## ---------------------------------------------------------------------------
setMethod("eval", 
          signature=signature(expr="invsplitscale", envir="missing"),
          definition=function (expr, envir = parent.frame(),
              enclos=if (is.list(envir) ||
                is.pairlist(envir)) parent.frame() else baseenv())
      {    
          function(df)
          {
              parameter <- resolve(expr@parameters, df)
			  parameter <- flowFrameToMatrix(parameter)
              transitionChannel <- expr@transitionChannel
              r <- expr@r
              maxValue <- expr@maxValue
              b <- transitionChannel/2
              d <- 2*r*log10(2.71828)/transitionChannel
              log10t <- -2*log10(2.71828)*r/transitionChannel +log10(maxValue)
                  t <- 10^(log10t)
                  a <- transitionChannel/(2*t)
                  log10ct <- (a*t+b)*d/r
                  c <- (10^log10ct)/t            
                  thresh <- t*a+b
                  idx <- which(parameter<=thresh)
                  idx2 <- which(parameter>thresh)
                  if(length(idx2)>0)
                      parameter[idx2] <- (10^(parameter[idx2]*(d/r)))/c
                  if(length(idx>0))
                      parameter[idx] <- (parameter[idx]-b)/a
                  parameter
              }
        })


## ===========================================================================
## Transformation reference
## ---------------------------------------------------------------------------
setMethod("eval",
          signature=signature(expr="transformReference", envir="missing"),
          definition=function (expr, envir = parent.frame(),
              enclos=if (is.list(envir) ||
                is.pairlist(envir)) parent.frame() else baseenv())
          {
              expr@searchEnv[[slot(expr,"transformationId")]]
          })	
	
####----------------------------------------------------------------------------
#### Reference to a predefined gate 
####----------------------------------------------------------------------------

setMethod("eval",
          signature=signature(expr="filterReference", envir="missing"),
          definition=function (expr, envir = parent.frame(),
              enclos=if (is.list(envir) ||
                is.pairlist(envir)) parent.frame() else baseenv())
          expr@env[[expr@name]]  #retrieved using name instead of the filterId
          )	


####----------------------------------------------------------------------------
#### Eval transforms for compensations
####----------------------------------------------------------------------------

# Josef Spidlen, Oct 17, 2013:
# I have changed the eval method to accept a flowFrame (x) instead of just
# the data matrix (df).
# The whole point is that Gating-ML 2.0 includes the option of specifying
# "FCS" as the "spillover matrix", which means that parameters are supposed
# to be compensated as per compensation description in FCS. This is why the
# whole flowFrame is passed to eval, which then has the option of extracting
# the spillover matrix from the SPILL (or some other) keyword.
setMethod("eval",
          signature=signature(expr="compensatedParameter", envir="missing"),
          function(expr, envir, enclos)
          {    function(x)
                 { 
                   df <- flowFrameToMatrix(x)
                   parameter <- expr@parameters
                   compObj <- expr@searchEnv[[expr@spillRefId]]
                   if (is.null(compObj) && expr@spillRefId == "SpillFromFCS") 
                   {
                       spillMat <- getSpilloverFromFlowFrame(x, parameter)
                       trans <- list()
                   }
                   else
                   {
                       spillMat <- compObj@spillover
                       trans <- compObj@parameters
                   }
                   cols <- colnames(spillMat)
                   for(i in trans){
                     if(is(i, "transformReference")){
                       newCol <- resolveTransformReference(i, x)
                       colnames(newCol) <- i@transformationId
                       df <- cbind(df,newCol)
                     }
                   }
                   # Josef Spidlen, Oct 23, 2013
                   # Added pseudoinverse (from corpcor) to deal with non-square spectrum matrices
                   if(ncol(spillMat) == nrow(spillMat))
                   {
                       # Josef Spidlen, Nov 14, 2013:
                       # This code is wrong and went probably unnoticed for some time
                       # t(solve(spillMat)[parameter,]%*%t(df[,cols]))
                       # The same issue existed in the compensate method (see flowFrame-accessors.R) and
                       # has been fixed by "phd" long time ago
                       tmp <- (df[,cols] %*% solve(spillMat))
                       # that is the same as tmp <- t(solve(t(spillMat))%*%t(df[,cols]))
                       # which is essentially what the compensate method is doing.
                       colnames(tmp) <- cols
                       tmp[,parameter]
                   }
                   else
                   {
                       resMatrix <- df[,cols] %*% pseudoinverse(spillMat)
                       colnames(resMatrix) <- rownames(spillMat)
                       # Note that bellow we are using expr@transformationId rather than parameter
                       # since the parameter of a compensatedParameter reflects the detector name,
                       # not the fluorochrome name of a Gating-ML 2.0 spectrum matrix
                       # Btw. compensatedParameter@parameter is not meaningful for non-square matrices
                       as.matrix(resMatrix[,expr@transformationId])
                   }
                 }
             })

# Josef Spidlen, Oct 18, 2013:
# Gating-ML 2.0 may specify to use compensation description as prescribed
# by the FCS data file.
# We will look at
#  - description[['SPILL']]
#  - description[['$SPILLOVER']]
#  - description[['SPILLOVER']]
#  - description[['$SPILL']]
# and try to extract the spillover from there.
# If there is no spillover in the FCS datafile or if the spillover does not
# include the required parameter, then the parameter is supposed to be used
# uncompensated. In flowUtils/flowCore, we keep the parameter as compensated,
# but we will provide a 1x1 identify matrix as the spillover at the point of
# evaluation. Therefore, the calculation will essentially use the uncompensated
# parameter. This also has the advantage that if the same filter is applied
# to a different flowFrame, which may include a different spillover, then the
# parameter will be compensated according to that spillover at the time of
# evaluation.
getSpilloverFromFlowFrame <- function(myFrame, requiredParameter)
{
    mySpill <- myFrame@description[['SPILL']]
    if (is.null(mySpill))
        mySpill <- myFrame@description[['$SPILLOVER']]
    if (is.null(mySpill))
        mySpill <- myFrame@description[['SPILLOVER']]
    if (is.null(mySpill))
        mySpill <- myFrame@description[['$SPILL']]
    if (is.null(mySpill))
        mySpill <- getIdentityMatrixForParameter(requiredParameter)
    if (class(mySpill) != "matrix")
        mySpill <- parseMatrixFromString(mySpill, requiredParameter)
    if (!(requiredParameter %in% colnames(mySpill)))
        mySpill <- getIdentityMatrixForParameter(requiredParameter)
	mySpill
}

# Josef Spidlen, Oct 18, 2013:
# Return a 1x1 matrix with the value 1 and with both colnames and
# rownames set to the provided paremeter value. This is used as dummy
# spillover matrix that does not change the value of the parameter
getIdentityMatrixForParameter <- function(parameter)
{
    ret <- matrix(c(1), dimnames=list(parameter))
    colnames(ret) <- list(parameter)
    ret
}

# Josef Spidlen, Oct 18, 2013:
# Parse the spillover matrix from a string. This is what
# flowCore's IO is doing when reading the SPILL keyword.
# Here, we may can parse it from different keywords as well,
# and we have a fall back strategy of returning a 1x1 identity
# matrix if parsing doesn't work as expected (i.e, if there is
# something else in the spilloverString.
parseMatrixFromString <- function(spilloverString, requiredParameter)
{
    spmat <- NULL
    suppressWarnings(try(
        {
            splt <- strsplit(spilloverString, ",")[[1]]
            nrCols <- as.numeric(splt[1])
            cnames <- splt[2:(nrCols+1)]
            vals <- as.numeric(splt[(nrCols+2):length(splt)])
            spmat <- matrix(vals, ncol=nrCols, byrow=TRUE)
            colnames(spmat) <- cnames
        }, silent=TRUE))
    if (is.null(spmat)) spmat <- getIdentityMatrixForParameter(requiredParameter)
    spmat
}

# These eval methods are made to use either a flowFrame or a data matrix, so this
# this mehtod is called if we want to be sure we have the data matrix only
flowFrameToMatrix <- function(x)
{
    if (class(x) == "flowFrame")
        exprs(x)
    else
        x
}
