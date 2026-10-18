#include "../../SupportShared/SLDonationRequest.h"
#include <assert.h>
#include <stdio.h>

int main(void) {
    const double now = 1800000000.0;
    assert(SLDonationTimestampIsFresh(now, now));
    assert(SLDonationTimestampIsFresh(now - 60, now));
    assert(!SLDonationTimestampIsFresh(now - 60.001, now));
    assert(SLDonationTimestampIsFresh(now + 5, now));
    assert(!SLDonationTimestampIsFresh(now + 5.001, now));
    assert(!SLDonationTimestampIsFresh(0, now));
    assert(!SLDonationTimestampIsFresh(-1, now));
    assert(!SLDonationTimestampIsFresh(NAN, now));
    assert(!SLDonationTimestampIsFresh(INFINITY, now));
    assert(!SLDonationTimestampIsFresh(now, NAN));
    assert(!SLDonationTimestampIsFresh(now, INFINITY));
    puts("11 timestamp boundary checks passed");
    return 0;
}
