import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

/// Estados posibles de la conexión Bluetooth
enum BtState { disconnected, connecting, connected }

/// Modos de paso del motor
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
  int velocidad = 5;              // ms entre pasos (1–50)
  StepMode stepMode = StepMode.simple;

  // ── Telemetría (llegando del Arduino) ────────────────────────────
  int posicion = 0;
  double grados = 0.0;
  double voltaje = 0.0;
  int velRecibida = 5;

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
  //  ENVÍO DE COMANDOS
  // ─────────────────────────────────────────────────────────────────

  void sendCommand(String cmd) {
    if (_connection == null || !_connection!.isConnected) return;
    final data = Uint8List.fromList(utf8.encode('$cmd\n'));
    _connection!.output.add(data);
    _addLog('> $cmd');
  }

  void toggleMotor() {
    motorActivo = !motorActivo;
    sendCommand(motorActivo ? 'START' : 'STOP');
    notifyListeners();
  }

  void setSentido(bool cw) {
    sentidoCW = cw;
    sendCommand(cw ? 'CW' : 'CCW');
    notifyListeners();
  }

  void setVelocidad(int ms) {
    velocidad = ms;
    sendCommand('V:$ms');
    notifyListeners();
  }

  void setStepMode(StepMode mode) {
    stepMode = mode;
    final cmd = switch (mode) {
      StepMode.simple => 'S1',
      StepMode.doble  => 'S2',
      StepMode.medio  => 'SM',
    };
    sendCommand(cmd);
    notifyListeners();
  }

  void resetPosicion() {
    sendCommand('RESET');
    posicion = 0;
    grados = 0.0;
    notifyListeners();
  }

  void pedirVoltaje() => sendCommand('READ');

  // ─────────────────────────────────────────────────────────────────
  //  RECEPCIÓN DE TELEMETRÍA
  // ─────────────────────────────────────────────────────────────────

  void _listenToStream() {
    _connection!.input!.listen(
      (Uint8List data) {
        _buffer += utf8.decode(data, allowMalformed: true);
        // Procesar líneas completas
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
        _addLog('>> Conexión cerrada por el dispositivo');
        notifyListeners();
      },
    );
  }

  void _parseLine(String line) {
    _addLog('< $line');

    if (line.startsWith('POS:')) {
      posicion = int.tryParse(line.substring(4)) ?? posicion;
      // Calcular grados: 28BYJ-48 half-step = 4096 pasos/rev
      grados = (posicion % 4096) / 4096.0 * 360.0;
      if (grados < 0) grados += 360.0;
    } else if (line.startsWith('VOL:')) {
      voltaje = double.tryParse(line.substring(4)) ?? voltaje;
    } else if (line.startsWith('VEL:')) {
      velRecibida = int.tryParse(line.substring(4)) ?? velRecibida;
      velocidad = velRecibida;
    } else if (line.startsWith('DIR:')) {
      sentidoCW = line.substring(4).trim() == 'CW';
    }

    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────
  //  LOG
  // ─────────────────────────────────────────────────────────────────

  void _addLog(String msg) {
    serialLog.add(msg);
    if (serialLog.length > _maxLog) serialLog.removeAt(0);
    // No llamamos notifyListeners() aquí para no re-renderizar
    // toda la UI solo por un log; el ScrollController de la consola
    // se actualiza por separado.
  }

  void clearLog() {
    serialLog.clear();
    notifyListeners();
  }
}
