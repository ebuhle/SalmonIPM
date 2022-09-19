#' Generate initial values for fitting IPMs or run-reconstruction spawner-recruit models.
#' 
#' This function is mostly used internally, but may occasionally be called directly 
#' to help diagnose sampling problems or for simulation testing.
#'
#' @param stan_model Character string specifying the **salmonIPM** model to be fit.
#' @param data Named list of input data for fitting either an IPM or
#'   run-reconstruction spawner-recruit model in [Stan](http://mc-stan.org), 
#'   as returned by [stan_data()].
#' @param chains A positive integer specifying the number of Markov chains.
#'
#' @return A named list with starting values for the parameters and states in
#'   the model that is passed to [rstan::sampling()] as the `init` argument to be
#'   used when fitting **salmonIPM** models.
#'
#' @examples
#' # Simulate data for a multi-population spawner-to-spawner model
#' set.seed(1234)
#' N_pop <- 10
#' N_year <- 20
#' N <- N_pop*N_year
#' 
#' pars <- list(mu_alpha = 2, sigma_alpha = 0.5, mu_Rmax = 5, sigma_Rmax = 0.5, 
#'              rho_alphaRmax = 0.3, rho_R = 0.7, sigma_year_R = 0.5, sigma_R = 0.3, 
#'              tau = 0.5, mu_p = c(0.05, 0.55, 0.4), sigma_pop_p = c(0.1, 0.2), 
#'              R_pop_p = diag(2), sigma_p = c(0.5, 0.5), R_p = diag(2), S_init_K = 0.7)
#' 
#' fd <- data.frame(pop = rep(1:N_pop, each = N_year), year = rep(1:N_year, N_pop),
#'                  A = 1, p_HOS = 0, F_rate = rbeta(N,7,3), B_rate = 0,
#'                  n_age_obs = 50, n_HW_obs = 0)
#' 
#' sim_out <- simIPM(pars = pars, fish_data = fd, N_age = 3, max_age = 5)
#' 
#' # Prepare simulated data for Stan
#' dat <- stan_data("IPM_SS_pp", fish_data = sim_out$sim_dat)
#' 
#' # Generate inits for 3 chains
#' inits <- stan_init("IPM_SS_pp", data = dat, chains = 3)
#'
#' @export
stan_init <- function(stan_model, data, chains = 1) 
{
  if(!stan_model %in% c("IPM_SS_np","IPM_SS_pp","IPM_SMS_np","IPM_SMS_pp",
                        "IPM_SSsthd_np", "IPM_SMaS_np",
                        "IPM_LCRchum_pp","IPM_ICchinook_pp",
                        "RR_SS_np","RR_SS_pp"))
    stop("Stan model ", stan_model, " does not exist")
  
  model <- strsplit(stan_model, "_")[[1]][1]
  life_cycle <- strsplit(stan_model, "_")[[1]][2]
  for(i in names(data)) assign(i, data[[i]])
  N_pop <- max(pop)
  N_year <- max(year)
  
  if(life_cycle == "LCRchum") {
    n_H_obs <- rowSums(n_origin_obs[,-1])
    which_H <- which(n_H_obs > 0)
    n_H_obs <- n_H_obs[which_H]
    n_W_obs <- n_origin_obs[which_H,1]
    
    p_origin <- matrix(c(0.135411592660393,0.0771601000938529,0.286929034048003,0.0102868226187408,
                         0.00943396226415094,0.00943396226415094,0.00943396226415094,0.0284385085450134,
                         0.405170168449092,0.00943396226415094,0.00943396226415094,0.00943396226415094, 
                         0.0091743119266055,0.053367124866482,0.221432516561387,0.0091743119266055,
                         0.0091743119266055,0.0091743119266055,0.0091743119266055,0.0091743119266055,
                         0.642631551232681,0.0091743119266055,0.0091743119266055,0.0091743119266055,
                         0.0091743119266055,0.0091743119266055,0.0091743119266055,0.0091743119266055,
                         0.0091743119266055,0.0091743119266055,0.0091743119266055,0.0091743119266055,
                         0.0091743119266055,0.202442783082541,0.397475438447644,0.317512971130366), 
                       nrow = 3, byrow = TRUE)
  }
  
  if(life_cycle == "SSsthd") {
    # ignore repeat spawner age structure in run reconstruction 
    n_age_obs <- n_MRage_obs[, grep("_M_", colnames(n_MRage_obs))]
    colnames(n_age_obs) <- gsub("_R", "", gsub("_M", "", gsub("MR", "", colnames(n_age_obs))))
    n_MRage_M_obs <- pmax(rowSums(n_age_obs), 0.1)
    n_MRage_R_obs <- pmax(rowSums(n_MRage_obs[, grep("_R_", colnames(n_MRage_obs))]), 0.1)
    s_SS <- pmin(n_MRage_R_obs/n_MRage_M_obs, 0.9)
    q_MR_obs <- sweep(n_MRage_obs, 1, rowSums(n_MRage_obs), "/")
    q_MR_obs_NA <- apply(is.na(q_MR_obs), 1, any)
    q_MR_obs[q_MR_obs_NA,] <- rep(colMeans(na.omit(q_MR_obs)), each = sum(q_MR_obs_NA))
  }
  
  if(model == "IPM" & life_cycle != "SMaS") {
    S_obs_noNA <- S_obs
    S_obs[-which_S_obs] <- NA
    p_HOS_obs <- pmin(pmax(n_H_obs / (n_H_obs + n_W_obs), 0.1), 0.9)
    p_HOS_obs[n_H_obs + n_W_obs == 0] <- 0.5
    p_HOS_all <- rep(0,N)
    p_HOS_all[which_H] <- p_HOS_obs
    n_W_obs_all <- replace(rep(0,N), which_H, n_W_obs)
    n_H_obs_all <- replace(rep(0,N), which_H, n_H_obs)
    min_age <- max_age - N_age + 1
    adult_ages <- min_age:max_age
    q_obs <- sweep(n_age_obs, 1, rowSums(n_age_obs), "/")
    q_obs_NA <- apply(is.na(q_obs), 1, any)
    q_obs[q_obs_NA,] <- rep(colMeans(na.omit(q_obs)), each = sum(q_obs_NA))
    R_a <- matrix(NA, N, N_age)
    S_W_obs <- S_obs * (1 - p_HOS_all)
    B_take_all <- replace(rep(0,N), which_B, B_take_obs)
    B_rate <- pmin(pmax(B_take_obs / (S_W_obs[which_B] * (1 - q_obs[which_B,1]) + B_take_obs), 0.01), 0.99)
    B_rate <- replace(B_rate, is.na(B_rate), mean(B_rate, na.rm = TRUE))
    B_rate_all <- replace(rep(0,N), which_B, B_rate)
    rr_dat <- run_recon(data.frame(pop = pop, A = A, year = year, S_obs = S_obs, 
                                   n_age_obs, n_W_obs = n_W_obs_all, n_H_obs = n_H_obs_all,
                                   F_rate = F_rate, B_take_obs = B_take_all))
    R_obs <- replace(rr_dat$R_obs, is.na(rr_dat$R_obs), mean(rr_dat$R_obs, na.rm = TRUE))
    R_obs <- pmax(R_obs, 1)
    p_obs <- rr_dat[, grep("p_age", names(rr_dat))]
    p_obs <- pmin(pmax(p_obs, 0.01), 0.99)
    p_obs_NA <- apply(is.na(p_obs), 1, any)
    p_obs[p_obs_NA, ] <- rep(colMeans(na.omit(p_obs)), each = sum(p_obs_NA))
    p_obs <- sweep(p_obs, 1, rowSums(p_obs), "/")
    alr_p <- sweep(log(p_obs[, 1:(N_age-1), drop = FALSE]), 1, log(p_obs[, N_age]), "-")
    zeta_p <- apply(alr_p, 2, scale)
    mu_p <- aggregate(p_obs, list(pop), mean)[, -1, drop = FALSE]
    zeta_pop_p <- aggregate(alr_p, list(pop), mean)[, -1, drop = FALSE]
    zeta_pop_p <- apply(zeta_pop_p, 2, scale)
  }
  
  if(life_cycle %in% c("SMS","LCRchum")) {
    mu_mu_Mmax <- max(log(M_obs/A), na.rm = TRUE)
    if(N_M_obs < N)
      M_obs[-which_M_obs] <- median(M_obs[which_M_obs])
    s_MS <- pmin(S_obs_noNA/M_obs, 0.9)
  }
  
  if(stan_model == "IPM_SMaS_np") {
    # This is a bit of a hack to avoid tedious age-structured run reconstruction
    N_GRage <- N_Mage*N_MSage
    max_age <- max_Mage + max_MSage
    q_M_obs <- sweep(n_Mage_obs, 1, rowSums(n_Mage_obs), "/")
    s_MS <- mean(pmin(S_obs/M_obs, 0.99), na.rm = TRUE)
    q_MS_obs <- sweep(n_MSage_obs, 1, rowSums(n_MSage_obs), "/")
    q_MS_obs_NA <- apply(is.na(q_MS_obs), 1, any)
    q_MS_obs[q_MS_obs_NA,] <- rep(colMeans(na.omit(q_MS_obs)), each = sum(q_MS_obs_NA))
    q_MS_pop <- as.matrix(aggregate(q_MS_obs, list(pop), mean))[,-1,drop=FALSE]
    mu_q_MS <- array(0, c(N_pop, N_Mage, N_MSage))
    for(i in 1:N_pop)
      for(j in 1:N_Mage)
        mu_q_MS[i,j,] <- as.vector(q_MS_pop[i,])
    q_GR_obs <- sweep(n_GRage_obs, 1, rowSums(n_GRage_obs), "/")
    p_HOS_obs <- pmin(pmax(n_H_obs / (n_H_obs + n_W_obs), 0.01), 0.99)
    p_HOS_obs[n_H_obs + n_W_obs == 0] <- 0.5
    p_HOS_all <- rep(0,N)
    p_HOS_all[which_H] <- p_HOS_obs
    S_W_obs <- S_obs*(1 - p_HOS_all)
    B_rate <- pmin(pmax(B_take_obs / (S_W_obs[which_B] + B_take_obs), 0.01), 0.99)
    B_rate[is.na(B_rate)] <- 0.1
  }
  
  if(life_cycle == "LCRchum") {
    E <- S_obs_noNA*0.5*mean(fecundity_data$E_obs)
    s_EM <- pmin(M_obs/E, 0.9)
  }
  
  out <- lapply(1:chains, function(i) {
    switch(stan_model,
           IPM_SS_np = list(
             # recruitment
             alpha = array(exp(runif(N_pop, 1, 3))),
             beta_alpha = matrix(rnorm(K_alpha*N_pop, 0, 0.5/apply(abs(X_alpha), 2, max)), 
                                 N_pop, K_alpha, byrow = TRUE),
             Rmax = array(rlnorm(N_pop, log(tapply(R_obs/A, pop, quantile, 0.9)), 0.5)),
             beta_Rmax = matrix(rnorm(K_Rmax*N_pop, 0, 0.5/apply(abs(X_Rmax), 2, max)), 
                                N_pop, K_Rmax, byrow = TRUE),
             beta_R = matrix(rnorm(K_R*N_pop, 0, 0.5/apply(abs(X_R), 2, max)), 
                             N_pop, K_R, byrow = TRUE),
             rho_R = array(runif(N_pop, 0.1, 0.7)),
             sigma_R = array(runif(N_pop, 0.05, 2)), 
             zeta_R = as.vector(scale(log(R_obs)))*0.1,
             # spawner age structure
             mu_p = mu_p,
             sigma_p = matrix(runif(N_pop*(N_age-1), 0.5, 1), N_pop, N_age-1),
             zeta_p = zeta_p,
             # H/W composition, removals
             p_HOS = p_HOS_obs,
             B_rate = B_rate,
             # initial spawners, observation error
             S_init = rep(median(S_obs_noNA), max_age*N_pop),
             q_init = matrix(colMeans(q_obs), max_age*N_pop, N_age, byrow = TRUE),
             tau = array(runif(N_pop, 0.5, 1))
           ),
           
           IPM_SS_pp = list(
             # recruitment
             mu_alpha = runif(1, 1, 3),
             beta_alpha = array(rnorm(K_alpha, 0, 0.5/apply(abs(X_alpha), 2, max))),
             sigma_alpha = runif(1, 0.1, 0.5),
             zeta_alpha = as.vector(runif(N_pop, -1, 1)),
             mu_Rmax = rnorm(1, log(quantile(R_obs/A,0.9)), 0.5),
             beta_Rmax = array(rnorm(K_Rmax, 0, 0.5/apply(abs(X_Rmax), 2, max))),
             sigma_Rmax = runif(1, 0.1, 0.5),
             zeta_Rmax = as.vector(runif(N_pop,-1,1)),
             rho_alphaRmax = runif(1, -0.5, 0.5),
             beta_R = array(rnorm(K_R, 0, 0.5/apply(abs(X_R), 2, max))),
             rho_R = runif(1, 0.1, 0.7),
             sigma_year_R = runif(1, 0.1, 0.5),
             zeta_year_R = as.vector(rnorm(max(year, year_fwd), 0, 0.1)),
             sigma_R = runif(1, 0.5, 1),
             zeta_R = as.vector(scale(log(R_obs)))*0.1,
             # spawner age structure
             mu_p = colMeans(p_obs),
             sigma_pop_p = array(runif(N_age - 1, 0.5, 1)),
             zeta_pop_p = zeta_pop_p,
             sigma_p = array(runif(N_age-1, 0.5, 1)),
             zeta_p = zeta_p,
             # H/W composition, removals
             p_HOS = p_HOS_obs,
             B_rate = B_rate,
             # initial spawners, observation error
             S_init = rep(median(S_obs_noNA), max_age*N_pop),
             q_init = matrix(colMeans(q_obs), max_age*N_pop, N_age, byrow = TRUE),
             tau = runif(1, 0.5, 1)
           ),
           
           IPM_SSsthd_np = list(
             # recruitment
             alpha = array(exp(runif(N_pop, 1, 3))),
             beta_alpha = matrix(rnorm(K_alpha*N_pop, 0, 0.5/apply(abs(X_alpha), 2, max)), 
                                 N_pop, K_alpha, byrow = TRUE),
             Rmax = array(rlnorm(N_pop, log(tapply(R_obs/A, pop, quantile, 0.9)), 0.5)),
             beta_Rmax = matrix(rnorm(K_Rmax*N_pop, 0, 0.5/apply(abs(X_Rmax), 2, max)), 
                                N_pop, K_Rmax, byrow = TRUE),
             beta_R = matrix(rnorm(K_R*N_pop, 0, 0.5/apply(abs(X_R), 2, max)), 
                             N_pop, K_R, byrow = TRUE),
             rho_R = array(runif(N_pop, 0.1, 0.7)),
             sigma_R = array(runif(N_pop, 0.05, 2)), 
             zeta_R = as.vector(scale(log(R_obs)))*0.1,
             # kelt survival
             mu_SS = array(plogis(rnorm(N_pop, mean(qlogis(s_SS)), 0.5))),
             rho_SS = array(runif(N_pop, 0.1, 0.7)),
             sigma_SS = array(runif(N_pop, 0.05, 2)),
             zeta_SS = as.vector(scale(qlogis(s_SS))),
             # maiden spawner age structure
             mu_p = mu_p,
             sigma_p = matrix(runif(N_pop*(N_age-1), 0.5, 1), N_pop, N_age-1),
             zeta_p = zeta_p,
             # H/W composition, removals
             p_HOS = p_HOS_obs,
             B_rate = B_rate,
             # initial spawners, observation error
             S_init = rep(median(S_obs_noNA), max_age*N_pop),
             q_MR_init = matrix(colMeans(q_MR_obs), max_age*N_pop, N_age*2, byrow = TRUE),
             tau = array(runif(N_pop, 0.5, 1))
           ),
           
           IPM_SMS_np = list(
             # smolt recruitment
             alpha = array(exp(runif(N_pop,1,3))),
             beta_alpha = matrix(rnorm(K_alpha*N_pop, 0, 0.5/apply(abs(X_alpha), 2, max)), 
                                 N_pop, K_alpha, byrow = TRUE),
             Mmax = array(rlnorm(N_pop, log(tapply(R_obs/A, pop, quantile, 0.9)), 0.5)),
             beta_Mmax = matrix(rnorm(K_Mmax*N_pop, 0, 0.5/apply(abs(X_Mmax), 2, max)), 
                                N_pop, K_Mmax, byrow = TRUE),
             beta_M = matrix(rnorm(K_M*N_pop, 0, 0.5/apply(abs(X_M), 2, max)), 
                             N_pop, K_M, byrow = TRUE),
             rho_M = array(runif(N_pop, 0.1, 0.7)),
             sigma_M = array(runif(N_pop, 0.05, 2)), 
             zeta_M = as.vector(scale(log(M_obs)))*0.1,
             # SAR
             mu_MS = array(plogis(rnorm(N_pop, mean(qlogis(s_MS)), 0.5))),
             beta_MS = matrix(rnorm(K_MS*N_pop, 0, 0.5/apply(abs(X_MS), 2, max)), 
                              N_pop, K_MS, byrow = TRUE),
             rho_MS = array(runif(N_pop, 0.1, 0.7)),
             sigma_MS = array(runif(N_pop, 0.05, 2)), 
             zeta_MS = as.vector(scale(qlogis(s_MS))),
             # spawner age structure
             mu_p = mu_p,
             sigma_p = matrix(runif(N_pop*(N_age-1),0.5,1), N_pop, N_age-1),
             zeta_p = zeta_p,
             # H/W composition, removals
             p_HOS = p_HOS_obs,
             B_rate = B_rate,
             # initial states, observation error
             M_init = array(rep(median(M_obs), smolt_age*N_pop)),
             S_init = array(rep(median(S_obs_noNA), (max_age - smolt_age)*N_pop)),
             q_init = matrix(colMeans(q_obs), (max_age - smolt_age)*N_pop, N_age, byrow = TRUE),
             tau_M = array(runif(N_pop, 0.5, 1)),
             tau_S = array(runif(N_pop, 0.5, 1))
           ),
           
           IPM_SMS_pp = list(
             # smolt recruitment
             mu_alpha = runif(1, 1, 3),
             beta_alpha = array(rnorm(K_alpha, 0, 0.5/apply(abs(X_alpha), 2, max))),
             sigma_alpha = runif(1, 0.1, 0.5),
             zeta_alpha = as.vector(rnorm(N_pop, 0, 1)),
             mu_Mmax = rnorm(1, log(quantile(R_obs/A,0.9)), 0.5),
             beta_Mmax = array(rnorm(K_Mmax, 0, 0.5/apply(abs(X_Mmax), 2, max))),
             sigma_Mmax = runif(1, 0.1, 0.5),
             zeta_Mmax = as.vector(rnorm(N_pop, 0, 1)),
             rho_alphaMmax = runif(1, -0.5, 0.5),
             beta_M = array(rnorm(K_M, 0, 0.5/apply(abs(X_M), 2, max))),
             rho_M = runif(1, 0.1, 0.7),
             sigma_year__M = runif(1, 0.1, 0.5),
             zeta_year__M = as.vector(rnorm(max(year), 0, 0.1)),
             sigma_M = runif(1, 0.5, 1),
             zeta_M = as.vector(scale(log(M_obs)))*0.1,
             # SAR
             mu_MS = plogis(rnorm(1, mean(qlogis(s_MS)), 0.5)),
             beta_MS = array(rnorm(K_MS, 0, 0.5/apply(abs(X_MS), 2, max))),
             rho_MS = runif(1, 0.1, 0.7),
             sigma_year__MS = runif(1, 0.05, 2), 
             sigma_MS = runif(1, 0.5, 1),
             zeta_MS = as.vector(scale(qlogis(s_MS))),
             # spawner age structure
             mu_p = colMeans(p_obs),
             sigma_pop_p = array(runif(N_age - 1, 0.5, 1)),
             zeta_pop_p = zeta_pop_p,
             sigma_p = array(runif(N_age-1, 0.5, 1)),
             zeta_p = zeta_p,
             # H/W composition, removals
             p_HOS = p_HOS_obs,
             B_rate = B_rate,
             # initial states, observation error
             M_init = array(rep(median(M_obs), smolt_age*N_pop)),
             S_init = array(rep(median(S_obs_noNA), (max_age - smolt_age)*N_pop)),
             q_init = matrix(colMeans(q_obs), (max_age - smolt_age)*N_pop, N_age, byrow = TRUE),
             tau_M = runif(1, 0.5, 1),
             tau_S = runif(1, 0.5, 1)
           ),
           
           IPM_SMaS_np = list(
             # smolt recruitment
             alpha = array(rlnorm(N_pop, max(log(M_obs/S_obs), na.rm = TRUE), 1)),
             beta_alpha = matrix(rnorm(K_alpha*N_pop, 0, 0.5/apply(abs(X_alpha), 2, max)), 
                                 N_pop, K_alpha, byrow = TRUE),
             Mmax = array(rlnorm(N_pop, log(tapply(M_obs/A, pop, quantile, 0.9, na.rm = TRUE)), 0.5)),
             beta_Mmax = matrix(rnorm(K_Mmax*N_pop, 0, 0.5/apply(abs(X_Mmax), 2, max)), 
                                N_pop, K_Mmax, byrow = TRUE),
             beta_M = matrix(rnorm(K_M*N_pop, 0, 0.5/apply(abs(X_M), 2, max)), 
                             N_pop, K_M, byrow = TRUE),
             rho_M = array(runif(N_pop, 0.1, 0.7)),
             sigma_M = array(runif(N_pop, 0.05, 2)), 
             zeta_M = rnorm(N,0,0.1), 
             # smolt age structure
             mu_p_M = aggregate(q_M_obs, list(pop), mean, na.rm = TRUE),
             sigma_p_M = matrix(runif(N_pop*(N_Mage - 1), 0.05, 2), N_pop, N_Mage - 1),
             zeta_p_M = matrix(rnorm(N*(N_Mage - 1), 0, 0.1), N, N_Mage - 1),
             # SAR
             mu_MS = matrix(plogis(rnorm(N_pop*N_Mage, qlogis(s_MS), 0.5)), N_pop, N_Mage),
             beta_MS = matrix(rnorm(K_MS*N_pop, 0, 0.5/apply(abs(X_MS), 2, max)), 
                              N_pop, K_MS, byrow = TRUE),
             rho_MS = matrix(runif(N_pop, 0.1, 0.7), N_pop, N_Mage),
             sigma_MS = matrix(runif(N_pop, 0.05, 2), N_pop, N_Mage), 
             zeta_MS = matrix(rnorm(N*N_Mage, 0, 0.1), N, N_Mage),
             # ocean age structure
             mu_p_MS = mu_q_MS,
             sigma_p_MS = array(runif(N_pop*N_Mage*(N_MSage - 1), 0.05, 2), 
                                c(N_pop, N_Mage, N_MSage - 1)), 
             zeta_p_MS = matrix(rnorm(N*N_Mage*(N_MSage - 1), 0, 0.5), N, N_Mage*(N_MSage - 1)),
             # H/W composition, removals
             p_HOS = p_HOS_obs,
             B_rate = B_rate,
             # initial states, observation error
             M_init = array(rep(median(M_obs), max_Mage*N_pop)),
             q_M_init = matrix(colMeans(q_M_obs, na.rm = TRUE), max_Mage*N_pop, N_Mage, byrow = TRUE),
             S_init = array(rep(median(S_obs, na.rm = TRUE), N_pop*max_MSage)),
             q_GR_init = matrix(colMeans(q_GR_obs, na.rm = TRUE), max_MSage*N_pop, N_GRage, byrow = TRUE),
             tau_S = array(runif(N_pop, 0.01, 0.05)),
             tau_M = array(runif(N_pop, 0.01, 0.05))
           ),
           
           IPM_LCRchum_pp = list(
             # egg deposition
             mu_E = rlnorm(N_age, tapply(log(E_obs), age_E, mean), 0.5),
             sigma_E = rlnorm(N_age, log(tapply(E_obs, age_E, sd)), 0.5), 
             delta_NG = runif(1, 0.7, 1),
             # egg-smolt survival
             mu_psi = plogis(rnorm(1, mean(qlogis(s_EM)), 0.3)),
             beta_psi = array(rnorm(K_psi, 0, 0.5/apply(abs(X_psi), 2, max))),
             sigma_psi = runif(1, 0.1, 0.5),
             zeta_psi = rnorm(N_pop, 0, 1),
             mu_Mmax = rnorm(1, mu_mu_Mmax, 3),
             beta_Mmax = array(rnorm(K_Mmax, 0, 0.5/apply(abs(X_Mmax), 2, max))),
             sigma_Mmax = runif(1, 0.5, 2),
             zeta_Mmax = rnorm(N_pop, 0, 1),
             beta_M = array(rnorm(K_M, 0, 0.5/apply(abs(X_M), 2, max))),
             rho_M = runif(1, 0.1, 0.7),
             sigma_year_M = runif(1, 0.1, 0.5),
             zeta_year_M = rnorm(N_year, 0, 0.1),
             sigma_M = runif(1, 0.1, 0.5),
             zeta_M = rep(0,N), #as.vector(scale(log(M_obs)))*0.1,
             # SAR
             mu_MS = plogis(rnorm(1, mean(qlogis(s_MS)), 0.5)),
             beta_MS = array(rnorm(K_MS, 0, 0.5/apply(abs(X_MS), 2, max))),
             rho_MS = runif(1, 0.1, 0.7),
             sigma_year_MS = runif(1, 0.05, 2), 
             zeta_year_MS = as.vector(tapply(scale(qlogis(s_MS)), year, mean)),
             sigma_MS = runif(1, 0.5, 1),
             zeta_MS = rep(0,N), #as.vector(scale(qlogis(s_MS))),
             # spawner age structure and sex ratio
             mu_p = colMeans(p_obs),
             sigma_pop_p = runif(N_age - 1, 0.5, 1),
             zeta_pop_p = zeta_pop_p,
             sigma_p = runif(N_age-1, 0.5, 1),
             zeta_p = zeta_p,
             mu_F = runif(1,0.4,0.6),
             sigma_pop_F = runif(1, 0.1, 0.5),
             zeta_pop_F = rnorm(N_pop, 0, 0.3),
             sigma_F = runif(1, 0.1, 0.5),
             zeta_F = rnorm(N, 0, 0.3),
             # H/W composition, removals
             p_origin = p_origin,
             B_rate = B_rate,
             # initial states, observation error
             M_init = rep(tapply(M_obs, pop, median), each = smolt_age),
             S_init = rep(tapply(S_obs_noNA, pop, median), each = max_age - smolt_age),
             q_init = matrix(colMeans(q_obs), (max_age - smolt_age)*N_pop, N_age, byrow = TRUE),
             mu_tau_M = runif(1, 0, 0.5),
             sigma_tau_M = runif(1, 0, 0.5),
             mu_tau_S = runif(1, 0, 0.5),
             sigma_tau_S = runif(1, 0, 0.5)
           ),
           
           IPM_ICchinook_pp = list(
             # smolt recruitment
             mu_alpha = runif(1, 1, 3),
             beta_alpha = array(rnorm(K_alpha, 0, 0.5/apply(abs(X_alpha), 2, max))),
             sigma_alpha = runif(1, 0.1, 0.5),
             zeta_alpha = runif(N_pop, -1, 1),
             mu_Mmax = rnorm(1, log(quantile(R_obs/A,0.9)), 0.5),
             beta_Mmax = array(rnorm(K_Mmax, 0, 0.5/apply(abs(X_Mmax), 2, max))),
             sigma_Mmax = runif(1, 0.1, 0.5),
             zeta_Mmax = runif(N_pop, -1, 1),
             rho_alphaMmax = runif(1, -0.5, 0.5),
             beta_M = array(rnorm(K_M, 0, 0.5/apply(abs(X_M), 2, max))),
             rho_M = runif(1, 0.1, 0.7),
             sigma_M = runif(1, 0.05, 2), 
             zeta_M = as.vector(scale(log(R_obs)))*0.01,
             M_init = rep(median(S_obs_noNA)*100, smolt_age*N_pop),
             # downstream, SAR, upstream survival
             mu_D = qlogis(0.8),
             beta_D = array(rnorm(K_D, 0, 0.5/apply(abs(X_D), 2, max))),
             rho_D = runif(1, 0.1, 0.7),
             sigma_D = runif(1, 0.05, 2),
             zeta_D = rnorm(max(year,year_fwd), 0, 0.1),
             mu_SAR = qlogis(0.01),
             beta_SAR = array(rnorm(K_SAR, 0, 0.5/apply(abs(X_SAR), 2, max))),
             rho_SAR = runif(1, 0.1, 0.7),
             sigma_SAR = runif(1, 0.05, 2),
             zeta_SAR = rnorm(max(year,year_fwd), 0, 0.1),
             mu_U = qlogis(0.8),
             beta_U = array(rnorm(K_U, 0, 0.5/apply(abs(X_U), 2, max))),
             rho_U = runif(1, 0.1, 0.7),
             sigma_U = runif(1, 0.05, 2),
             zeta_U = rnorm(max(year,year_fwd), 0, 0.1),
             # spawner age structure
             mu_p = colMeans(p_obs),
             sigma_pop_p = runif(N_age - 1, 0.5, 1),
             zeta_pop_p = zeta_pop_p,
             sigma_p = runif(N_age-1, 0.5, 1),
             zeta_p = zeta_p,
             # H/W composition, removals
             p_HOS = p_HOS_obs,
             B_rate = B_rate,
             # initial spawners, observation error
             S_init = rep(median(S_obs_noNA), (max_age - smolt_age)*N_pop),
             q_init = matrix(colMeans(q_obs), (max_age - smolt_age)*N_pop, N_age, byrow = TRUE),
             tau_S = runif(1, 0.5, 1)
           ),
           
           RR_SS_pp = list(
             # This is currently not based on the input data
             mu_alpha = runif(1, 3, 6), 
             sigma_alpha = runif(1, 0.1, 0.5),
             zeta_alpha = array(runif(N_pop, -1, 1)), 
             mu_Rmax = rnorm(1, log(quantile(S_obs/A, 0.9, na.rm = TRUE)), 0.5),
             sigma_Rmax = runif(1, 0.1, 0.5),
             zeta_Rmax = array(runif(N_pop, -1, 1)), 
             rho_alphaRmax = runif(1, -0.5, 0.5),
             rho_R = runif(1, 0.1, 0.7),
             sigma_year_R = runif(1, 0.1, 0.5), 
             sigma_R = runif(1, 0.1, 2)
           ),
           
           RR_SS_np = list(
             # This is currently not based on the input data
             alpha = array(exp(runif(N_pop, 1, 3))),
             Rmax = array(exp(runif(N_pop, -1, 0))),
             rho_R = array(runif(N_pop, 0.1, 0.7)),
             sigma_R = array(runif(N_pop, 0.5, 1))
           )
    )  # end switch()
  })  # end lappply()
  
  return(out)
}
