#pragma once
#include <stdbool.h>
#include <math.h>

// A request is a one-shot UI action, never a payment instruction.
static inline bool SLDonationTimestampIsFresh(double timestamp, double now) {
	if (!isfinite(timestamp) || !isfinite(now) || timestamp <= 0) return false;
	double age = now - timestamp;
	return age >= -5.0 && age <= 60.0;
}

#ifdef __OBJC__
#define SLDonationScheme @"weixin"
#define SLDonationHost @"shortlook-support"
#define SLDonationPath @"/donate"
#endif
