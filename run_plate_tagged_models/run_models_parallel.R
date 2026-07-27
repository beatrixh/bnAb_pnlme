library(lixoftConnectors)
library(parallel)
library(dplyr)

monolix_path <- "C:/Program Files/Lixoft/MonolixSuite2024R1"
models_dir <- "C:/Users/bhaddock/repos/bnAb_pnlme/run_plate_tagged_models/model_files"

model_files <- list.files(models_dir, pattern = "^4PL_edge_effects_m[0-9]+\\.mlxtran$")
model_names <- sub("^4PL_edge_effects_(m[0-9]+)\\.mlxtran$", "\\1", model_files)
model_names <- model_names[order(as.integer(sub("^m", "", model_names)))]

run_one_model <- function(model_name, models_dir, monolix_path) {
  library(lixoftConnectors)
  library(dplyr)
  initializeLixoftConnectors(path = monolix_path)

  mlxtran_path <- file.path(models_dir, paste0("4PL_edge_effects_", model_name, ".mlxtran"))
  savedir <- file.path(models_dir, model_name)

  if (file.exists(mlxtran_path) && !dir.exists(savedir)) {
    tryCatch({
      loadProject(mlxtran_path)
      print(model_name)

      autoInitValues <- getFixedEffectsByAutoInit()
      setPopulationParameterInformation(autoInitValues)

      popParams <- getPopulationParameterInformation()

      betaRows <- grepl("^beta_", popParams$name)
      popParams$initialValue[betaRows] <- 0

      omegaRows <- grepl("^omega_", popParams$name)
      popParams$initialValue[omegaRows] <- 1

      popParams <- popParams %>%
        rows_update(autoInitValues, by = "name")
      setPopulationParameterInformation(popParams)

      defaults <- c(a = 1, b = 0.3, c = 1)
      for (nm in names(defaults)) {
        if (nm %in% popParams$name) {
          popParams$initialValue[popParams$name == nm] <- defaults[nm]
        }
      }
      setPopulationParameterInformation(popParams)

      setConditionalModeEstimationSettings(
        nboptimizationiterationsmode = 2000
      )

      runPopulationParameterEstimation()
      runConditionalModeEstimation()
      runLogLikelihoodEstimation()

      pop <- getEstimatedPopulationParameters()
      ind <- getEstimatedIndividualParameters()
      loglik <- getEstimatedLogLikelihood()

      dir.create(savedir, recursive = TRUE)

      write.csv(pop, file.path(savedir, "pop.csv"), row.names = FALSE)
      for (nm in names(ind)) {
        write.csv(ind[[nm]], file.path(savedir, paste0("ind_", nm, ".csv")), row.names = FALSE)
      }
      write.csv(data.frame(as.list(unlist(loglik))), file.path(savedir, "loglik.csv"), row.names = FALSE)
    }, error = function(e) {
      message(sprintf("[%s] failed: %s", model_name, conditionMessage(e)))
    })
  }

  invisible(model_name)
}

n_workers <- 3
cl <- makeCluster(n_workers)

results <- tryCatch(
  parLapplyLB(
    cl, model_names, run_one_model,
    models_dir = models_dir, monolix_path = monolix_path
  ),
  finally = stopCluster(cl)
)
