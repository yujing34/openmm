#if USE_EWALD
bool needCorrection = hasExclusions && isExcluded && atom1 != atom2 && atom1 < NUM_ATOMS && atom2 < NUM_ATOMS;
if (!isExcluded || needCorrection) {
    if (r2 < CUTOFF_SQUARED || needCorrection) {
        const real alphaR = EWALD_ALPHA*r;
        const real expAlphaRSqr = EXP(-alphaR*alphaR);
        const real prefactor = 138.935456f*posq1.w*posq2.w*invR;

#ifdef USE_DOUBLE_PRECISION
       const real erfcAlphaR = erfc(alphaR);
#else
        // This approximation for erfc is from Abramowitz and Stegun (1964) p. 299.  They cite the following as
        // the original source: C. Hastings, Jr., Approximations for Digital Computers (1955).  It has a maximum
        // error of 3e-7.

        real t = 1.0f+(0.0705230784f+(0.0422820123f+(0.0092705272f+(0.0001520143f+(0.0002765672f+0.0000430638f*alphaR)*alphaR)*alphaR)*alphaR)*alphaR)*alphaR;
        t *= t;
        t *= t;
        t *= t;
        const real erfcAlphaR = RECIP(t*t);
#endif
        real tempForce = 0;
        if (needCorrection) {
            // Subtract off the part of this interaction that was included in the reciprocal space contribution.

            tempForce = -prefactor*((1.0f-erfcAlphaR)-alphaR*expAlphaRSqr*TWO_OVER_SQRT_PI);
            tempEnergy += -prefactor*(1.0f-erfcAlphaR);
        }
        else {
#if HAS_LENNARD_JONES
            real sig = sigmaEpsilon1.x + sigmaEpsilon2.x;
            real sig2 = invR*sig;
            sig2 *= sig2;
            real sig6 = sig2*sig2*sig2;
            real epssig6 = sig6*(sigmaEpsilon1.y*sigmaEpsilon2.y);
            tempForce = epssig6*(12.0f*sig6 - 6.0f) + prefactor*(erfcAlphaR+alphaR*expAlphaRSqr*TWO_OVER_SQRT_PI);
            tempEnergy += epssig6*(sig6 - 1.0f) + prefactor*erfcAlphaR;
#else
            tempForce = prefactor*(erfcAlphaR+alphaR*expAlphaRSqr*TWO_OVER_SQRT_PI);
            tempEnergy += prefactor*erfcAlphaR;
#endif
        }
        dEdR += tempForce*invR*invR;
    }
}
#else
{
#ifdef USE_DOUBLE_PRECISION
    unsigned long includeInteraction;
#else
    unsigned int includeInteraction;
#endif
#ifdef USE_CUTOFF
    includeInteraction = (!isExcluded && r2 < CUTOFF_SQUARED);
#else
    includeInteraction = (!isExcluded);
#endif
    real tempForce = 0;
  #if HAS_LENNARD_JONES
    real sig = sigmaEpsilon1.x + sigmaEpsilon2.x;
    real sig2 = invR*sig;
    sig2 *= sig2;
    real sig6 = sig2*sig2*sig2;
    real epssig6 = sig6*(sigmaEpsilon1.y*sigmaEpsilon2.y);
    tempForce = epssig6*(12.0f*sig6 - 6.0f);
    tempEnergy += select((real) 0, epssig6*(sig6-1), includeInteraction);
  #endif
#if HAS_COULOMB
  #ifdef USE_CUTOFF
    const real prefactor = 138.935456f*posq1.w*posq2.w;
    tempForce += prefactor*(invR - 2.0f*REACTION_FIELD_K*r2);
    tempEnergy += select((real) 0, prefactor*(invR + REACTION_FIELD_K*r2 - REACTION_FIELD_C), includeInteraction);
  #else
    const real prefactor = 138.935456f*posq1.w*posq2.w*invR;
    tempForce += prefactor;
    tempEnergy += select((real) 0, prefactor, includeInteraction);
  #endif
#endif
    dEdR += select((real) 0, tempForce*invR*invR, includeInteraction);
}
#endif