//
//  ThreadLocal.cpp
//  ObservationBP
//
//  Created by Wei Wang on 2023/08/03.
//

#include <stdio.h>
#include <dispatch/dispatch.h>
#include <pthread.h>

enum class tls_key {
  observation_transaction
};

using once_t = ::dispatch_once_t;
using tls_key_t = pthread_key_t;
using tls_dtor_t = void (*)(void *);

inline void once_impl(once_t &predicate, void (*fn)(void *), void *context) {
  dispatch_once_f(&predicate, context, fn);
}

inline void once(once_t &predicate, void (*fn)(void *),
                 void *context = nullptr) {
  once_impl(predicate, fn, context);
}

inline bool tls_alloc(tls_key_t &key, tls_dtor_t dtor) {
  return pthread_key_create(&key, dtor) == 0;
}

class ThreadLocalKey {
  // We rely on the zero-initialization of objects with static storage
  // duration.
  once_t onceFlag;
  tls_key_t key;

public:
  tls_key_t getKey() {
    once(
        onceFlag,
        [](void *ctx) {
          tls_key_t *pkey = reinterpret_cast<tls_key_t *>(ctx);
          tls_alloc(*pkey, nullptr);
        },
        &key);
    return key;
  }
};

inline void *tls_get(tls_key_t key) {
    return pthread_getspecific(key);
}
inline void tls_set(tls_key_t key, void *value) {
    pthread_setspecific(key, value);
}

template <class T, class Key>
class ThreadLocal {

  Key key;

public:
  constexpr ThreadLocal() {}

  T get() {
    void *storedValue = tls_get(key.getKey());
    T value;
    memcpy(&value, &storedValue, sizeof(T));
    return value;
  }

  void set(T newValue) {
    void *storedValue;
    memcpy(&storedValue, &newValue, sizeof(T));
    tls_set(key.getKey(), storedValue);
  }
};


static ThreadLocal<void *, ThreadLocalKey> Value;

extern "C" void *_swift_observation_tls_get();
void *_swift_observation_tls_get() {
  return Value.get();
}

extern "C" void _swift_observation_tls_set(void *value);
void _swift_observation_tls_set(void *value) {
  Value.set(value);
}
