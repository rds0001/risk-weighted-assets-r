# Shared default contract for formula and portfolio APIs.
irb_default_flag <- function(value) {
  regulatory_bool(value, "default_flag")
}

irb_rate <- function(value, name) {
  if (!is.numeric(value) || length(value) != 1L || !is.finite(value) ||
      value < 0 || value > 1) stop(name, " must be a finite rate in [0, 1]", call. = FALSE)
  value
}

irb_effective_pd <- function(pd, defaulted, floor = 0) {
  if (!is.logical(defaulted) || length(defaulted) != 1L || is.na(defaulted))
    stop("defaulted must be a boolean", call. = FALSE)
  value <- max(irb_rate(pd, "pd"), irb_rate(floor, "pd_floor"))
  if (!defaulted && value == 1) stop("PD = 1 contradicts defaulted=FALSE", call. = FALSE)
  if (defaulted) 1 else value
}

irb_treatment_for <- function(approach, subclass) {
  retail <- subclass %in% c("RETAIL_RESIDENTIAL", "RETAIL_QRRE", "RETAIL_OTHER")
  if (!approach %in% c("FIRB", "AIRB"))
    stop("Unsupported irb_approach; SLOTTING requires a separate implementation", call. = FALSE)
  if (!retail && !subclass %in% c("CORPORATE", "INSTITUTION", "SOVEREIGN"))
    stop("Unsupported irb_subclass: ", subclass, call. = FALSE)
  if (retail && approach != "AIRB")
    stop("Retail IRB requires AIRB / OWN_ESTIMATES, not FIRB", call. = FALSE)
  if (approach == "FIRB") "SUPERVISORY" else "OWN_ESTIMATES"
}

irb_resolve <- function(pd, lgd, defaulted, elbe, treatment) {
  pd <- irb_effective_pd(pd, defaulted)
  lgd <- irb_rate(lgd, "lgd")
  if (!is.null(treatment) && (length(treatment) != 1L ||
      !treatment %in% c("SUPERVISORY", "OWN_ESTIMATES")))
    stop("lgd_treatment must be SUPERVISORY or OWN_ESTIMATES", call. = FALSE)
  if (defaulted) {
    if (is.null(treatment)) stop("lgd_treatment is required for defaulted exposures", call. = FALSE)
    if (treatment == "SUPERVISORY") return(list(pd = pd, k = 0, el_rate = pd * lgd))
    elbe <- irb_rate(elbe, "elbe")
    return(list(pd = pd, k = max(lgd - elbe, 0), el_rate = elbe))
  }
  list(pd = pd, k = NULL, el_rate = pd * lgd)
}
