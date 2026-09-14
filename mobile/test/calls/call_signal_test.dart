import 'package:datingapp/calls/domain/call_signal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CallSignal round-trips through toJson/fromJson', () {
    const signal = CallSignal(
      callId: 1,
      type: 'ice-candidate',
      payload: {'candidate': 'candidate:1 1 UDP 1 1.2.3.4 5 typ host'},
    );

    final decoded = CallSignal.fromJson(signal.toJson());

    expect(decoded.callId, 1);
    expect(decoded.type, 'ice-candidate');
    expect(decoded.payload, signal.payload);
  });
}
