// Forked from idevice's ffi/src/pairable_host.rs with the mDNS advertising moved
// to the Swift side (NetService) to avoid the iOS multicast entitlement.
#ifndef STIKPAIR_H
#define STIKPAIR_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef void (*StikPairReadyCb)(void *ctx,
                                const char *service_id,
                                uint16_t port,
                                const char *const *txt_keys,
                                const char *const *txt_vals,
                                size_t txt_count);

typedef void (*StikPairPinCb)(const char *pin, void *ctx);
typedef void (*StikPairAppleTvPinCb)(void *ctx);

typedef struct StikPairAppleTvSession StikPairAppleTvSession;

typedef struct {
    char *error;
    char *device_name;
    char *device_model;
    char *device_udid;
    char *pairing_file_path;
    char *host_alt_irk_hex;
} StikPairResult;

int32_t stikpair_run_host(const char *bind_addr,
                          uint16_t port,
                          const char *name,
                          const char *model,
                          const char *out_path,
                          StikPairReadyCb ready_cb,
                          StikPairPinCb pin_cb,
                          void *ctx,
                          StikPairResult *out);

StikPairAppleTvSession *stikpair_apple_tv_session_new(void);

int32_t stikpair_apple_tv_session_run(StikPairAppleTvSession *session,
                                      const char *host,
                                      uint16_t port,
                                      const char *name,
                                      const char *out_path,
                                      StikPairAppleTvPinCb pin_cb,
                                      void *ctx,
                                      StikPairResult *out);

int32_t stikpair_apple_tv_session_submit_pin(StikPairAppleTvSession *session,
                                             const char *pin);

void stikpair_apple_tv_session_cancel(StikPairAppleTvSession *session);
void stikpair_apple_tv_session_free(StikPairAppleTvSession *session);

void stikpair_result_free(StikPairResult *r);
void stikpair_free_string(char *s);

// AirLift App Container File Access (AFC / HouseArrest)
int32_t stikpair_write_app_file(const char *pairing_file_path,
                                const char *bundle_id,
                                const char *relative_path,
                                const uint8_t *data,
                                size_t data_len,
                                char **err_out);

int32_t stikpair_remove_app_file(const char *pairing_file_path,
                                 const char *bundle_id,
                                 const char *relative_path,
                                 char **err_out);

int32_t stikpair_app_file_exists(const char *pairing_file_path,
                                 const char *bundle_id,
                                 const char *relative_path,
                                 int32_t *out_exists,
                                 char **err_out);

#ifdef __cplusplus
}
#endif

#endif // STIKPAIR_H
