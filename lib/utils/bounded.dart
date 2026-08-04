/// Runs [task] over [items] with at most [concurrency] of them in flight.
///
/// `Future.wait` over a mapped list starts everything at once, which is fine
/// for three requests and not fine for thirteen on a phone: they contend for
/// the same link, and a rate limit hit by one is hit by all of them together.
/// Results keep the order of [items] regardless of the order they finish in.
///
/// A task that throws propagates, as it would from `Future.wait`; tasks not yet
/// started are simply never started.
Future<List<T>> mapBounded<S, T>(Iterable<S> items, Future<T> Function(S item) task, {int concurrency = 4}) async {
  final list = items.toList(growable: false);
  if (list.isEmpty) {
    return const [];
  }

  final results = List<T?>.filled(list.length, null);
  var next = 0;

  Future<void> worker() async {
    while (true) {
      final index = next++;
      if (index >= list.length) {
        return;
      }

      results[index] = await task(list[index]);
    }
  }

  final workers = concurrency < list.length ? concurrency : list.length;
  await Future.wait(List.generate(workers < 1 ? 1 : workers, (_) => worker()));

  return results.map((e) => e as T).toList();
}
