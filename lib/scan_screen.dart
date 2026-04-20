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
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initBluetooth();
  }

  Future<void> _initBluetooth() async {
    setState(() => _isLoading = true);
    
    // 1. Pedir permisos (Crítico en Android)
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    // 2. Verificar si el Bluetooth está encendido
    bool? isEnabled = await FlutterBluetoothSerial.instance.isEnabled;
    if (isEnabled != true) {
      await FlutterBluetoothSerial.instance.requestEnable();
    }

    _fetchBondedDevices();
  }

  Future<void> _fetchBondedDevices() async {
    setState(() => _isLoading = true);
    try {
      // Obtenemos los dispositivos que ya están vinculados en Ajustes del Celular
      List<BluetoothDevice> bondedDevices = await FlutterBluetoothSerial.instance.getBondedDevices();
      setState(() {
        _devices = bondedDevices;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al obtener dispositivos: $e')),
      );
    }
  }

  Future<void> _connect(BluetoothDevice device) async {
    final ctrl = context.read<BtController>();
    
    // Mostramos un indicador de carga mientras conecta
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final ok = await ctrl.connect(device);
    
    if (!mounted) return;
    Navigator.pop(context); // Quitar el círculo de carga

    if (ok) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ControlScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de conexión. Asegúrate que el HC-05 esté encendido.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dispositivos Vinculados'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchBondedDevices,
          )
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _devices.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.bluetooth_disabled, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'No se encontraron dispositivos vinculados.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Primero vincula tu HC-05 en los Ajustes de Bluetooth de tu teléfono.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _fetchBondedDevices,
                      child: const Text('Reintentar'),
                    )
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _devices.length,
              itemBuilder: (context, index) {
                final device = _devices[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: const Icon(Icons.bluetooth, color: Colors.blue),
                    title: Text(device.name ?? "Dispositivo desconocido"),
                    subtitle: Text(device.address),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _connect(device),
                  ),
                );
              },
            ),
    );
  }
}
