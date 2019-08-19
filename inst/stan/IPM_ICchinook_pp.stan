functions {
  // spawner-recruit functions
  real SR(int SR_fun, real alpha, real Rmax, real S, real A) {
    real R;
    
    if(SR_fun == 1)      // discrete exponential
      R = alpha*S/A;
    else if(SR_fun == 2) // Beverton-Holt
      R = alpha*S/(A + alpha*S/Rmax);
    else if(SR_fun == 3) // Ricker
      R = alpha*(S/A)*exp(-alpha*S/(A*e()*Rmax));
    
    return(R);
  }
  
  // Generalized normal (aka power-exponential) unnormalized log-probability
  real pexp_lpdf(real y, real mu, real sigma, real shape) {
    return(-(fabs(y - mu)/sigma)^shape);
  }
  
  // convert matrix to array of column vectors
  vector[] matrix_to_array(matrix m) {
    vector[2] arr[cols(m)];
    
    for(i in 1:cols(m))
      arr[i] = col(m,i);
    return(arr);
  }

  // Vectorized logical equality
  int[] veq(int[] x, int y) {
    int xeqy[size(x)];
    for(i in 1:size(x))
      xeqy[i] = x[i] == y;
    return(xeqy);
  }

  // Vectorized logical &&
  int[] vand(int[] cond1, int[] cond2) {
    int cond1_and_cond2[size(cond1)];
    for(i in 1:size(cond1))
      cond1_and_cond2[i] = cond1[i] && cond2[i];
    return(cond1_and_cond2);
  }

  // R-style conditional subsetting
  int[] rsub(int[] x, int[] cond) {
    int xsub[sum(cond)];
    int pos;
    pos = 1;
    for (i in 1:size(x))
      if (cond[i])
      {
        xsub[pos] = x[i];
        pos = pos + 1;
      }
    return(xsub);
  }

  // Equivalent of R: which(cond), where sum(cond) == 1
  int which(int[] cond) {
    int which_cond;
    for(i in 1:size(cond))
      if(cond[i])
        which_cond = i;
      return(which_cond);
  }
  
  // Left multiply vector by matrix
  // works even if size is zero
  vector mat_lmult(matrix X, vector v)
  {
    vector[rows(X)] Xv;
    Xv = rows_dot_product(X, rep_matrix(to_row_vector(v), rows(X)));
    return(Xv); 
  }
}

data {
  // info for observed data
  int<lower=1> N;                      // total number of cases in all pops and years
  int<lower=1,upper=N> pop[N];         // population identifier
  int<lower=1,upper=N> year[N];        // brood year identifier
  // info for forward simulations
  int<lower=0> N_fwd;                  // total number of cases in forward simulations
  int<lower=1,upper=N> pop_fwd[N_fwd]; // population identifier for forward simulations
  int<lower=1,upper=N+N_fwd> year_fwd[N_fwd]; // brood year identifier for forward simulations
  vector<lower=0>[N_fwd] A_fwd; // habitat area for each forward simulation
  vector<lower=0,upper=1>[N_fwd] F_rate_fwd; // fishing mortality for forward simulations
  vector<lower=0,upper=1>[N_fwd] B_rate_fwd; // broodstock take rate for forward simulations
  vector<lower=0,upper=1>[N_fwd] p_HOS_fwd;  // p_HOS for forward simulations
  // smolt production
  int<lower=1> SR_fun;                 // S-R model: 1 = exponential, 2 = BH, 3 = Ricker
  vector<lower=0>[N] A;                // habitat area associated with each spawner abundance obs
  int<lower=1> smolt_age;              // smolt age
  int<lower=0> N_X_M;                  // number of spawner-smolt productivity covariates
  matrix[max(append_array(year,year_fwd)),N_X_M] X_M; // spawner-smolt covariates (if none, use vector of zeros)
  // downstream, SAR, upstream survival
  int<lower=0> N_X_D;                  // number of juvenile downstream survival covariates
  matrix[max(append_array(year,year_fwd)),N_X_D] X_D; // downstream survival covariates (if none, use vector of zeros)
  int<lower=0> N_X_SAR;                  // number of smolt-to-adult survival (SAR) covariates
  matrix[max(append_array(year,year_fwd)),N_X_SAR] X_SAR; // SAR covariates (if none, use vector of zeros)
  int<lower=0> N_X_U;                  // number of adult upstream survival covariates
  matrix[max(append_array(year,year_fwd)),N_X_U] X_U; // upstream survival covariates (if none, use vector of zeros)
  ////// priors for survival from CJS go here //////
  // fishery and hatchery removals
  vector<lower=0,upper=1>[N] F_rate;   // fishing mortality of wild adults
  int<lower=0,upper=N> N_B;            // number of years with B_take > 0
  int<lower=1,upper=N> which_B[N_B];   // years with B_take > 0
  vector[N_B] B_take_obs;              // observed broodstock take of wild adults
  // spawner abundance
  int<lower=1,upper=N> N_S_obs;        // number of cases with non-missing spawner abundance obs 
  int<lower=1,upper=N> which_S_obs[N_S_obs]; // cases with non-missing spawner abundance obs
  vector<lower=0>[N] S_obs;            // observed annual total spawner abundance (not density)
  // spawner age structure
  int<lower=2> N_age;                  // number of adult age classes
  int<lower=2> max_age;                // maximum adult age
  matrix<lower=0>[N,N_age] n_age_obs;  // observed wild spawner age frequencies (all zero row = NA)  
  // H/W composition
  int<lower=0,upper=N> N_H;            // number of years with p_HOS > 0
  int<lower=1,upper=N> which_H[N_H];   // years with p_HOS > 0
  int<lower=0> n_W_obs[N_H];           // count of wild spawners in samples (assumes no NAs)
  int<lower=0> n_H_obs[N_H];           // count of hatchery spawners in samples (assumes no NAs)
}

transformed data {
  int<lower=1,upper=N> N_pop;        // number of populations
  int<lower=1,upper=N> N_year;       // number of years, not including forward simulations
  int<lower=1,upper=N> N_year_all;   // total number of years, including forward simulations
  int<lower=1> ocean_ages[N_age];    // ocean ages
  int<lower=2> ages[N_age];          // adult ages
  int<lower=0> n_HW_obs[N_H];        // total sample sizes for H/W frequencies
  int<lower=1> pop_year_indx[N];     // index of years within each pop, starting at 1
  int<lower=0,upper=N> fwd_init_indx[N_fwd,N_age]; // links "fitted" brood years to recruits in forward sims
  
  N_pop = max(pop);
  N_year = max(year);
  N_year_all = max(append_array(year, year_fwd));
  for(a in 1:N_age)
  {
    ages[a] = max_age - N_age + a;
    ocean_ages[a] = max_age - smolt_age - N_age + a;
  }
  for(i in 1:N_H) n_HW_obs[i] = n_H_obs[i] + n_W_obs[i];
  
  pop_year_indx[1] = 1;
  for(i in 1:N)
  {
    if(i == 1 || pop[i-1] != pop[i])
      pop_year_indx[i] = 1;
    else
      pop_year_indx[i] = pop_year_indx[i-1] + 1;
  }
  
  fwd_init_indx = rep_array(0, N_fwd, N_age);
  for(i in 1:N_fwd)
  {
    for(a in 1:N_age)
    {
      if(year_fwd[i] - ages[a] < min(rsub(year_fwd, veq(pop_fwd, pop_fwd[i]))))
        fwd_init_indx[i,a] = which(vand(veq(pop, pop_fwd[i]), veq(year, year_fwd[i] - ages[a])));
    }
  }
}

parameters {
  // smolt recruitment
  real mu_alpha;                         // hyper-mean log intrinsic productivity
  real<lower=0> sigma_alpha;             // hyper-SD log intrinsic productivity
  vector[N_pop] zeta_alpha;              // log intrinsic prod (Z-scores)
  real mu_Rmax;                          // hyper-mean log asymptotic recruitment
  real<lower=0> sigma_Rmax;              // hyper-SD log asymptotic recruitment
  vector[N_pop] zeta_Rmax;               // log asymptotic recruitment (Z-scores)
  real<lower=-1,upper=1> rho_alphaRmax;  // correlation between log(alpha) and log(Rmax)
  vector[N_X_M] beta_M;                  // regression coefs for spawner-smolt productivity
  real<lower=-1,upper=1> rho_M;          // AR(1) coef for spawner-smolt productivity
  real<lower=0> sigma_M;                 // spawner-smolt process error SD
  vector[N] zeta_M;                      // smolt recruitment process errors (Z-scores)
  vector<lower=0>[smolt_age*N_pop] M_init; // true smolt abundance in years 1:smolt_age
  real<lower=0> tau_M;                   // smolt abundance observation error SD 
  // downstream, SAR, upstream survival
  real<lower=0,upper=1> mu_D;            // mean logit downstream juvenile survival 
  vector[N_X_D] beta_D;                  // regression coefs for logit downstream juvenile survival
  real<lower=-1,upper=1> rho_D;          // AR(1) coef for logit downstream juvenile survival
  real<lower=0> sigma_D;                 // process error SD of logit downstream juvenile survival
  vector[N_year_all] zeta_D;             // logit downstream juvenile survival process errors (Z-scores)
  real<lower=0,upper=1> mu_SAR;          // mean logit smolt-to-adult survival 
  vector[N_X_SAR] beta_SAR;              // regression coefs for logit smolt-to-adult survival
  real<lower=-1,upper=1> rho_SAR;        // AR(1) coef for logit smolt-to-adult survival
  real<lower=0> sigma_SAR;               // process error SD of logit smolt-to-adult survival
  vector[N_year_all] zeta_SAR;           // logit smolt-to-adult survival process errors (Z-scores)
  real<lower=0,upper=1> mu_U;            // mean logit upstream adult survival 
  vector[N_X_U] beta_U;                  // regression coefs for logit upstream adult survival
  real<lower=-1,upper=1> rho_U;          // AR(1) coef for logit upstream adult survival
  real<lower=0> sigma_U;                 // process error SD of logit upstream adult survival
  vector[N_year_all] zeta_U;             // logit upstream adult survival process errors (Z-scores)
  // spawner age structure
  simplex[N_age] mu_p;                   // among-pop mean of age distributions
  vector<lower=0>[N_age-1] sigma_gamma;  // among-pop SD of mean log-ratio age distributions
  cholesky_factor_corr[N_age-1] L_gamma; // Cholesky factor of among-pop correlation matrix of mean log-ratio age distns
  matrix[N_pop,N_age-1] zeta_gamma;      // population mean log-ratio age distributions (Z-scores)
  vector<lower=0>[N_age-1] sigma_p;      // SD of log-ratio cohort age distributions
  cholesky_factor_corr[N_age-1] L_p;     // Cholesky factor of correlation matrix of cohort log-ratio age distributions
  matrix[N,N_age-1] zeta_p;              // log-ratio cohort age distributions (Z-scores)
  // H/W composition, removals
  vector<lower=0,upper=1>[N_H] p_HOS;    // true p_HOS in years which_H
  vector<lower=0,upper=1>[N_B] B_rate;   // true broodstock take rate when B_take > 0
  // initial spawners, observation error
  vector<lower=0>[max_age*N_pop] S_init; // true total spawner abundance in years 1-max_age
  simplex[N_age] q_init[max_age*N_pop];  // true wild spawner age distributions in years 1-max_age
  real<lower=0> tau_S;                   // observation error SD of total spawners
}

transformed parameters {
  // smolt recruitment
  vector<lower=0>[N_pop] alpha;          // intrinsic productivity 
  vector<lower=0>[N_pop] Rmax;           // asymptotic recruitment 
  vector<lower=0>[N] M_hat;              // expected smolt abundance (not density) by brood year
  vector[N] epsilon_M;                   // process error in smolt abundance by brood year 
  vector<lower=0>[N] M0;                 // true smolt abundance (not density) by brood year
  vector<lower=0>[N] M;                  // true smolt abundance (not density) by outmigration year
  // downstream, SAR, upstream survival
  vector[N_year_all] epsilon_D;          // process error in downstream survival by outmigration year
  vector[N_year_all] s_D;                // true downstream survival by outmigration year
  vector[N_year_all] epsilon_SAR;        // process error in SAR by outmigration year
  vector[N_year_all] SAR;                // true SAR by outmigration year
  vector[N_year_all] epsilon_U;          // process error in upstream survival by return year
  vector[N_year_all] s_U;                // true upstream survival by return year
  // spawner age structure
  matrix<lower=0,upper=1>[N,N_age] q;    // true spawner age distributions
  row_vector[N_age-1] mu_gamma;          // mean of log-ratio cohort age distributions
  matrix[N_pop,N_age-1] gamma;           // population mean log-ratio age distributions
  matrix<lower=0,upper=1>[N,N_age] p;    // true adult age distributions by outmigration year
  // H/W spawner abundance, removals
  vector<lower=0>[N] S_W;                // true total wild spawner abundance
  vector[N] S_H;                         // true total hatchery spawner abundance (can == 0)
  vector<lower=0>[N] S;                  // true total spawner abundance
  vector[N] p_HOS_all;                   // true p_HOS in all years (can == 0)
  vector<lower=0,upper=1>[N] B_rate_all; // true broodstock take rate in all years
  
  // Multivariate Matt trick for [log(alpha), log(Rmax)]
  {
    matrix[2,2] L_alphaRmax;           // temp variable: Cholesky factor of corr matrix of log(alpha), log(Rmax)
    matrix[N_pop,2] zeta_alphaRmax;    // temp variable [log(alpha), log(Rmax)] random effects (z-scored)
    matrix[N_pop,2] epsilon_alphaRmax; // temp variable: [log(alpha), log(Rmax)] random effects
    vector[2] sigma_alphaRmax;         // temp variable: SD vector of [log(alpha), log(Rmax)]
    
    L_alphaRmax[1,1] = 1;
    L_alphaRmax[2,1] = rho_alphaRmax;
    L_alphaRmax[1,2] = 0;
    L_alphaRmax[2,2] = sqrt(1 - rho_alphaRmax^2);
    sigma_alphaRmax[1] = sigma_alpha;
    sigma_alphaRmax[2] = sigma_Rmax;
    zeta_alphaRmax = append_col(zeta_alpha, zeta_Rmax);
    epsilon_alphaRmax = (diag_matrix(sigma_alphaRmax) * L_alphaRmax * zeta_alphaRmax')';
    alpha = exp(mu_alpha + col(epsilon_alphaRmax,1));
    Rmax = exp(mu_Rmax + col(epsilon_alphaRmax,2));
  }

  // AR(1) models for downstream, SAR, upstream survival
  epsilon_D[1] = zeta_D[1]*sigma_D/sqrt(1 - rho_D^2); 
  epsilon_SAR[1] = zeta_SAR[1]*sigma_SAR/sqrt(1 - rho_SAR^2); 
  epsilon_U[1] = zeta_U[1]*sigma_U/sqrt(1 - rho_U^2);
  for(i in 2:N_year_all)
  {
    epsilon_D[i] = rho_D*epsilon_D[i-1] + zeta_D[i]*sigma_D;
    epsilon_SAR[i] = rho_SAR*epsilon_SAR[i-1] + zeta_SAR[i]*sigma_SAR;
    epsilon_U[i] = rho_U*epsilon_U[i-1] + zeta_U[i]*sigma_U;
  }
  // constrain process errors to sum to 0 (columns of X should be centered)
  s_D = inv_logit(logit(mu_D) + mat_lmult(X_D,beta_D) + epsilon_D - mean(epsilon_D[1:N_year]));
  SAR = inv_logit(logit(mu_SAR) + mat_lmult(X_SAR,beta_SAR) + epsilon_SAR - mean(epsilon_SAR[1:N_year]));
  s_U = inv_logit(logit(mu_U) + mat_lmult(X_U,beta_U) + epsilon_U - mean(epsilon_U[1:N_year]));
  
  // Pad p_HOS and B_rate
  p_HOS_all = rep_vector(0,N);
  p_HOS_all[which_H] = p_HOS;
  B_rate_all = rep_vector(0,N);
  B_rate_all[which_B] = B_rate;
  
  // Multivariate Matt trick for age vectors
  mu_gamma = to_row_vector(log(mu_p[1:(N_age-1)]) - log(mu_p[N_age]));
  // pop-specific mean
  gamma = rep_matrix(mu_gamma,N_pop) + (diag_matrix(sigma_gamma) * L_gamma * zeta_gamma')';
  // within-pop, time-varying IID
  p = append_col(gamma[pop,] + (diag_matrix(sigma_p) * L_p * zeta_p')', rep_vector(0,N));
  
  // Calculate true total wild and hatchery spawners and spawner age distribution
  // and predict recruitment from brood year i
  for(i in 1:N)
  {
    row_vector[N_age] exp_p; // temp variable: exp(p[i,])
    row_vector[N_age] S_W_a; // temp variable: true wild spawners by age
    int ii;                  // temp variable: index into S_init and q_init
    
    // Inverse log-ratio transform of cohort age distn
    // (built-in softmax function doesn't accept row vectors)
    exp_p = exp(p[i,]);
    p[i,] = exp_p/sum(exp_p);
    
    // AR(1) smolt recruitment process errors  
    if(pop_year_indx[i] == 1) 
      epsilon_M[i] = zeta_M[i]*sigma_M/sqrt(1 - rho_M^2);
    else
      epsilon_M[i] = rho_M*epsilon_M[i-1] + zeta_M[i]*sigma_M;

    // Smolt recruitment
    if(pop_year_indx[i] <= smolt_age)
      M[i] = M_init[(pop[i]-1)*smolt_age + pop_year_indx[i]];  // use initial values
    else
      M[i] = M0[i-smolt_age];  // smolts from appropriate brood year
    
    // Spawner recruitment and age structure
    if(pop_year_indx[i] <= max_age)
    {
      // Use initial values
      ii = (pop[i] - 1)*max_age + pop_year_indx[i];
      S_W[i] = S_init[ii]*(1 - p_HOS_all[i]);        
      S_H[i] = S_init[ii]*p_HOS_all[i];
      q[i,] = to_row_vector(q_init[ii,]);
      S_W_a = S_W[i]*q[i,];
    }
    else
    {
      // Use recruitment process model
      for(a in 1:N_age)
        S_W_a[a] = M[i-ocean_ages[a]]*s_D[i-ocean_ages[a]]*SAR[i-ocean_ages[a]]*p[i-ocean_ages[a],a]*s_U[i];
      // catch and broodstock removal (assumes no take of age 1)
      S_W_a[2:N_age] = S_W_a[2:N_age]*(1 - F_rate[i])*(1 - B_rate_all[i]);
      S_W[i] = sum(S_W_a);
      S_H[i] = S_W[i]*p_HOS_all[i]/(1 - p_HOS_all[i]);
      q[i,] = S_W_a/S_W[i];
    }
    
    S[i] = S_W[i] + S_H[i];
    
    // Smolt production from brood year i
    M_hat[i] = A[i] * SR(SR_fun, alpha[pop[i]], Rmax[pop[i]], S[i], A[i]);
    M0[i] = M_hat[i]*exp(dot_product(X_M[year[i],], beta_M) + epsilon_M[i]); 
  }
}

model {
  vector[N_B] B_take; // true broodstock take when B_take_obs > 0
  
  // Priors
  
  // smolt production
  mu_alpha ~ normal(2,5);
  sigma_alpha ~ pexp(0,3,10);
  mu_Rmax ~ normal(0,10);
  sigma_Rmax ~ pexp(0,3,10);
  // log([alpha,Rmax]) ~ MVN([mu_alpha,mu_Rmax], D*R_aRmax*D), where D = diag_matrix(sigma_alpha,sigma_Rmax)
  zeta_alpha ~ normal(0,1);
  zeta_Rmax ~ normal(0,1);
  beta_M ~ normal(0,5);
  rho_M ~ pexp(0,0.85,50); // mildly regularize to ensure stationarity
  sigma_M ~ pexp(0,2,10);
  zeta_M ~ normal(0,1);    // epsilon_M ~ AR1(rho_M, sigma_M)
  M_init ~ lognormal(0,5);
  tau_M ~ pexp(0,1,10);
  
  // downstream, SAR, upstream survival
  beta_D ~ normal(0,5);
  rho_D ~ pexp(0,0.85,50);   // mildly regularize to ensure stationarity
  sigma_D ~ pexp(0,2,10);
  zeta_D ~ normal(0,1);      // epsilon_D ~ AR1(rho_D, sigma_D)
  ////// informative prior on s_D goes here
  beta_SAR ~ normal(0,5);
  rho_SAR ~ pexp(0,0.85,50); // mildly regularize to ensure stationarity
  sigma_SAR ~ pexp(0,2,10);
  zeta_SAR ~ normal(0,1);    // epsilon_SAR ~ AR1(rho_SAR, sigma_SAR)
  ////// informative prior on SAR goes here
  beta_U ~ normal(0,5);
  rho_U ~ pexp(0,0.85,50);   // mildly regularize to ensure stationarity
  sigma_U ~ pexp(0,2,10);
  zeta_U ~ normal(0,1);      // epsilon_U ~ AR1(rho_U, sigma_U)
  ////// informative prior on s_U goes here
  
  // spawner age structure
  for(i in 1:(N_age-1))
  {
    sigma_gamma[i] ~ pexp(0,2,5);
    sigma_p[i] ~ pexp(0,2,5); 
  }
  L_gamma ~ lkj_corr_cholesky(1);
  L_p ~ lkj_corr_cholesky(1);
  // gamma[i,] ~ MVN(mu_gamma,D*R_gamma*D), where D = diag_matrix(sigma_gamma)
  to_vector(zeta_gamma) ~ normal(0,1);
  // age probs logistic MVN: 
  // alr_p[i,] ~ MVN(gamma[pop[i],], D*R_p*D), 
  // where D = diag_matrix(sigma_p)
  to_vector(zeta_p) ~ normal(0,1);
  
  // initial spawners, observation error, removals
  S_init ~ lognormal(0,10);
  tau_S ~ pexp(0,1,10);
  B_take = B_rate .* S_W[which_B] .* (1 - q[which_B,1]) ./ (1 - B_rate);
  B_take_obs ~ lognormal(log(B_take), 0.1); // penalty to force pred and obs broodstock take to match 

  // Observation model
  S_obs[which_S_obs] ~ lognormal(log(S[which_S_obs]), tau_S);  // observed spawners
  n_H_obs ~ binomial(n_HW_obs, p_HOS); // observed counts of hatchery vs. wild spawners
  target += sum(n_age_obs .* log(q));  // obs wild age freq: n_age_obs[i] ~ multinomial(q[i])
}

generated quantities {
  corr_matrix[N_age-1] R_gamma;     // among-pop correlation matrix of mean log-ratio age distns 
  corr_matrix[N_age-1] R_p;         // correlation matrix of within-pop cohort log-ratio age distns 
  // vector<lower=0>[N_fwd] S_W_fwd;   // true total wild spawner abundance in forward simulations
  // vector[N_fwd] S_H_fwd;            // true total hatchery spawner abundance in forward simulations
  // vector<lower=0>[N_fwd] S_fwd;     // true total spawner abundance in forward simulations
  // matrix<lower=0,upper=1>[N_fwd,N_age] p_fwd; // cohort age distributions in forward simulations
  // matrix<lower=0,upper=1>[N_fwd,N_age] q_fwd; // spawner age distributions in forward simulations
  // vector<lower=0>[N_fwd] R_hat_fwd; // expected recruit abundance by brood year in forward simulations
  // vector<lower=0>[N_fwd] R_fwd;     // true recruit abundance by brood year in forward simulations
  vector[N] LL_S_obs;               // pointwise log-likelihood of total spawners
  vector[N_H] LL_n_H_obs;           // pointwise log-likelihood of hatchery vs. wild frequencies
  vector[N] LL_n_age_obs;           // pointwise log-likelihood of wild age frequencies
  vector[N] LL;                     // total pointwise log-likelihood                              
  
  R_gamma = multiply_lower_tri_self_transpose(L_gamma);
  R_p = multiply_lower_tri_self_transpose(L_p);
  
  // // Calculate true total wild and hatchery spawners and spawner age distribution
  // // and simulate recruitment from brood year i
  // // (Note that if N_fwd == 0, this block will not execute)
  // for(i in 1:N_fwd)
  // {
  //   vector[N_age-1] alr_p_fwd;   // temp variable: alr(p_fwd[i,])'
  //   row_vector[N_age] S_W_a_fwd; // temp variable: true wild spawners by age
  // 
  //   // Inverse log-ratio transform of cohort age distn
  //   alr_p_fwd = multi_normal_cholesky_rng(to_vector(gamma[pop_fwd[i],]), L_p);
  //   p_fwd[i,] = to_row_vector(softmax(append_row(alr_p_fwd,0)));
  // 
  //   for(a in 1:N_age)
  //   {
  //     if(fwd_init_indx[i,a] != 0)
  //     {
  //       // Use estimated values from previous cohorts
  //       S_W_a_fwd[a] = R[fwd_init_indx[i,a]]*p[fwd_init_indx[i,a],a];
  //     }
  //     else
  //     {
  //       S_W_a_fwd[a] = R_fwd[i-ages[a]]*p_fwd[i-ages[a],a];
  //     }
  //   }
  // 
  //   for(a in 2:N_age)  // catch and broodstock removal (assumes no take of age 1)
  //     S_W_a_fwd[a] = S_W_a_fwd[a]*(1 - F_rate_fwd[i])*(1 - B_rate_fwd[i]);
  // 
  //   S_W_fwd[i] = sum(S_W_a_fwd);
  //   S_H_fwd[i] = S_W_fwd[i]*p_HOS_fwd[i]/(1 - p_HOS_fwd[i]);
  //   q_fwd[i,] = S_W_a_fwd/S_W_fwd[i];
  //   S_fwd[i] = S_W_fwd[i] + S_H_fwd[i];
  //   R_hat_fwd[i] = A_fwd[i] * SR(SR_fun, alpha[pop_fwd[i]], Rmax[pop_fwd[i]], S_fwd[i], A_fwd[i]);
  //   R_fwd[i] = lognormal_rng(log(R_hat_fwd[i]) + phi[year_fwd[i]], sigma);
  // }
  
  LL_S_obs = rep_vector(0,N);
  for(i in 1:N_S_obs)
    LL_S_obs[which_S_obs[i]] = lognormal_lpdf(S_obs[which_S_obs[i]] | log(S[which_S_obs[i]]), tau); 
  LL_n_age_obs = (n_age_obs .* log(q)) * rep_vector(1,N_age);
  LL_n_H_obs = rep_vector(0,N_H);
  for(i in 1:N_H)
    LL_n_H_obs[i] = binomial_lpmf(n_H_obs[i] | n_HW_obs[i], p_HOS[i]);
  LL = LL_S_obs + LL_n_age_obs;
  LL[which_H] = LL[which_H] + LL_n_H_obs;
}
