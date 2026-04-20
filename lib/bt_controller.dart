import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

/// Estados posibles de la conexión Bluetooth
enum BtState { disconnected, connecting, connected }

/// Modos de paso del motor (Simple, Doble, Medio)
enum StepMode { simple, doble, medio }

class BtController extends ChangeNotifier {
  // ── Bluetooth ────────────────────────────────────────────────────
  BluetoothConnection? _connection;
  BtState btState = BtState.disconnected;
  String connectedDeviceName = '';
  String _buffer = ''; // buffer para armar líneas incompletas

  // ── Estado del motor ─────────────────────────────────────────────
  bool motorActivo = false;
  bool sentidoCW = true;          // true = CW, false = CCW
  StepMode stepMode = StepMode.simple;
  int velocidad = 5;              // ms entre pasos (valor local para UI)

  // ── Telemetría (llegando del Arduino) ────────────────────────────
  int posicion = 0;
  double grados = 0.0;
  double voltaje = 0.0;
  int velRecibida = 0;

  // ── Consola serial ───────────────────────────────────────────────
  final List<String> serialLog = [];
  static const int _maxLog = 80;

  // ─────────────────────────────────────────────────────────────────
  //  CONEXIÓN
  // ─────────────────────────────────────────────────────────────────

  Future<bool> connect(BluetoothDevice device) async {
    btState = BtState.connecting;
    connectedDeviceName = device.name ?? device.address;
    notifyListeners();

    try {
      _connection = await BluetoothConnection.toAddress(device.address);
      btState = BtState.connected;
      _addLog('>> Conectado a $connectedDeviceName');
      _listenToStream();
      notifyListeners();
      return true;
    } catch (e) {
      btState = BtState.disconnected;
      _addLog('[ERROR] $e');
      notifyListeners();
      return false;
    }
  }

  Future<void> disconnect() async {
    await _connection?.finish();
    _connection = null;
    btState = BtState.disconnected;
    motorActivo = false;
    connectedDeviceName = '';
    _addLog('>> Desconectado');
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────
  //  ENVÍO DE COMANDOS (Protocolo Arduino HC-05)
  // ─────────────────────────────────────────────────────────────────

  void sendCommand(String cmd) {
    if (_connection == null || !_connection!.isConnected) return;
    final data = Uint8List.fromList(utf8.encode('$cmd\n'));
    _connection!.output.add(data);
    _addLog('> $cmd');
  }

  void _syncWithArduino() {
    if (!motorActivo) {
      sendCommand('STOP');
      return;
    }

    String cmd = '';
    if (sentidoCW) {
      cmd = switch (stepMode) {
        StepMode.simple => 'OSP',
        StepMode.doble  => 'ODP',
        StepMode.medio  => 'OMP',
      };
    } else {
      cmd = switch (stepMode) {
        StepMode.simple => 'CSP',
        StepMode.doble  => 'CDP',
        StepMode.medio  => 'CMP',
      };
    }
    sendCommand(cmd);
  }

  void toggleMotor() {
    motorActivo = !motorActivo;
    _syncWithArduino();
    notifyListeners();
  }

  void setSentido(bool cw) {
    sentidoCW = cw;
    if (motorActivo) _syncWithArduino();
    notifyListeners();
  }

  void setStepMode(StepMode mode) {
    stepMode = mode;
    if (motorActivo) _syncWithArduino();
    notifyListeners();
  }

  void setVelocidad(int ms) {
    velocidad = ms;
    _addLog('Info: Velocidad ajustada localmente a $ms ms/paso.');
    notifyListeners();
  }

  void resetPosicion() {
    posicion = 0;
    grados = 0.0;
    _addLog('Local: Posición reseteada');
    notifyListeners();
  }

  void pedirVoltaje() {
    _addLog('Info: El firmware actual no soporta lectura de voltaje.');
  }

  // ─────────────────────────────────────────────────────────────────
  //  RECEPCIÓN DE RESPUESTAS
  // ─────────────────────────────────────────────────────────────────

  void _listenToStream() {
    _connection!.input!.listen(
      (Uint8List data) {
        _buffer += utf8.decode(data, allowMalformed: true);
        while (_buffer.contains('\n')) {
          final idx = _buffer.indexOf('\n');
          final line = _buffer.substring(0, idx).trim();
          _buffer = _buffer.substring(idx + 1);
          if (line.isNotEmpty) _parseLine(line);
        }
      },
      onDone: () {
        btState = BtState.disconnected;
        motorActivo = false;
        _addLog('>> Conexión cerrada');
        notifyListeners();
      },
    );
  }

  void _parseLine(String line) {
    _addLog('< $line');
    if (line.contains('Modo:')) {
      if (line.contains('CW')) sentidoCW = true;
      if (line.contains('CCW')) sentidoCW = false;
      if (line.contains('STOP')) motorActivo = false;
    }
    notifyListeners();
  }

  void _addLog(String msg) {
    serialLog.add(msg);
    if (serialLog.length > _maxLog) serialLog.removeAt(0);
    notifyListeners();
  }

  void clearLog() {
    serialLog.clear();
    notifyListeners();
  }
}
