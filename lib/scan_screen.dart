import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'bt_controller.dart';
import 'control_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  List<BluetoothDevice> _devices = [];
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _requestPermsAndScan();
  }

  Future<void> _requestPermsAndScan() async {
    // Android 12+ requiere BLUETOOTH_SCAN + BLUETOOTH_CONNECT
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    _scanDevices();
  }

  Future<void> _scanDevices() async {
    setState(() { _scanning = true; _devices = []; });

    // Dispositivos ya emparejados (el HC-06 suele estar aquí)
    final bonded = await FlutterBluetoothSerial.instance.getBondedDevices();
    setState(() {
      _devices = bonded;
      _scanning = false;
    });
  }

  Future<void> _connect(BluetoothDevice device) async {
    final ctrl = context.read<BtController>();
    final ok = await ctrl.connect(device);
    if (!mounted) return;
    if (ok) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ControlScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo conectar. ¿Está encendido el HC-06?')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conectar dispositivo'),
        backgroundColor: cs.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: _scanning
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.refresh),
            onPressed: _scanning ? null : _scanDevices,
          ),
        ],
      ),
      body: Column(
        children: [
          // Ícono Bluetooth animado
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(children: [
              Icon(Icons.bluetooth_searching, size: 56, color: cs.primary),
              const SizedBox(height: 8),
              Text(
                _scanning ? 'Buscando dispositivos emparejados...' : 'Dispositivos encontrados',
                style: TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: 13),
              ),
            ]),
          ),

          // Lista de dispositivos
          Expanded(
            child: _devices.isEmpty && !_scanning
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('Sin dispositivos emparejados',
                          style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 12),
                      Text('Empareja el HC-06 primero en la configuración BT de Android',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 12)),
                    ]),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _devices.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final dev = _devices[i];
                      return Card(
                        color: const Color(0xFF1E1E30),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                                color: dev.name?.contains('HC') == true
                                    ? cs.primary.withOpacity(0.6)
                                    : Colors.grey.shade800,
                                width: 0.5)),
                        child: ListTile(
                          leading: Icon(Icons.bluetooth,
                              color: dev.name?.contains('HC') == true
                                  ? cs.primary : Colors.grey),
                          title: Text(dev.name ?? 'Desconocido',
                              style: const TextStyle(fontWeight: FontWeight.w500)),
                          subtitle: Text(dev.address,
                              style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: cs.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                textStyle: const TextStyle(fontSize: 12)),
                            onPressed: () => _connect(dev),
                            child: const Text('Conectar'),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Nota de ayuda
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'PIN del HC-06: 1234  •  Baud rate: 9600',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
