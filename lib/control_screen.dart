import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'bt_controller.dart';
import 'scan_screen.dart';

class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  final ScrollController _logScroll = ScrollController();

  @override
  void dispose() {
    _logScroll.dispose();
    super.dispose();
  }

  void _scrollLog() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScroll.hasClients) {
        _logScroll.jumpTo(_logScroll.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Consumer<BtController>(
      builder: (_, ctrl, __) {
        _scrollLog();
        return Scaffold(
          appBar: AppBar(
            backgroundColor: cs.primary,
            foregroundColor: Colors.white,
            title: const Text('StepperControl'),
            actions: [
              // Badge de conexión
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Chip(
                  label: Text(ctrl.connectedDeviceName,
                      style: const TextStyle(fontSize: 11, color: Colors.white)),
                  backgroundColor: Colors.white24,
                  avatar: Icon(
                    ctrl.btState == BtState.connected
                        ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                    size: 14, color: Colors.white),
                ),
              ),
            ],
          ),

          // ─── BOTÓN DESCONECTAR ───────────────────────────────
          drawer: Drawer(
            child: SafeArea(
              child: Column(children: [
                const DrawerHeader(child: Text('Opciones')),
                ListTile(
                  leading: const Icon(Icons.bluetooth_disabled, color: Colors.red),
                  title: const Text('Desconectar'),
                  onTap: () {
                    ctrl.disconnect();
                    Navigator.pushReplacement(context,
                        MaterialPageRoute(builder: (_) => const ScanScreen()));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Limpiar consola'),
                  onTap: () { ctrl.clearLog(); Navigator.pop(context); },
                ),
              ]),
            ),
          ),

          body: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // ── TARJETA: CONTROL ─────────────────────────────
              _Card(
                title: 'Control',
                child: Column(children: [
                  // START / STOP
                  Row(children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ctrl.motorActivo
                              ? const Color(0xFFC62828) : const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: Icon(ctrl.motorActivo ? Icons.stop : Icons.play_arrow),
                        label: Text(ctrl.motorActivo ? 'STOP' : 'START'),
                        onPressed: ctrl.btState == BtState.connected
                            ? ctrl.toggleMotor : null,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  // CW / CCW
                  Row(children: [
                    Expanded(
                      child: _DirButton(
                        label: '↺  CW',
                        active: ctrl.sentidoCW,
                        onTap: () => ctrl.setSentido(true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _DirButton(
                        label: '↻  CCW',
                        active: !ctrl.sentidoCW,
                        onTap: () => ctrl.setSentido(false),
                      ),
                    ),
                  ]),
                ]),
              ),

              const SizedBox(height: 10),

              // ── TARJETA: MODO DE PASO ─────────────────────────
              _Card(
                title: 'Modo de paso',
                child: Row(children: [
                  _ModeChip(label: 'Simple', active: ctrl.stepMode == StepMode.simple,
                      onTap: () => ctrl.setStepMode(StepMode.simple)),
                  const SizedBox(width: 8),
                  _ModeChip(label: 'Doble', active: ctrl.stepMode == StepMode.doble,
                      onTap: () => ctrl.setStepMode(StepMode.doble)),
                  const SizedBox(width: 8),
                  _ModeChip(label: 'Medio', active: ctrl.stepMode == StepMode.medio,
                      onTap: () => ctrl.setStepMode(StepMode.medio)),
                ]),
              ),

              const SizedBox(height: 10),

              // ── TARJETA: TELEMETRÍA ──────────────────────────
              _Card(
                title: 'Telemetría',
                action: IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  onPressed: ctrl.pedirVoltaje,
                  tooltip: 'Pedir voltaje',
                ),
                child: Column(children: [
                  // Aguja de posición angular
                  SizedBox(
                    height: 100,
                    child: CustomPaint(
                      painter: _GaugePainter(ctrl.grados),
                      size: const Size(double.infinity, 100),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Grid de valores
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 2.5,
                    children: [
                      _TeleItem(label: 'Posición', value: '${ctrl.posicion}', unit: 'pasos'),
                      _TeleItem(label: 'Ángulo', value: ctrl.grados.toStringAsFixed(1), unit: '°'),
                      _TeleItem(label: 'Voltaje', value: ctrl.voltaje.toStringAsFixed(2), unit: 'V'),
                      _TeleItem(label: 'Vel actual', value: '${ctrl.velRecibida}', unit: 'ms'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.restore, size: 16),
                    label: const Text('Resetear posición'),
                    onPressed: ctrl.resetPosicion,
                    style: OutlinedButton.styleFrom(
                        textStyle: const TextStyle(fontSize: 12)),
                  ),
                ]),
              ),

              const SizedBox(height: 10),

              // ── TARJETA: CONSOLA SERIAL ──────────────────────
              _Card(
                title: 'Consola serial',
                action: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: ctrl.clearLog,
                ),
                child: Container(
                  height: 160,
                  decoration: BoxDecoration(
                    color: const Color(0xFF090915),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: ListView.builder(
                    controller: _logScroll,
                    itemCount: ctrl.serialLog.length,
                    itemBuilder: (_, i) {
                      final line = ctrl.serialLog[i];
                      Color c = Colors.grey.shade500;
                      if (line.startsWith('>')) c = const Color(0xFF4CAF50);
                      if (line.startsWith('<')) c = const Color(0xFF90CAF9);
                      if (line.startsWith('[')) c = Colors.redAccent;
                      return Text(line,
                          style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10, color: c, height: 1.6));
                    },
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  WIDGETS AUXILIARES
// ─────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? action;
  const _Card({required this.title, required this.child, this.action});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12, width: 0.5),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(title.toUpperCase(),
              style: const TextStyle(
                  fontSize: 10, letterSpacing: 0.5,
                  color: Color(0xFF90CAF9), fontWeight: FontWeight.w500)),
          if (action != null) ...[const Spacer(), action!],
        ]),
        const SizedBox(height: 10),
        child,
      ]),
    );
  }
}

class _DirButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _DirButton({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1976D2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF1976D2),
            width: active ? 0 : 0.5,
          ),
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: active ? Colors.white : const Color(0xFF90CAF9),
                fontSize: 13, fontWeight: FontWeight.w500)),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ModeChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF1976D2) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
                color: const Color(0xFF1976D2), width: 0.5),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: active ? Colors.white : const Color(0xFF90CAF9),
                  fontSize: 11)),
        ),
      ),
    );
  }
}

class _TeleItem extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  const _TeleItem({required this.label, required this.value, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF13132A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 9,
                    letterSpacing: 0.4)),
            const SizedBox(height: 2),
            RichText(text: TextSpan(children: [
              TextSpan(text: value,
                  style: const TextStyle(color: Colors.white,
                      fontSize: 15, fontWeight: FontWeight.w500)),
              TextSpan(text: ' $unit',
                  style: const TextStyle(color: Colors.grey, fontSize: 10)),
            ])),
          ]),
    );
  }
}

/// Aguja tipo velocímetro para mostrar el ángulo del motor
class _GaugePainter extends CustomPainter {
  final double degrees;
  _GaugePainter(this.degrees);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height - 10;
    final r = size.height - 20;

    // Arco de fondo
    final bgPaint = Paint()
      ..color = Colors.white12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        pi, pi, false, bgPaint);

    // Arco de progreso
    final prog = degrees / 360.0;
    final fgPaint = Paint()
      ..color = const Color(0xFF1976D2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        pi, pi * prog, false, fgPaint);

    // Aguja
    final rad = pi + pi * prog;
    final needlePaint = Paint()..color = Colors.white..strokeWidth = 2..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(cx, cy),
        Offset(cx + cos(rad) * (r - 10), cy + sin(rad) * (r - 10)),
        needlePaint);

    // Centro
    canvas.drawCircle(Offset(cx, cy), 5, Paint()..color = const Color(0xFF1976D2));

    // Texto de grados
    final tp = TextPainter(
      text: TextSpan(
          text: '${degrees.toStringAsFixed(1)}°',
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - r - 20));
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.degrees != degrees;
}
