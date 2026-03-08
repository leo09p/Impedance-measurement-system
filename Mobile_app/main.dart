import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(ImpedanceApp());
}

class ImpedanceApp extends StatefulWidget {
  @override
  _ImpedanceAppState createState() => _ImpedanceAppState();
}

class _ImpedanceAppState extends State<ImpedanceApp> {
  bool isDarkMode = false;

  void toggleTheme() {
    setState(() {
      isDarkMode = !isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Medidor de Impedancia',
      theme: isDarkMode ? ThemeData.dark() : ThemeData.light(),
      home: DashboardScreen(toggleTheme: toggleTheme),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  DashboardScreen({required this.toggleTheme});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {

  double impedance = 0;
  int batteryPercent = 0;
  bool isCharging = false;
  double batteryVoltage = 0;
  double chargingTimeLeft = 0;

  String connectionStatus = "Conectando a Firebase...";
  List<Map<String, dynamic>> historyLog = [];

  final DatabaseReference dbRef = FirebaseDatabase.instance.ref("mediciones");

  late AnimationController _batteryController;
  late Animation<double> _batteryAnimation;

  @override
  void initState() {
    super.initState();
    listenToFirebase();

    _batteryController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );

    _batteryAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _batteryController, curve: Curves.easeOut),
    );
  }

  void listenToFirebase() {
    dbRef.onValue.listen((event) {

      final data = event.snapshot.value;

      if (data != null && data is Map) {

        double newImpedance = (data["impedance"] ?? 0).toDouble();
        int newBatteryPercent = (data["batteryPercent"] ?? 0).toInt();
        double newBatteryVoltage = (data["batteryVoltage"] ?? 0).toDouble();
        bool newIsCharging = data["isCharging"] == 1;
        double newChargingTimeLeft = (data["chargingTimeLeft"] ?? 0).toDouble();

        setState(() {

          impedance = newImpedance;
          batteryPercent = newBatteryPercent;
          batteryVoltage = newBatteryVoltage;
          isCharging = newIsCharging;
          chargingTimeLeft = newChargingTimeLeft;

          _batteryAnimation = Tween<double>(
            begin: _batteryAnimation.value,
            end: batteryPercent.toDouble(),
          ).animate(
            CurvedAnimation(parent: _batteryController, curve: Curves.easeOut),
          );

          _batteryController.forward(from: 0);

          historyLog.add({
            'num': historyLog.length + 1,
            'impedance': impedance,
            'time': DateFormat.Hms().format(DateTime.now()),
          });

          if (historyLog.length > 50) historyLog.removeAt(0);

          connectionStatus = "Conectado a Firebase";
        });
      }

    }, onError: (error) {
      setState(() {
        connectionStatus = "Error Firebase";
      });
    });
  }

  Color getStatusColor() {
    if (connectionStatus.contains("Conectado")) return Colors.green;
    if (connectionStatus.contains("Error")) return Colors.red;
    return Colors.orange;
  }

  void goToHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => HistoryScreen(historyLog: historyLog)),
    );
  }

  void goToHelp() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => HelpScreen()),
    );
  }

  @override
  void dispose() {
    _batteryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: Text('Medidor de Impedancia'),
        actions: [
          IconButton(icon: Icon(Icons.brightness_6), onPressed: widget.toggleTheme),
          IconButton(icon: Icon(Icons.history), onPressed: goToHistory),
          IconButton(icon: Icon(Icons.help_outline), onPressed: goToHelp),
        ],
      ),

      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),

        child: Column(
          children: [

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud, color: getStatusColor()),
                SizedBox(width: 8),
                Text(
                  connectionStatus,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: getStatusColor()),
                ),
              ],
            ),

            SizedBox(height: 20),

            Text(
              'Impedancia (mΩ)',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            Text(
              impedance.toStringAsFixed(1),
              style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue),
            ),

            SizedBox(height: 16),

            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: 1000,
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: true, interval: 250)),
                    bottomTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: historyLog
                          .asMap()
                          .entries
                          .map((e) => FlSpot(
                          e.key.toDouble(),
                          e.value['impedance'].toDouble()))
                          .toList(),
                      isCurved: false,
                      color: Colors.blue,
                      barWidth: 3,
                      dotData: FlDotData(show: true),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            Text('Batería',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),

            SizedBox(height: 16),

            SizedBox(
              width: 180,
              height: 180,
              child: AnimatedBuilder(
                animation: _batteryAnimation,
                builder: (context, child) {
                  return CustomPaint(
                    painter:
                    BatteryMeterPainter180(_batteryAnimation.value, isCharging),
                  );
                },
              ),
            ),

            SizedBox(height: 8),

            Text(
              '${batteryPercent}%  |  ${batteryVoltage.toStringAsFixed(2)} V',
              style: TextStyle(fontSize: 16),
            ),

            if (isCharging)
              Text(
                'Tiempo restante: ${chargingTimeLeft.toStringAsFixed(0)} min',
                style: TextStyle(fontSize: 16, color: Colors.orange),
              ),
          ],
        ),
      ),
    );
  }
}

class BatteryMeterPainter180 extends CustomPainter {

  final double percent;
  final bool isCharging;

  BatteryMeterPainter180(this.percent, this.isCharging);

  @override
  void paint(Canvas canvas, Size size) {

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final backgroundPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final foregroundPaint = Paint()
      ..shader = LinearGradient(colors: [Colors.green, Colors.blue])
          .createShader(Rect.fromCircle(center: center, radius: radius))
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final startAngle = pi;
    final sweepAngle = pi;

    canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        backgroundPaint);

    double angle = sweepAngle * (percent / 100);

    canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        angle,
        false,
        foregroundPaint);

    final needlePaint = Paint()
      ..color = Colors.redAccent
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final needleLength = radius - 15;
    final needleAngle = startAngle + angle;

    final nx = center.dx + needleLength * cos(needleAngle);
    final ny = center.dy + needleLength * sin(needleAngle);

    canvas.drawLine(center, Offset(nx, ny), needlePaint);

    canvas.drawCircle(center, 6, Paint()..color = Colors.black);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class HistoryScreen extends StatelessWidget {

  final List<Map<String, dynamic>> historyLog;

  HistoryScreen({required this.historyLog});

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: Text('Historial')),

      body: ListView.builder(
        itemCount: historyLog.length,

        itemBuilder: (_, index) {

          final entry = historyLog[index];

          return ListTile(
            leading: Text('${entry['num']}'),
            title: Text('${entry['impedance'].toStringAsFixed(1)} mΩ'),
            trailing: Text('${entry['time']}'),
          );
        },
      ),
    );
  }
}


// Ayuda
// Pantalla de ayuda profesional
class HelpScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Ayuda y Guía del Fabricante')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Introducción
            Card(
              color: Colors.blue[50],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Introducción',
                      style:
                      TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Bienvenido a la aplicación de medición de impedancia en tiempo real. '
                          'Esta app permite visualizar las mediciones enviadas desde el dispositivo ESP32 a Firebase, '
                          'mostrando valores numéricos y gráficos lineales para facilitar su interpretación.',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // Indicadores de conexión
            Card(
              color: Colors.orange[50],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Indicadores de conexión',
                      style:
                      TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.circle, color: Colors.green, size: 16),
                        SizedBox(width: 6),
                        Expanded(child: Text('Verde: Conectado y recibiendo datos correctamente.')),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Icons.circle, color: Colors.orange, size: 16),
                        SizedBox(width: 6),
                        Expanded(child: Text('Naranja: Intentando conectarse a Firebase.')),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Icons.circle, color: Colors.red, size: 16),
                        SizedBox(width: 6),
                        Expanded(child: Text('Rojo: Error en la conexión con Firebase.')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // Acerca del fabricante
            Card(
              color: Colors.green[50],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Acerca del Fabricante',
                      style:
                      TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Fabricantes: Leonel Araque y Fabian Amador\n'
                          'Versión: 1.0\n\n'
                          'Este proyecto fue desarrollado como un medidor de impedancia en tiempo real utilizando ESP32, Firebase y Flutter. '
                          'Permite registrar, visualizar y monitorear las mediciones de impedancia y estado de batería del dispositivo de manera intuitiva.',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // Instrucciones de uso
            Card(
              color: Colors.purple[50],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Instrucciones de Uso',
                      style:
                      TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '- Asegúrese de que el ESP32 esté conectado a una red WiFi con acceso a Internet.\n'
                          '- La app actualizará automáticamente los datos cada vez que el ESP32 los envíe.\n'
                          '- Los datos de impedancia se muestran en una gráfica lineal y en números grandes.\n'
                          '- La sección de batería muestra porcentaje, voltaje, estado de carga y tiempo restante si aplica.\n'
                          '- Para ver el historial completo de mediciones, use el icono de Historial en la parte superior derecha.',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // Notas finales
            Card(
              color: Colors.grey[200],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notas Finales',
                      style:
                      TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Recuerde que esta aplicación es un proyecto educativo y de prototipo. '
                          'Se recomienda verificar la calibración del ESP32 y la conexión a Firebase antes de usarla para mediciones críticas.',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}