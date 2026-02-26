import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

Map<String, dynamic>? _asStringDynamicMap(dynamic raw) {
  if (raw is! Map) return null;
  return Map<String, dynamic>.from(
    raw.map((key, value) => MapEntry(key.toString(), value)),
  );
}

class FlutterBluetoothClassic {
  static const MethodChannel _channel = MethodChannel(
    'com.flutter_bluetooth_classic.plugin/flutter_bluetooth_classic',
  );
  static const EventChannel _stateChannel = EventChannel(
    'com.flutter_bluetooth_classic.plugin/flutter_bluetooth_classic_state',
  );
  static const EventChannel _connectionChannel = EventChannel(
    'com.flutter_bluetooth_classic.plugin/flutter_bluetooth_classic_connection',
  );
  static const EventChannel _dataChannel = EventChannel(
    'com.flutter_bluetooth_classic.plugin/flutter_bluetooth_classic_data',
  );

  // Singleton instance
  static FlutterBluetoothClassic? _instance;

  // Stream controllers
  final _stateStreamController = StreamController<BluetoothState>.broadcast();
  final _connectionStreamController =
      StreamController<BluetoothConnectionState>.broadcast();
  final _dataStreamController = StreamController<BluetoothData>.broadcast();
  final _deviceDiscoveryStreamController =
      StreamController<BluetoothDevice>.broadcast();

  // Public streams that can be subscribed to
  Stream<BluetoothState> get onStateChanged => _stateStreamController.stream;
  Stream<BluetoothConnectionState> get onConnectionChanged =>
      _connectionStreamController.stream;
  Stream<BluetoothData> get onDataReceived => _dataStreamController.stream;
  Stream<BluetoothDevice> get onDeviceDiscovered =>
      _deviceDiscoveryStreamController.stream;

  /// Factory constructor to maintain a single instance of the class
  factory FlutterBluetoothClassic() {
    _instance ??= FlutterBluetoothClassic._();
    return _instance!;
  }

  /// Private constructor that sets up the event listeners
  FlutterBluetoothClassic._() {
    // Listen for state/discovery events
    _stateChannel.receiveBroadcastStream().listen((dynamic event) {
      final eventMap = _asStringDynamicMap(event);
      if (eventMap == null) return;

      // Device discovery event
      if (eventMap['event'] == 'deviceFound') {
        final deviceMap = _asStringDynamicMap(eventMap['device']);
        if (deviceMap != null) {
          _deviceDiscoveryStreamController.add(
            BluetoothDevice.fromMap(deviceMap),
          );
        }
        return;
      }

      // Regular Bluetooth state event
      _stateStreamController.add(BluetoothState.fromMap(eventMap));
    });

    // Listen for connection changes
    _connectionChannel.receiveBroadcastStream().listen((dynamic event) {
      final map = _asStringDynamicMap(event);
      if (map != null) {
        _connectionStreamController.add(BluetoothConnectionState.fromMap(map));
      }
    });

    // Listen for data received
    _dataChannel.receiveBroadcastStream().listen((dynamic event) {
      final map = _asStringDynamicMap(event);
      if (map != null) {
        _dataStreamController.add(BluetoothData.fromMap(map));
      }
    });
  }

  /// Check if Bluetooth is supported on the device
  Future<bool> isBluetoothSupported() async {
    try {
      return await _channel.invokeMethod('isBluetoothSupported');
    } catch (e) {
      throw BluetoothException('Failed to check Bluetooth support: $e');
    }
  }

  /// Check if Bluetooth is enabled
  Future<bool> isBluetoothEnabled() async {
    try {
      return await _channel.invokeMethod('isBluetoothEnabled');
    } catch (e) {
      throw BluetoothException('Failed to check Bluetooth status: $e');
    }
  }

  /// Request to enable Bluetooth
  Future<bool> enableBluetooth() async {
    try {
      return await _channel.invokeMethod('enableBluetooth');
    } catch (e) {
      throw BluetoothException('Failed to enable Bluetooth: $e');
    }
  }

  /// Get paired devices
  Future<List<BluetoothDevice>> getPairedDevices() async {
    try {
      final List<dynamic> devices = await _channel.invokeMethod(
        'getPairedDevices',
      );

      return devices
          .map((device) => _asStringDynamicMap(device))
          .whereType<Map<String, dynamic>>()
          .map((deviceMap) => BluetoothDevice.fromMap(deviceMap))
          .toList();
    } catch (e) {
      throw BluetoothException('Failed to get paired devices: $e');
    }
  }

  /// Get discovered devices from the last discovery session
  Future<List<BluetoothDevice>> getDiscoveredDevices() async {
    try {
      final List<dynamic> devices = await _channel.invokeMethod(
        'getDiscoveredDevices',
      );

      return devices
          .map((device) => _asStringDynamicMap(device))
          .whereType<Map<String, dynamic>>()
          .map((deviceMap) => BluetoothDevice.fromMap(deviceMap))
          .toList();
    } catch (e) {
      throw BluetoothException('Failed to get discovered devices: $e');
    }
  }

  /// Start discovery for nearby Bluetooth devices
  Future<bool> startDiscovery() async {
    try {
      return await _channel.invokeMethod('startDiscovery');
    } catch (e) {
      throw BluetoothException('Failed to start discovery: $e');
    }
  }

  /// Stop discovery
  Future<bool> stopDiscovery() async {
    try {
      return await _channel.invokeMethod('stopDiscovery');
    } catch (e) {
      throw BluetoothException('Failed to stop discovery: $e');
    }
  }

  /// Connect to a device
  Future<bool> connect(String address) async {
    try {
      return await _channel.invokeMethod('connect', {'address': address});
    } catch (e) {
      throw BluetoothException('Failed to connect to device: $e');
    }
  }

  /// Disconnect from a device
  Future<bool> disconnect() async {
    try {
      return await _channel.invokeMethod('disconnect');
    } catch (e) {
      throw BluetoothException('Failed to disconnect: $e');
    }
  }

  /// Send data to the connected device
  Future<bool> sendData(List<int> data) async {
    try {
      return await _channel.invokeMethod('sendData', {'data': data});
    } catch (e) {
      throw BluetoothException('Failed to send data: $e');
    }
  }

  /// Send string data to the connected device
  Future<bool> sendString(String message) async {
    try {
      final List<int> data = List<int>.from(utf8.encode(message));
      return await sendData(data);
    } catch (e) {
      throw BluetoothException('Failed to send string: $e');
    }
  }

  /// Dispose of resources
  void dispose() {
    _stateStreamController.close();
    _connectionStreamController.close();
    _dataStreamController.close();
    _deviceDiscoveryStreamController.close();
  }
}

// Data Models

class BluetoothException implements Exception {
  final String message;

  BluetoothException(this.message);

  @override
  String toString() => 'BluetoothException: $message';
}

class BluetoothState {
  final bool isEnabled;
  final String status;

  BluetoothState({required this.isEnabled, required this.status});

  factory BluetoothState.fromMap(dynamic raw) {
    final map = _asStringDynamicMap(raw) ?? <String, dynamic>{};
    return BluetoothState(
      isEnabled: map['isEnabled'] == true,
      status: map['status']?.toString() ?? 'UNKNOWN',
    );
  }
}

class BluetoothDevice {
  final String name;
  final String address;
  final bool paired;

  BluetoothDevice({
    required this.name,
    required this.address,
    required this.paired,
  });

  factory BluetoothDevice.fromMap(dynamic raw) {
    final map = _asStringDynamicMap(raw) ?? <String, dynamic>{};
    return BluetoothDevice(
      name: map['name']?.toString() ?? 'Unknown',
      address: map['address']?.toString() ?? '',
      paired: map['paired'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'address': address, 'paired': paired};
  }
}

class BluetoothConnectionState {
  final bool isConnected;
  final String deviceAddress;
  final String status;

  BluetoothConnectionState({
    required this.isConnected,
    required this.deviceAddress,
    required this.status,
  });

  factory BluetoothConnectionState.fromMap(dynamic raw) {
    final map = _asStringDynamicMap(raw) ?? <String, dynamic>{};
    return BluetoothConnectionState(
      isConnected: map['isConnected'] == true,
      deviceAddress: map['deviceAddress']?.toString() ?? '',
      status: map['status']?.toString() ?? 'UNKNOWN',
    );
  }
}

class BluetoothData {
  final String deviceAddress;
  final List<int> data;

  BluetoothData({required this.deviceAddress, required this.data});

  String asString() {
    return utf8.decode(data, allowMalformed: true);
  }

  factory BluetoothData.fromMap(dynamic raw) {
    final map = _asStringDynamicMap(raw) ?? <String, dynamic>{};

    final dynamic rawData = map['data'];
    List<int> bytes = <int>[];
    if (rawData is List) {
      bytes = rawData
          .map((e) => e is num ? e.toInt() : int.tryParse(e.toString()) ?? 0)
          .toList();
    }

    return BluetoothData(
      deviceAddress: map['deviceAddress']?.toString() ?? '',
      data: bytes,
    );
  }
}
