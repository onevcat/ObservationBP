//
//  Locking.cpp
//  ObservationBP
//
//  Created by Wei Wang on 2023/08/03.
//

#include <cstdarg>
#include <chrono>

namespace swift {
namespace threading {

void fatal(const char *msg, ...) {
  std::va_list val;

  va_start(val, msg);
  std::vfprintf(stderr, msg, val);
  va_end(val);

  std::abort();
}

} // namespace threading
} // namespace swift

namespace swift {
namespace threading_impl {
namespace chrono_utils {
using std::chrono::ceil;
} // namespace chrono_utils
} // namespace threading_impl
} // namespace swift

namespace threading_impl {

#define SWIFT_PTHREADS_CHECK(expr)                                             \
  do {                                                                         \
    int res_ = (expr);                                                         \
    if (res_ != 0)                                                             \
      swift::threading::fatal(#expr " failed with error %d\n", res_);          \
  } while (0)

#define SWIFT_PTHREADS_RETURN_TRUE_OR_FALSE(falseerr, expr)                    \
  do {                                                                         \
    int res_ = (expr);                                                         \
    switch (res_) {                                                            \
    case 0:                                                                    \
      return true;                                                             \
    case falseerr:                                                             \
      return false;                                                            \
    default:                                                                   \
      swift::threading::fatal(#expr " failed with error (%d)\n", res_);        \
      return false;                                                            \
    }                                                                          \
  } while (0)

// .. Thread related things ..................................................

using thread_id = ::pthread_t;

inline thread_id thread_get_current() { return ::pthread_self(); }

bool thread_is_main();

inline bool threads_same(thread_id a, thread_id b) {
  return ::pthread_equal(a, b);
}

// .. Mutex support ..........................................................

using mutex_handle = ::pthread_mutex_t;

inline void mutex_init(mutex_handle &handle, bool checked = false) {
  if (!checked) {
    handle = PTHREAD_MUTEX_INITIALIZER;
  } else {
    ::pthread_mutexattr_t attr;
    SWIFT_PTHREADS_CHECK(::pthread_mutexattr_init(&attr));
    SWIFT_PTHREADS_CHECK(
        ::pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_ERRORCHECK));
    SWIFT_PTHREADS_CHECK(::pthread_mutex_init(&handle, &attr));
    SWIFT_PTHREADS_CHECK(::pthread_mutexattr_destroy(&attr));
  }
}
inline void mutex_destroy(mutex_handle &handle) {
  SWIFT_PTHREADS_CHECK(::pthread_mutex_destroy(&handle));
}

inline void mutex_lock(mutex_handle &handle) {
  SWIFT_PTHREADS_CHECK(::pthread_mutex_lock(&handle));
}
inline void mutex_unlock(mutex_handle &handle) {
  SWIFT_PTHREADS_CHECK(::pthread_mutex_unlock(&handle));
}
inline bool mutex_try_lock(mutex_handle &handle) {
  SWIFT_PTHREADS_RETURN_TRUE_OR_FALSE(EBUSY, ::pthread_mutex_trylock(&handle));
}

inline void mutex_unsafe_lock(mutex_handle &handle) {
  (void)::pthread_mutex_lock(&handle);
}
inline void mutex_unsafe_unlock(mutex_handle &handle) {
  (void)::pthread_mutex_unlock(&handle);
}

using lazy_mutex_handle = ::pthread_mutex_t;

// We don't actually need to be lazy here because pthreads has
// PTHREAD_MUTEX_INITIALIZER.
inline constexpr lazy_mutex_handle lazy_mutex_initializer() {
  return PTHREAD_MUTEX_INITIALIZER;
}
inline void lazy_mutex_destroy(lazy_mutex_handle &handle) {
  SWIFT_PTHREADS_CHECK(::pthread_mutex_destroy(&handle));
}

inline void lazy_mutex_lock(lazy_mutex_handle &handle) {
  SWIFT_PTHREADS_CHECK(::pthread_mutex_lock(&handle));
}
inline void lazy_mutex_unlock(lazy_mutex_handle &handle) {
  SWIFT_PTHREADS_CHECK(::pthread_mutex_unlock(&handle));
}
inline bool lazy_mutex_try_lock(lazy_mutex_handle &handle) {
  SWIFT_PTHREADS_RETURN_TRUE_OR_FALSE(EBUSY, ::pthread_mutex_trylock(&handle));
}

inline void lazy_mutex_unsafe_lock(lazy_mutex_handle &handle) {
  (void)::pthread_mutex_lock(&handle);
}
inline void lazy_mutex_unsafe_unlock(lazy_mutex_handle &handle) {
  (void)::pthread_mutex_unlock(&handle);
}

// .. ConditionVariable support ..............................................

struct cond_handle {
  ::pthread_cond_t  condition;
  ::pthread_mutex_t mutex;
};

inline void cond_init(cond_handle &handle) {
  handle.condition = PTHREAD_COND_INITIALIZER;
  handle.mutex = PTHREAD_MUTEX_INITIALIZER;
}
inline void cond_destroy(cond_handle &handle) {
  SWIFT_PTHREADS_CHECK(::pthread_cond_destroy(&handle.condition));
  SWIFT_PTHREADS_CHECK(::pthread_mutex_destroy(&handle.mutex));
}
inline void cond_lock(cond_handle &handle) {
  SWIFT_PTHREADS_CHECK(::pthread_mutex_lock(&handle.mutex));
}
inline void cond_unlock(cond_handle &handle) {
  SWIFT_PTHREADS_CHECK(::pthread_mutex_unlock(&handle.mutex));
}
inline void cond_signal(cond_handle &handle) {
  SWIFT_PTHREADS_CHECK(::pthread_cond_signal(&handle.condition));
}
inline void cond_broadcast(cond_handle &handle) {
  SWIFT_PTHREADS_CHECK(::pthread_cond_broadcast(&handle.condition));
}
inline void cond_wait(cond_handle &handle) {
  SWIFT_PTHREADS_CHECK(::pthread_cond_wait(&handle.condition, &handle.mutex));
}
template <class Rep, class Period>
inline bool cond_wait(cond_handle &handle,
                      std::chrono::duration<Rep, Period> duration) {
    auto to_wait = swift::threading_impl::chrono_utils::ceil<
    std::chrono::system_clock::duration>(duration);
  auto deadline = std::chrono::system_clock::now() + to_wait;
  return cond_wait(handle, deadline);
}
inline bool cond_wait(cond_handle &handle,
                      std::chrono::system_clock::time_point deadline) {
    auto ns = swift::threading_impl::chrono_utils::ceil<std::chrono::nanoseconds>(
    deadline.time_since_epoch()).count();
  struct ::timespec ts = { ::time_t(ns / 1000000000), long(ns % 1000000000) };
  SWIFT_PTHREADS_RETURN_TRUE_OR_FALSE(
    ETIMEDOUT,
    ::pthread_cond_timedwait(&handle.condition, &handle.mutex, &ts)
  );
}

// .. Once ...................................................................

using once_t = std::atomic<std::intptr_t>;

void once_slow(once_t &predicate, void (*fn)(void *), void *context);

inline void once_impl(once_t &predicate, void (*fn)(void *), void *context) {
  // Sadly we can't use ::pthread_once() for this (no context)
  if (predicate.load(std::memory_order_acquire) < 0)
    return;

  once_slow(predicate, fn, context);
}

// .. Thread local storage ...................................................

using tls_key_t = pthread_key_t;
using tls_dtor_t = void (*)(void *);

inline bool tls_alloc(tls_key_t &key, tls_dtor_t dtor) {
  return pthread_key_create(&key, dtor) == 0;
}

inline void *tls_get(tls_key_t key) { return pthread_getspecific(key); }

inline void tls_set(tls_key_t key, void *value) {
  pthread_setspecific(key, value);
}

} // namespace threading_impl

// -- ScopedLock ---------------------------------------------------------------

/// Compile time adjusted stack based object that locks/unlocks the supplied
/// Mutex type. Use the provided typedefs instead of this directly.
template <typename T, bool Inverted>
class ScopedLockT {
  ScopedLockT() = delete;
  ScopedLockT(const ScopedLockT &) = delete;
  ScopedLockT &operator=(const ScopedLockT &) = delete;
  ScopedLockT(ScopedLockT &&) = delete;
  ScopedLockT &operator=(ScopedLockT &&) = delete;

public:
  explicit ScopedLockT(T &l) : Lock(l) {
    if (Inverted) {
      Lock.unlock();
    } else {
      Lock.lock();
    }
  }

  ~ScopedLockT() {
    if (Inverted) {
      Lock.lock();
    } else {
      Lock.unlock();
    }
  }

private:
  T &Lock;
};

/// A Mutex object that supports `BasicLockable` and `Lockable` C++ concepts.
/// See http://en.cppreference.com/w/cpp/concept/BasicLockable
/// See http://en.cppreference.com/w/cpp/concept/Lockable
///
/// This is NOT a recursive mutex.
class Mutex {

  Mutex(const Mutex &) = delete;
  Mutex &operator=(const Mutex &) = delete;
  Mutex(Mutex &&) = delete;
  Mutex &operator=(Mutex &&) = delete;

public:
  /// Constructs a non-recursive mutex.
  ///
  /// If `checked` is true the mutex will attempt to check for misuse and
  /// fatalError when detected. If `checked` is false (the default) the
  /// mutex will make little to no effort to check for misuse (more efficient).
  explicit Mutex(bool checked = false) {
    threading_impl::mutex_init(Handle, checked);
  }
  ~Mutex() { threading_impl::mutex_destroy(Handle); }

  /// The lock() method has the following properties:
  /// - Behaves as an atomic operation.
  /// - Blocks the calling thread until exclusive ownership of the mutex
  ///   can be obtained.
  /// - Prior m.unlock() operations on the same mutex synchronize-with
  ///   this lock operation.
  /// - The behavior is undefined if the calling thread already owns
  ///   the mutex (likely a deadlock).
  /// - Does not throw exceptions but will halt on error (fatalError).
  void lock() { threading_impl::mutex_lock(Handle); }

  /// The unlock() method has the following properties:
  /// - Behaves as an atomic operation.
  /// - Releases the calling thread's ownership of the mutex and
  ///   synchronizes-with the subsequent successful lock operations on
  ///   the same object.
  /// - The behavior is undefined if the calling thread does not own
  ///   the mutex.
  /// - Does not throw exceptions but will halt on error (fatalError).
  void unlock() { threading_impl::mutex_unlock(Handle); }

  /// The try_lock() method has the following properties:
  /// - Behaves as an atomic operation.
  /// - Attempts to obtain exclusive ownership of the mutex for the calling
  ///   thread without blocking. If ownership is not obtained, returns
  ///   immediately. The function is allowed to spuriously fail and return
  ///   even if the mutex is not currently owned by another thread.
  /// - If try_lock() succeeds, prior unlock() operations on the same object
  ///   synchronize-with this operation. lock() does not synchronize with a
  ///   failed try_lock()
  /// - The behavior is undefined if the calling thread already owns
  ///   the mutex (likely a deadlock)?
  /// - Does not throw exceptions but will halt on error (fatalError).
  bool try_lock() { return threading_impl::mutex_try_lock(Handle); }

  /// Acquires lock before calling the supplied critical section and releases
  /// lock on return from critical section.
  ///
  /// This call can block while waiting for the lock to become available.
  ///
  /// For example the following mutates value while holding the mutex lock.
  ///
  /// ```
  ///   mutex.lock([&value] { value++; });
  /// ```
  ///
  /// Precondition: Mutex not held by this thread, undefined otherwise.
  template <typename CriticalSection>
  auto withLock(CriticalSection &&criticalSection)
      -> decltype(std::forward<CriticalSection>(criticalSection)()) {
    ScopedLock guard(*this);
    return std::forward<CriticalSection>(criticalSection)();
  }

  /// A stack based object that locks the supplied mutex on construction
  /// and unlocks it on destruction.
  ///
  /// Precondition: Mutex unlocked by this thread, undefined otherwise.
  typedef ScopedLockT<Mutex, false> ScopedLock;

  /// A stack based object that unlocks the supplied mutex on construction
  /// and relocks it on destruction.
  ///
  /// Precondition: Mutex locked by this thread, undefined otherwise.
  typedef ScopedLockT<Mutex, true> ScopedUnlock;

protected:
  threading_impl::mutex_handle Handle;
};


extern "C" size_t _swift_observation_lock_size();
size_t _swift_observation_lock_size() {
  size_t bytes = sizeof(Mutex);

  if (bytes < 1) {
    return 1;
  }

  return bytes;
}

extern "C" void _swift_observation_lock_init(Mutex &lock);
void _swift_observation_lock_init(Mutex &lock) {
  new (&lock) Mutex();
}

extern "C" void _swift_observation_lock_lock(Mutex &lock);
void _swift_observation_lock_lock(Mutex &lock) {
  lock.lock();
}

extern "C" void _swift_observation_lock_unlock(Mutex &lock);
void _swift_observation_lock_unlock(Mutex &lock) {
  lock.unlock();
}
