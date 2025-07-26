/* hsi_accel.c */
#include "hsi_accel.h"

bool hsi_accel_wait_done(uint32_t timeout_ciclos) {
    while (timeout_ciclos--) {
        if (hsi_accel_is_done())
            return true;
    }
    return false;
}
