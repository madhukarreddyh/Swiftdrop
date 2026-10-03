import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config.dart';
import '../models/order.dart';
import 'api_client.dart';

/// Polls GET /rider/offers while the rider is online.
///
/// v1 uses polling because FCM push is not wired yet. The poller emits the
/// newest unseen offer exactly once via [onNewOffer]; the UI shows the
/// incoming-order card and pauses polling until the card is dismissed.
class OfferPoller {
  OfferPoller(this.api);

  final ApiClient api;
  Timer? _timer;
  final Set<int> _seenOfferIds = {};
  bool _paused = false;
  bool _running = false;

  ValueChanged<DeliveryOrder>? onNewOffer;
  ValueChanged<Object>? onError;

  bool get isRunning => _running;

  void start() {
    if (_running) return;
    _running = true;
    _paused = false;
    _timer = Timer.periodic(AppConfig.offerPollInterval, (_) => _tick());
    _tick(); // poll immediately on start
  }

  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
  }

  /// Pause while an offer card / active delivery is on screen.
  void pause() => _paused = true;

  void resume() {
    _paused = false;
    _seenOfferIds.clear();
  }

  Future<void> _tick() async {
    if (!_running || _paused) return;
    try {
      final offers = await api.getOffers();
      if (!_running || _paused) return;
      for (final offer in offers) {
        if (_seenOfferIds.add(offer.id)) {
          onNewOffer?.call(offer);
          break; // one card at a time
        }
      }
    } catch (e) {
      onError?.call(e);
    }
  }
}
