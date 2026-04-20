import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

enum BtState { disconnected, connecting, connected }
enum StepMode { simple, doble, medio }

class BtController extends ChangeNotifier {
  BluetoothConnection? _connection;
  BtState btState = BtState.disconnected;
  String connectedDeviceName = '';
  String _buffer = ''; 
  Timer? _statusTimer;

  bool motorActivo = false;
  bool sentidoCW = true;          
  StepMode stepMode = StepMode.simple;
  int velocidad = 5;              

  // Telemetría
  int posicion = 0;           // Real (Encoder)
  int posicionEst = 0;        // Estimada (Motor)
  double grados = 0.0;
  double voltaje = 0.0;
  int velRecibida = 0;

  final List<String> serialLog = [];
  static const int _maxLog = 80;

  Future<bool> connect(BluetoothDevice device) async {
    btState = BtState.connecting;
    connectedDeviceName = device.name ?? device.address;
    notifyListeners();
    try {
      _connection = await BluetoothConnection.toAddress(device.address);
      btState = BtState.connected;
      _listenToStream();
      _startStatusPolling();
      notifyListeners();
      return true;
    } catch (e) {
      btState = BtState.disconnected;
      notifyListeners();
      return false;
    }
  }

  void sendCommand(String cmd, {bool log = true}) {
    if (_connection == null || !_connection!.isConnected) return;
    _connection!.output.add(Uint8List.fromList(utf8.encode('$cmd\n')));
    if (log) _addLog('> $cmd');
  }

  void toggleMotor() {
    motorActivo = !motorActivo;
    _syncWithArduino();
    notifyListeners();
  }

  void _syncWithArduino() {
    if (!motorActivo) { sendCommand('STOP'); return; }
    String cmd = (sentidoCW ? 'O' : 'C') + (stepMode == StepMode.simple ? 'SP' : stepMode == StepMode.doble ? 'DP' : 'MP');
    sendCommand(cmd);
  }

  void setSentido(bool cw) { sentidoCW = cw; if (motorActivo) _syncWithArduino(); notifyListeners(); }
  void setStepMode(StepMode mode) { stepMode = mode; if (motorActivo) _syncWithArduino(); notifyListeners(); }
  void setVelocidad(int ms) { velocidad = ms; notifyListeners(); }
  void resetPosicion() { sendCommand('RESET'); notifyListeners(); }
  void pedirVoltaje() => sendCommand('STATUS');

  void _listenToStream() {
    _connection!.input!.listen((data) {
      _buffer += utf8.decode(data, allowMalformed: true);
      while (_buffer.contains('\n')) {
        final idx = _buffer.indexOf('\n');
        final line = _buffer.substring(0, idx).trim();
        _buffer = _buffer.substring(idx + 1);
        if (line.isNotEmpty) _parseLine(line);
      }
    }).onDone(() { btState = BtState.disconnected; notifyListeners(); });
  }

  void _parseLine(String line) {
    _addLog('< $line');
    final matches = RegExp(r'([A-Za-z]+)\s*[:=]\s*([-+]?\d+(?:\.\d+)?)').allMatches(line);
    for (final m in matches) {
      final key = m.group(1)!.toLowerCase();
      final val = m.group(2)!;
      switch (key) {
        case 'pos': posicion = int.tryParse(val) ?? posicion; break;
        case 'grados': grados = double.tryParse(val) ?? grados; break;
        case 'volt': voltaje = double.tryParse(val) ?? voltaje; break;
        case 'vel': velRecibida = int.tryParse(val) ?? velRecibida; break;
        case 'est': posicionEst = int.tryParse(val) ?? posicionEst; break;
      }
    }
    final upper = line.toUpperCase();
    if (upper.contains('MODO:')) motorActivo = !upper.contains('STOP');
    if (upper.contains('DIR:')) sentidoCW = upper.contains('CW') && !upper.contains('CCW');
    notifyListeners();
  }

  void _startStatusPolling() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (btState == BtState.connected) sendCommand('STATUS', log: false);
    });
  }

  void _addLog(String msg) {
    serialLog.add(msg);
    if (serialLog.length > _maxLog) serialLog.removeAt(0);
    notifyListeners();
  }

  void clearLog() { serialLog.clear(); notifyListeners(); }
  void disconnect() { _statusTimer?.cancel(); _connection?.finish(); btState = BtState.disconnected; notifyListeners(); }
}
