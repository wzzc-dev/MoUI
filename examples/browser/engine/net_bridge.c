// MoUI browser demo: background curl fetch bridge.
//
// Single-slot API (navigation result) plus a batch API (page sub-resources:
// external scripts/stylesheets fetched in parallel worker threads).
//
// Slot model: a fixed array of slots. The single-slot navigation API uses
// slot 0; the batch API allocates slots 1..N. Every slot write happens
// under one mutex; a condition variable wakes waiters.
//
// Stale-result protection: each start bumps a generation counter; a worker
// that finishes after a newer start superseded it discards its output
// (only applies to the single-slot navigation API).
//
// ABI: MoonBit `Int` is 64-bit, so all cross-boundary ints are int64_t.
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <time.h>

#define MOUI_MAX_SLOTS 48
#define MOUI_SLOT_NAV 0 // single-slot navigation API uses slot 0

static pthread_mutex_t g_lock = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t g_cond = PTHREAD_COND_INITIALIZER;

static int g_slot_active[MOUI_MAX_SLOTS];
static int g_slot_state[MOUI_MAX_SLOTS]; // 0 pending, 1 done (html), 2 error
static char *g_slot_data[MOUI_MAX_SLOTS];
static size_t g_slot_len[MOUI_MAX_SLOTS];
// 槽代:每次 start 递增;worker 记录自己的代,写槽时核对,
// 防止"槽被 clear 并复用后,旧 worker 晚到写入新批次"的陈旧污染
static int64_t g_slot_gen[MOUI_MAX_SLOTS];

static void slot_set_error(int id, const char *msg) {
  if (g_slot_data[id]) {
    free(g_slot_data[id]);
    g_slot_data[id] = NULL;
  }
  size_t n = strlen(msg);
  g_slot_data[id] = (char *)malloc(n + 1);
  if (g_slot_data[id]) {
    memcpy(g_slot_data[id], msg, n + 1);
    g_slot_len[id] = n;
    g_slot_state[id] = 2;
  } else {
    // OOM: drop the message, keep slot empty (a later fetch overwrites)
    g_slot_len[id] = 0;
    g_slot_state[id] = 0;
  }
}

// Worker arg layout: [cmd_len 8B][cmd][NUL][gen 8B][slot_id 8B]
static void *curl_worker(void *arg) {
  char *buf = (char *)arg;
  int64_t cmd_len = *(int64_t *)buf;
  char *cmd = buf + 8;
  int64_t gen, slot_id;
  memcpy(&gen, buf + 8 + cmd_len + 1, 8);
  memcpy(&slot_id, buf + 8 + cmd_len + 1 + 8, 8);
  FILE *fp = popen(cmd, "r");
  if (!fp) {
    free(buf);
    pthread_mutex_lock(&g_lock);
    if (g_slot_active[slot_id] && g_slot_gen[slot_id] == gen) {
      slot_set_error((int)slot_id, "popen failed");
    }
    pthread_cond_signal(&g_cond);
    pthread_mutex_unlock(&g_lock);
    return NULL;
  }
  size_t cap = 1 << 20; // 1 MiB start
  size_t len = 0;
  char *data = (char *)malloc(cap);
  if (!data) {
    free(buf);
    pclose(fp);
    pthread_mutex_lock(&g_lock);
    if (g_slot_active[slot_id] && g_slot_gen[slot_id] == gen) {
      slot_set_error((int)slot_id, "out of memory");
    }
    pthread_cond_signal(&g_cond);
    pthread_mutex_unlock(&g_lock);
    return NULL;
  }
  int ch;
  while ((ch = fgetc(fp)) != EOF) {
    if (len + 2 > cap) {
      cap *= 2;
      char *nb = (char *)realloc(data, cap);
      if (!nb) {
        free(buf);
        free(data);
        pclose(fp);
        pthread_mutex_lock(&g_lock);
        if (g_slot_active[slot_id] && g_slot_gen[slot_id] == gen) {
          slot_set_error((int)slot_id, "out of memory");
        }
        pthread_cond_signal(&g_cond);
        pthread_mutex_unlock(&g_lock);
        return NULL;
      }
      data = nb;
    }
    data[len++] = (char)ch;
  }
  int rc = pclose(fp);
  pthread_mutex_lock(&g_lock);
  if (g_slot_active[slot_id] && g_slot_gen[slot_id] == gen) {
    if (g_slot_data[slot_id]) {
      free(g_slot_data[slot_id]);
      g_slot_data[slot_id] = NULL;
    }
    if (rc == 0 && len > 0) {
      g_slot_data[slot_id] = data;
      g_slot_len[slot_id] = len;
      g_slot_state[slot_id] = 1;
    } else {
      free(data);
      slot_set_error((int)slot_id, rc == 0 ? "empty response" : "curl failed");
    }
    pthread_cond_signal(&g_cond);
  } else {
    // stale: slot reused or a newer navigation superseded this worker
    free(data);
  }
  pthread_mutex_unlock(&g_lock);
  free(buf);
  return NULL;
}

// Common start: allocate a slot (or use the navigation slot), bump the
// generation counter, spawn a worker thread. Returns the slot id, or -1.
// `use_seq`=1 for the single-slot navigation API (stale protection),
// 0 for the batch API (results always kept while the slot is active).
static int64_t slot_start_common(int64_t requested, const char *cmd, int64_t cmd_len, int64_t use_seq) {
  char *buf = (char *)malloc((size_t)cmd_len + 1 + 8 + 8 + 8 + 8);
  if (!buf) return -1;
  pthread_mutex_lock(&g_lock);
  int64_t id = requested;
  if (id < 0 || id >= MOUI_MAX_SLOTS || g_slot_active[id]) {
    if (requested >= 0) {
      // 导航槽(slot 0)被占用:不 fallback,直接失败
      // (nav 的 wait/take 只读 slot 0,写进批量槽会丢结果)
      pthread_mutex_unlock(&g_lock);
      free(buf);
      return -1;
    }
    id = -1;
    for (int i = 1; i < MOUI_MAX_SLOTS; i++) {
      if (!g_slot_active[i]) {
        id = i;
        break;
      }
    }
  }
  if (id < 0) {
    pthread_mutex_unlock(&g_lock);
    free(buf);
    return -1;
  }
  g_slot_active[id] = 1;
  g_slot_state[id] = 0;
  g_slot_len[id] = 0;
  if (g_slot_data[id]) {
    free(g_slot_data[id]);
    g_slot_data[id] = NULL;
  }
  int64_t gen = ++g_slot_gen[id];
  pthread_mutex_unlock(&g_lock);
  memcpy(buf, &cmd_len, 8);
  memcpy(buf + 8, cmd, (size_t)cmd_len);
  buf[8 + cmd_len] = 0;
  memcpy(buf + 8 + cmd_len + 1, &gen, 8);
  memcpy(buf + 8 + cmd_len + 1 + 8, &id, 8);
  memcpy(buf + 8 + cmd_len + 1 + 16, &use_seq, 8);
  pthread_t tid;
  if (pthread_create(&tid, NULL, curl_worker, buf) != 0) {
    free(buf);
    pthread_mutex_lock(&g_lock);
    g_slot_active[id] = 0;
    pthread_mutex_unlock(&g_lock);
    return -1;
  }
  pthread_detach(tid);
  return id;
}

// Single-slot navigation API (slot 0, same semantics as before).
int64_t moui_nav_curl_start(const char *cmd, int64_t cmd_len) {
  return slot_start_common(MOUI_SLOT_NAV, cmd, cmd_len, 1);
}

// Blocks until the navigation slot (slot 0) leaves the pending state or
// `timeout_ms` elapses. Returns 0 on timeout, otherwise the result state.
int64_t moui_nav_result_wait(int64_t timeout_ms) {
  struct timespec ts;
  clock_gettime(CLOCK_REALTIME, &ts);
  ts.tv_sec += timeout_ms / 1000;
  ts.tv_nsec += (timeout_ms % 1000) * 1000000;
  if (ts.tv_nsec >= 1000000000) {
    ts.tv_sec += 1;
    ts.tv_nsec -= 1000000000;
  }
  pthread_mutex_lock(&g_lock);
  while (g_slot_active[MOUI_SLOT_NAV] && g_slot_state[MOUI_SLOT_NAV] == 0) {
    int rc = pthread_cond_timedwait(&g_cond, &g_lock, &ts);
    if (rc != 0) break; // timeout
  }
  int64_t s = g_slot_active[MOUI_SLOT_NAV] ? g_slot_state[MOUI_SLOT_NAV] : 0;
  pthread_mutex_unlock(&g_lock);
  return s;
}

// Copies the navigation slot payload into `dst` (at most `cap`) and clears
// the slot. Returns positive length for a successful fetch, negative for an
// error payload; if the payload does not fit in `cap` the slot is left
// intact and the required capacity is returned (positive).
int64_t moui_nav_result_take(char *dst, int64_t cap) {
  pthread_mutex_lock(&g_lock);
  int64_t n = 0;
  if (g_slot_active[MOUI_SLOT_NAV] && g_slot_data[MOUI_SLOT_NAV]) {
    int64_t m = (int64_t)g_slot_len[MOUI_SLOT_NAV];
    if (m > cap) {
      n = m; // buffer too small: leave slot intact
    } else {
      n = (g_slot_state[MOUI_SLOT_NAV] == 1) ? m : -m;
      if (m > 0) memcpy(dst, g_slot_data[MOUI_SLOT_NAV], (size_t)m);
      free(g_slot_data[MOUI_SLOT_NAV]);
      g_slot_data[MOUI_SLOT_NAV] = NULL;
      g_slot_len[MOUI_SLOT_NAV] = 0;
      g_slot_state[MOUI_SLOT_NAV] = 0;
      g_slot_active[MOUI_SLOT_NAV] = 0;
    }
  }
  pthread_mutex_unlock(&g_lock);
  return n;
}

// Batch API: allocate any free slot (>= 1). Returns slot id or -1.
int64_t moui_fetch_slot_start(const char *cmd, int64_t cmd_len) {
  return slot_start_common(-1, cmd, cmd_len, 0);
}

// Blocks until all active slots leave the pending state, or `timeout_ms`.
// Returns the number of active slots still pending on timeout, 0 when done.
int64_t moui_fetch_wait_all(int64_t timeout_ms) {
  struct timespec ts;
  clock_gettime(CLOCK_REALTIME, &ts);
  ts.tv_sec += timeout_ms / 1000;
  ts.tv_nsec += (timeout_ms % 1000) * 1000000;
  if (ts.tv_nsec >= 1000000000) {
    ts.tv_sec += 1;
    ts.tv_nsec -= 1000000000;
  }
  pthread_mutex_lock(&g_lock);
  for (;;) {
    int pending = 0;
    for (int i = 0; i < MOUI_MAX_SLOTS; i++) {
      if (g_slot_active[i] && g_slot_state[i] == 0) {
        pending = 1;
        break;
      }
    }
    if (!pending) break;
    int rc = pthread_cond_timedwait(&g_cond, &g_lock, &ts);
    if (rc != 0) break; // timeout
  }
  int still_pending = 0;
  for (int i = 0; i < MOUI_MAX_SLOTS; i++) {
    if (g_slot_active[i] && g_slot_state[i] == 0) still_pending++;
  }
  pthread_mutex_unlock(&g_lock);
  return still_pending;
}

// 0 = pending, 1 = done (html), 2 = error
int64_t moui_fetch_slot_state(int64_t id) {
  pthread_mutex_lock(&g_lock);
  int64_t s = (id >= 0 && id < MOUI_MAX_SLOTS && g_slot_active[id]) ? g_slot_state[id] : 2;
  pthread_mutex_unlock(&g_lock);
  return s;
}

int64_t moui_fetch_slot_len(int64_t id) {
  pthread_mutex_lock(&g_lock);
  int64_t n = (id >= 0 && id < MOUI_MAX_SLOTS && g_slot_active[id] && g_slot_data[id]) ? (int64_t)g_slot_len[id] : 0;
  pthread_mutex_unlock(&g_lock);
  return n;
}

// Copies the slot payload into `dst` (at most `cap`). Returns bytes copied.
int64_t moui_fetch_slot_take(int64_t id, char *dst, int64_t cap) {
  pthread_mutex_lock(&g_lock);
  int64_t n = 0;
  if (id >= 0 && id < MOUI_MAX_SLOTS && g_slot_active[id] && g_slot_data[id]) {
    int64_t m = (int64_t)g_slot_len[id];
    n = m < cap ? m : cap;
    if (n > 0) memcpy(dst, g_slot_data[id], (size_t)n);
  }
  pthread_mutex_unlock(&g_lock);
  return n;
}

// Releases the slot for reuse.
void moui_fetch_slot_clear(int64_t id) {
  pthread_mutex_lock(&g_lock);
  if (id >= 0 && id < MOUI_MAX_SLOTS) {
    if (g_slot_data[id]) {
      free(g_slot_data[id]);
      g_slot_data[id] = NULL;
    }
    g_slot_active[id] = 0;
    g_slot_state[id] = 0;
    g_slot_len[id] = 0;
  }
  pthread_mutex_unlock(&g_lock);
}
