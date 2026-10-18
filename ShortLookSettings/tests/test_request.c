#include "../../SupportShared/SLDonationRequest.h"
#include <assert.h>
#include <stdio.h>

int main(void) {
	assert(SLDonationTimestampIsFresh(100.0, 100.0));
	assert(SLDonationTimestampIsFresh(100.0, 160.0));
	assert(!SLDonationTimestampIsFresh(100.0, 160.001));
	assert(SLDonationTimestampIsFresh(105.0, 100.0));
	assert(!SLDonationTimestampIsFresh(105.001, 100.0));
	assert(!SLDonationTimestampIsFresh(0.0, 100.0));
	assert(!SLDonationTimestampIsFresh(-1.0, 100.0));
	assert(!SLDonationTimestampIsFresh(NAN, 100.0));
	assert(!SLDonationTimestampIsFresh(INFINITY, 100.0));
	assert(!SLDonationTimestampIsFresh(100.0, NAN));
	assert(!SLDonationTimestampIsFresh(100.0, INFINITY));
	puts("request freshness: 11 checks passed");
	return 0;
}
