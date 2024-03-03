#line 2 202
/**
 * Functions to generate normal/binomial distributed random numbers.
 *
 * The normal distribution is being approximated using Inversion Sampling with a GPU optimized approximation of
 * the inverse error function described in:
 * Giles, Mike. "Approximating the erfinv function." GPU Computing Gems Jade Edition. Morgan Kaufmann, 2012. 109-116.
 *
 * The binomial distribution is being approximated using the Gated Gaussian Binomial Approximation approach described in:
 * Deliot, T., and L. Belcour. "Real-Time Rendering of Glinty Appearances using Distributed Binomial Laws on Anisotropic Grids." (2023)
 * 
 * NOTE: Alternatively the normal distribution could be approximated using the Box-Muller transform or Ziggurat algorithm.
 */

/**
 * The inverse error function approximation described in:
 * Giles, Mike. "Approximating the erfinv function." GPU Computing Gems Jade Edition. Morgan Kaufmann, 2012. 109-116.
 */
// ! This is executed 4*3*4=48 times per sample
float erfinv(float x) {
    float w, p;
    w = -log((1.0 - x) * (1.0 + x));
    if (w < 5.000000) {
        w = w - 2.500000;
        p =        2.81022636e-08;
        p =  3.43273939e-07 + p*w;
        p =  -3.5233877e-06 + p*w;
        p = -4.39150654e-06 + p*w;
        p =   0.00021858087 + p*w;
        p =  -0.00125372503 + p*w;
        p =  -0.00417768164 + p*w;
        p =     0.246640727 + p*w;
        p =      1.50140941 + p*w;
    } else {
        w = sqrt(w) - 3.000000;
        p =      -0.000200214257;
        p = 0.000100950558 + p*w;
        p =  0.00134934322 + p*w;
        p = -0.00367342844 + p*w;
        p =  0.00573950773 + p*w;
        p =  -0.0076224613 + p*w;
        p =  0.00943887047 + p*w;
        p =     1.00167406 + p*w;
        p =     2.83297682 + p*w;
    }
    return p*x;
}

/**
 * Converts a uniform random number of range [0, 1] to a normal distributed random number using Inversion Sampling.
 * 
 * @param rand A uniform random number in the range [0, 1]. 
 */
float sampleNormal(float rand) {
    return sqrt(2.0) * erfinv(2.0 * rand - 1.0);
}

/**
 * Converts a uniform random vector of range [0, 1] to a normal distributed random vector using Inversion Sampling.
 * 
 * @param rand A uniform random vector in the range [0, 1]. 
 */
vec3 sampleNormal(vec3 rand) {
    vec3 rand11 = 2.0 * rand - 1.0;
    return sqrt(2.0) * vec3(erfinv(rand11.x), erfinv(rand11.y), erfinv(rand11.z));
}

/**
 * Converts a uniform random vector of range [0, 1] to a normal distributed random vector using Inversion Sampling.
 * 
 * @param rand A uniform random vector in the range [0, 1]. 
 */
vec4 sampleNormal(vec4 rand) {
    vec4 rand11 = 2.0 * rand - 1.0;
    return sqrt(2.0) * vec4(erfinv(rand11.x), erfinv(rand11.y), erfinv(rand11.z), erfinv(rand11.w));
}

/**
 * Converts a uniform random number of range [0, 1] to a normal distributed random number using Inversion Sampling.
 *
 * @param mu The mean of the normal distribution.
 * @param sigma The standard deviation of the normal distribution.
 * @param rand A uniform random number in the range [0, 1]. 
 */
float sampleNormal(float mu, float sigma, float rand) {
    return mu + sigma * sampleNormal(rand);
}

/**
 * Converts a uniform random vector of range [0, 1] to a normal distributed random vector using Inversion Sampling.
 *
 * @param mu The mean of the normal distribution.
 * @param sigma The standard deviation of the normal distribution.
 * @param rand A uniform random vector in the range [0, 1]. 
 */
vec3 sampleNormal(float mu, float sigma, vec3 rand) {
    return mu + sigma * sampleNormal(rand);
}

/**
 * Converts a uniform random vector of range [0, 1] to a normal distributed random vector using Inversion Sampling.
 *
 * @param mu The mean of the normal distribution.
 * @param sigma The standard deviation of the normal distribution.
 * @param rand A uniform random vector in the range [0, 1]. 
 */
vec4 sampleNormal(float mu, float sigma, vec4 rand) {
    return mu + sigma * sampleNormal(rand);
}

/**
 * Samples a binomial distributed random number using the Gated Gaussian Binomial Approximation.
 *
 * @param N The number of trials.
 * @param p The probability of success.
 * @param rand Two uniform random numbers in the range [0, 1].
 */
float sampleBinom(float N, float p, vec2 rand) {
    // The probability of having at least one success in a binomial distribution b(N,p)
    float pOneSuccess = 1.0 - pow(1.0 - p, N); // Equation (16)
    // Compute the parameters of the normal approximation of the binomial distribution for one less sample, b(N-1,p)
    float mu = (N - 1.0) * p;
    float sigma = sqrt((N - 1.0) * p * (1.0 - p)); // Equation (17)
    // Approximate the binomial distribution b(N-1,p) by sampling from the normal distribution N(mu,sigma)
    float normalSample = clamp(floor(sampleNormal(mu, sigma, rand.y)) + 1.0, 1.0, N); // Clamping to ensure valid range
    // Gate the normal sample using a single Bernoulli trial
    float gated = rand.x < pOneSuccess ? normalSample : 0.0; // Equation (18)
    return gated;
}

/**
 * Samples a binomial distributed random vector using the Gated Gaussian Binomial Approximation.
 *
 * @param N The number of trials.
 * @param p The probability of success.
 * @param rand Two uniform random vectors in the range [0, 1].
 */
// ! Performance issue: No vectorization
vec4 sampleBinom(float N, float p, vec4 randA, vec4 randB) {
    // The probability of having at least one success in a binomial distribution b(N,p)
    float pOneSuccess = 1.0 - pow(1.0 - p, N); // Equation (16)
    // Compute the parameters of the normal approximation of the binomial distribution for one less sample, b(N-1,p)
    float mu = (N - 1.0) * p;
    float sigma = sqrt((N - 1.0) * p * (1.0 - p)); // Equation (17)
    // Approximate the binomial distribution b(N-1,p) by sampling from the normal distribution N(mu,sigma)
    vec4 normalSample = clamp(floor(sampleNormal(mu, sigma, randB)) + 1.0, 1.0, N); // Clamping to ensure valid range
    // Gate the normal sample using a single Bernoulli trial
    vec4 gated = mix(vec4(0.0), normalSample, lessThan(randA, vec4(pOneSuccess))); // Equation (18)
    return gated;
}

/**
 * Samples 4 binomial distributed random numbers using the Gated Gaussian Binomial Approximation.
 * Faster version that uses precalculations to avoid redundant computations.
 *
 * @param N The number of trials.
 * @param pOneSuccess The probability of having at least one success in a binomial distribution b(N,p).
 * @param mu The mean of the normal distribution.
 * @param sigma The standard deviation of the normal distribution.
 * @param rand Two uniform random vectors in the range [0, 1].
 */
// ! This is executed 4*3=12 times per sample
vec4 sampleBinom(float N, float pOneSuccess, float mu, float sigma, vec4 randA, vec4 randB) {
    // Approximate the binomial distribution b(N-1,p) by sampling from the normal distribution N(mu,sigma)
    // vec4 normalSample = clamp(floor(sampleNormal(mu, sigma, randB)) + 1.0, 1.0, N); // Wrong clamping
    vec4 normalSample = clamp(floor(sampleNormal(mu, sigma, randB)), 0.0, N) + 1.0; // Why is this clamping correct? normalSample can become N+1
    // Gate the normal sample using a single Bernoulli trial
    vec4 gated = mix(vec4(0.0), normalSample, lessThan(randA, vec4(pOneSuccess))); // Equation (18)
    return gated;
}
