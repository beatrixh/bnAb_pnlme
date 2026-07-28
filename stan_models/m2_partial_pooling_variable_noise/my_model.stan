functions {
    vector fourpl(vector x, real L, real m, real c, real U){
        return U + (L-U)/(1 + pow((x/c),m));
    }
}
data {
    int<lower=0> N; // # total data points
    int<lower=0> K; // # mab-viruses
    vector[N] x_flat;
    vector[N] y_flat;
    array[K] int group_sizes;
}
parameters {
    vector<lower=0>[K] m; // m for each mab-virus group
    vector<lower=0>[K] c; // c for each mab-virus group
    vector<lower=0>[K] U; // U for each mab-virus group
    vector<lower=0>[K] L;

    real sigma_m; // this could maybe be a vector if want each mab-virus group to have different variance?
    real sigma_c; // could be a vector? if want variable variance for diff mab-virus? need to make sure that doesnt cause anythign strange
    real sigma_U; // could be a vector? if want variable variance for diff mab-virus? need to make sure that doesnt cause anythign strange

    vector[K] alpha_m; // mean for each mab-virus group distribution
    vector[K] alpha_c; // mean for each mab-virus group distribution
    vector[K] alpha_U; // mean for each mab-virus group distribution

    real mu_m; // mean for dist that alpha_ms drawn from
    real mu_c; // mean for dist that alpha_cs drawn from
    real mu_U; // mean for dist that alpha_Us drawn from

    real sigma_alpha_m; // var for dist that alpha_ms drawn from
    real sigma_alpha_c; // var for dist that alpha_cs drawn from
    real sigma_alpha_U; // var for dist that alpha_Us drawn from

    real<lower=0> sigma;

}
transformed parameters {

}
model {
    // noise scalar -- expecting it to fit approx 0.84406193
    sigma ~ normal(0.84406193, 1);

    // mab-virus level
    for (j in 1:K){
        m[j] ~ lognormal(alpha_m[j], sigma_m);
        c[j] ~ lognormal(alpha_c[j], sigma_c);
        U[j] ~ normal(alpha_U[j], sigma_U);
    }

    // population priors
    alpha_m ~ normal(mu_m, sigma_alpha_m);
    alpha_c ~ normal(mu_c, sigma_alpha_c);
    alpha_U ~ normal(mu_U, sigma_alpha_U);

    L ~ normal(0.0,0.2);

    int pos;
    pos = 1;
    for (i in 1:K){
        int ni = group_sizes[i];
        vector[ni] x_i = segment(x_flat, pos, ni);
        vector[ni] y_i = segment(y_flat, pos, ni);
        vector[ni] mu_i = fourpl(x_i, L[i], m[i], c[i], U[i]);
        y_i ~ normal(mu_i, sigma*mu_i);
        pos = pos + ni;
    }
}
generated quantities {
  vector[N] log_lik;
  int pos = 1;
  for (i in 1:K) {
    int ni = group_sizes[i];
    vector[ni] x_i = segment(x_flat, pos, ni);
    vector[ni] y_i = segment(y_flat, pos, ni);
    vector[ni] mu_i = fourpl(x_i, L[i], m[i], c[i], U[i]);
    for (j in 1:ni) {
      log_lik[pos + j - 1] = normal_lpdf(y_i[j] | mu_i[j], sigma*mu_i[j]);
    }
    pos += ni;
  }
}
