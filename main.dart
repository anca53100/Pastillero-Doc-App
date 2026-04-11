import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
runApp(const DocApp());
}

const String esp32BaseUrl = 'http://192.168.0.8';

Future<void> enviarMedicamentoAlESP32({
  required int compartimiento,
  required MedicationData medicamento,
}) async {
  final url = Uri.parse('$esp32BaseUrl/configurar');

  final body = {
    'compartimiento': 1,
    'nombre': medicamento.nombre,
    'cantidadPastillas': medicamento.cantidadPastillas,
    'frecuenciaHoras': medicamento.frecuenciaHoras,
    'totalPastillasCargadas': medicamento.totalPastillasCargadas,
    'pastillasRestantes': medicamento.pastillasRestantes,
    'horaPrimeraDosis': {
      'hour': medicamento.primeraDosis.hour,
      'minute': medicamento.primeraDosis.minute,
    },
    'proximaDosis': medicamento.proximaDosis.toIso8601String(),
  };

  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(body),
  );

  if (response.statusCode != 200) {
    throw Exception('No se pudo enviar la configuración al ESP32');
  }
}

Future<void> notificarTomaConfirmadaAlESP32({
  required int compartimiento,
  required MedicationData medicamento,
}) async {
  final url = Uri.parse('$esp32BaseUrl/confirmar-toma');

  final body = {
    'compartimiento': 1,
    'nombre': medicamento.nombre,
    'cantidadPastillas': medicamento.cantidadPastillas,
    'pastillasRestantes': medicamento.pastillasRestantes,
    'proximaDosis': medicamento.proximaDosis.toIso8601String(),
  };

  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(body),
  );

  if (response.statusCode != 200) {
    throw Exception('No se pudo notificar la toma al ESP32');
  }
}

String dosDigitos(int numero) {
return numero.toString().padLeft(2, '0');
}

DateTime redondearAlMinuto(DateTime fecha) {
return DateTime(
fecha.year,
fecha.month,
fecha.day,
fecha.hour,
fecha.minute,
);
}

DateTime combinarFechaYHora(DateTime fecha, TimeOfDay hora) {
return DateTime(
fecha.year,
fecha.month,
fecha.day,
hora.hour,
hora.minute,
);
}

String formatearHora(DateTime fecha) {
int hora = fecha.hour;
final String periodo = hora >= 12 ? 'PM' : 'AM';

hora = hora % 12;
if (hora == 0) {
hora = 12;
}

return '$hora:${dosDigitos(fecha.minute)} $periodo';
}

String etiquetaFecha(DateTime fecha) {
final hoy = DateUtils.dateOnly(DateTime.now());
final objetivo = DateUtils.dateOnly(fecha);
final diferencia = objetivo.difference(hoy).inDays;

if (diferencia == 0) return 'Hoy';
if (diferencia == 1) return 'Mañana';
if (diferencia == -1) return 'Ayer';

return '${dosDigitos(fecha.day)}/${dosDigitos(fecha.month)}';
}

String formatearFechaHoraCorta(DateTime fecha) {
return '${etiquetaFecha(fecha)} • ${formatearHora(fecha)}';
}

bool mismaFechaHoraMinuto(DateTime a, DateTime b) {
return a.year == b.year &&
a.month == b.month &&
a.day == b.day &&
a.hour == b.hour &&
a.minute == b.minute;
}

TimeOfDay? parsearHoraManual(String texto) {
final limpio = texto.trim().toUpperCase();
final regex = RegExp(r'^(\d{1,2}):(\d{2})\s*([AP]M)$');
final match = regex.firstMatch(limpio);

if (match == null) return null;

final int? hora12 = int.tryParse(match.group(1)!);
final int? minuto = int.tryParse(match.group(2)!);
final String periodo = match.group(3)!;

if (hora12 == null || minuto == null) return null;
if (hora12 < 1 || hora12 > 12) return null;
if (minuto < 0 || minuto > 59) return null;

int hora24 = hora12 % 12;
if (periodo == 'PM') {
hora24 += 12;
}

return TimeOfDay(hour: hora24, minute: minuto);
}

DateTime calcularProximaDosisDesdeHoraBase({
required TimeOfDay horaBase,
required int frecuenciaHoras,
DateTime? referencia,
}) {
final ahora = redondearAlMinuto(referencia ?? DateTime.now());
final hoy = DateUtils.dateOnly(ahora);
final primeraDosis = combinarFechaYHora(hoy, horaBase);
final intervalo = Duration(hours: frecuenciaHoras);

DateTime proxima = primeraDosis;

while (proxima.isBefore(ahora)) {
proxima = proxima.add(intervalo);
}

return proxima;
}

enum UserRole {
paciente,
cuidador,
}

enum CaregiverRelationship {
familiar,
enfermero,
amigo,
otro,
}

String userRoleLabel(UserRole role) {
switch (role) {
case UserRole.paciente:
return 'Paciente';
case UserRole.cuidador:
return 'Cuidador';
}
}

String caregiverRelationshipLabel(CaregiverRelationship relationship) {
switch (relationship) {
case CaregiverRelationship.familiar:
return 'Familiar';
case CaregiverRelationship.enfermero:
return 'Enfermero(a)';
case CaregiverRelationship.amigo:
return 'Amigo(a)';
case CaregiverRelationship.otro:
return 'Otro';
}
}

class AppUser {
final String nombre;
final String correo;
final UserRole rol;

const AppUser({
required this.nombre,
required this.correo,
required this.rol,
});
}

class CareLink {
final String patientCode;
final CaregiverRelationship relationship;

const CareLink({
required this.patientCode,
required this.relationship,
});
}

class DocApp extends StatelessWidget {
const DocApp({super.key});

@override
Widget build(BuildContext context) {
return MaterialApp(
debugShowCheckedModeBanner: false,
title: 'Doc',
theme: ThemeData(
useMaterial3: true,
scaffoldBackgroundColor: const Color(0xFFEDEDED),
colorScheme: ColorScheme.fromSeed(
seedColor: const Color(0xFF111111),
brightness: Brightness.light,
),
),
home: const WelcomePage(),
);
}
}

class MedicationData {
final String nombre;
final int cantidadPastillas;
final int frecuenciaHoras;
final int totalPastillasCargadas;
final int pastillasRestantes;
final DateTime primeraDosis;
final DateTime proximaDosis;

const MedicationData({
required this.nombre,
required this.cantidadPastillas,
required this.frecuenciaHoras,
required this.totalPastillasCargadas,
required this.pastillasRestantes,
required this.primeraDosis,
required this.proximaDosis,
});

String get cantidadTexto {
if (cantidadPastillas == 1) {
return '1 pastilla';
}
return '$cantidadPastillas pastillas';
}

String get frecuenciaTexto => 'Cada $frecuenciaHoras horas';

String get restantesTexto {
if (pastillasRestantes == 1) {
return 'Queda 1 pastilla';
}
return 'Quedan $pastillasRestantes pastillas';
}

MedicationData copyWith({
String? nombre,
int? cantidadPastillas,
int? frecuenciaHoras,
int? totalPastillasCargadas,
int? pastillasRestantes,
DateTime? primeraDosis,
DateTime? proximaDosis,
}) {
return MedicationData(
nombre: nombre ?? this.nombre,
cantidadPastillas: cantidadPastillas ?? this.cantidadPastillas,
frecuenciaHoras: frecuenciaHoras ?? this.frecuenciaHoras,
totalPastillasCargadas:
totalPastillasCargadas ?? this.totalPastillasCargadas,
pastillasRestantes: pastillasRestantes ?? this.pastillasRestantes,
primeraDosis: primeraDosis ?? this.primeraDosis,
proximaDosis: proximaDosis ?? this.proximaDosis,
);
}
}

class PhoneFrame extends StatelessWidget {
final Widget child;

const PhoneFrame({
super.key,
required this.child,
});

@override
Widget build(BuildContext context) {
return LayoutBuilder(
builder: (context, constraints) {
final double frameHeight =
constraints.maxHeight > 840 ? 840 : constraints.maxHeight;

return Center(
child: ConstrainedBox(
constraints: const BoxConstraints(maxWidth: 390),
child: Container(
height: frameHeight,
decoration: BoxDecoration(
color: const Color(0xFFF3F3F3),
borderRadius: BorderRadius.circular(34),
border: Border.all(
color: const Color(0xFFD8D8D8),
width: 1,
),
boxShadow: [
BoxShadow(
color: Colors.black.withValues(alpha: 0.10),
blurRadius: 28,
offset: const Offset(0, 14),
),
],
),
clipBehavior: Clip.antiAlias,
child: Material(
color: const Color(0xFFF3F3F3),
child: child,
),
),
),
);
},
);
}
}

class WelcomePage extends StatefulWidget {
const WelcomePage({super.key});

@override
State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
String? rolSeleccionado;

void continuar() {
if (rolSeleccionado == null) return;

final UserRole rol = rolSeleccionado == 'paciente'
? UserRole.paciente
: UserRole.cuidador;

Navigator.push(
context,
MaterialPageRoute(
builder: (_) => AuthSetupPage(rol: rol),
),
);
}

@override
Widget build(BuildContext context) {
return Scaffold(
body: SafeArea(
child: PhoneFrame(
child: Padding(
padding: const EdgeInsets.all(22),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Spacer(),
const Text(
'Bienvenido a\nDoc',
style: TextStyle(
fontSize: 30,
height: 1.0,
fontWeight: FontWeight.w800,
),
),
const SizedBox(height: 18),
const Text(
'Tu asistente para nunca olvidar un medicamento. ¿Cómo deseas ingresar?',
style: TextStyle(
fontSize: 17,
height: 1.2,
color: Color(0xFF222222),
),
),
const SizedBox(height: 34),
RoleCard(
titulo: 'Soy el paciente',
descripcion: 'Gestiona tus medicamentos y recordatorios',
seleccionado: rolSeleccionado == 'paciente',
onTap: () {
setState(() {
rolSeleccionado = 'paciente';
});
},
),
const SizedBox(height: 18),
RoleCard(
titulo: 'Soy el cuidador',
descripcion: 'Monitorea y acompaña a tu familiar',
seleccionado: rolSeleccionado == 'cuidador',
onTap: () {
setState(() {
rolSeleccionado = 'cuidador';
});
},
),
const SizedBox(height: 34),
SizedBox(
width: double.infinity,
child: ElevatedButton(
onPressed: rolSeleccionado == null ? null : continuar,
style: ElevatedButton.styleFrom(
backgroundColor: const Color(0xFFE7E7E7),
foregroundColor: Colors.black,
disabledBackgroundColor: const Color(0xFFE7E7E7),
disabledForegroundColor: Colors.black45,
elevation: 0,
padding: const EdgeInsets.symmetric(vertical: 18),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(28),
),
),
child: const Text(
'Continuar',
style: TextStyle(
fontSize: 16,
fontWeight: FontWeight.w500,
),
),
),
),
const Spacer(),
],
),
),
),
),
);
}
}

class RoleCard extends StatelessWidget {
final String titulo;
final String descripcion;
final bool seleccionado;
final VoidCallback onTap;

const RoleCard({
super.key,
required this.titulo,
required this.descripcion,
required this.seleccionado,
required this.onTap,
});

@override
Widget build(BuildContext context) {
return Material(
color: seleccionado ? const Color(0xFFEFEFEF) : const Color(0xFFF8F8F8),
borderRadius: BorderRadius.circular(24),
child: InkWell(
borderRadius: BorderRadius.circular(24),
onTap: onTap,
child: Ink(
padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(24),
border: Border.all(
color: seleccionado
? const Color(0xFF111111)
: const Color(0xFFF0F0F0),
width: seleccionado ? 1.3 : 1,
),
boxShadow: [
BoxShadow(
color: Colors.black.withValues(alpha: 0.06),
blurRadius: 22,
offset: const Offset(0, 10),
),
],
),
child: Row(
children: [
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
titulo,
style: const TextStyle(
fontSize: 22,
fontWeight: FontWeight.w700,
),
),
const SizedBox(height: 8),
Text(
descripcion,
style: const TextStyle(
fontSize: 15,
height: 1.15,
color: Color(0xFF2A2A2A),
),
),
],
),
),
const SizedBox(width: 12),
Container(
width: 24,
height: 24,
decoration: BoxDecoration(
shape: BoxShape.circle,
color: seleccionado
? const Color(0xFF111111)
: Colors.transparent,
border: Border.all(
color: const Color(0xFF111111),
width: 1.2,
),
),
child: seleccionado
? const Icon(
Icons.check,
size: 15,
color: Colors.white,
)
: null,
),
],
),
),
),
);
}
}

class AuthSetupPage extends StatefulWidget {
final UserRole rol;

const AuthSetupPage({
super.key,
required this.rol,
});

@override
State<AuthSetupPage> createState() => _AuthSetupPageState();
}

class _AuthSetupPageState extends State<AuthSetupPage> {
late final TextEditingController nombreController;
late final TextEditingController correoController;

@override
void initState() {
super.initState();
nombreController = TextEditingController();
correoController = TextEditingController();
}

@override
void dispose() {
nombreController.dispose();
correoController.dispose();
super.dispose();
}

InputDecoration buildDecoration(String hintText) {
return InputDecoration(
hintText: hintText,
filled: true,
fillColor: Colors.white,
contentPadding: const EdgeInsets.symmetric(
horizontal: 16,
vertical: 16,
),
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(18),
borderSide: const BorderSide(
color: Color(0xFFE0E0E0),
),
),
enabledBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(18),
borderSide: const BorderSide(
color: Color(0xFFE0E0E0),
),
),
focusedBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(18),
borderSide: const BorderSide(
color: Colors.black,
),
),
);
}

void continuarRegistro() {
final nombre = nombreController.text.trim();
final correo = correoController.text.trim();

if (nombre.isEmpty) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text('Escriba su nombre.'),
),
);
return;
}

if (correo.isEmpty || !correo.contains('@')) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text('Escriba un correo válido.'),
),
);
return;
}

final usuario = AppUser(
nombre: nombre,
correo: correo,
rol: widget.rol,
);

if (widget.rol == UserRole.paciente) {
Navigator.push(
context,
MaterialPageRoute(
builder: (_) => PatientCodePage(usuario: usuario),
),
);
} else {
Navigator.push(
context,
MaterialPageRoute(
builder: (_) => CaregiverLinkPatientPage(usuario: usuario),
),
);
}
}

@override
Widget build(BuildContext context) {
final bool esCuidador = widget.rol == UserRole.cuidador;

return Scaffold(
body: SafeArea(
child: PhoneFrame(
child: SingleChildScrollView(
padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
esCuidador ? 'Registro de\nCuidador' : 'Registro de\nPaciente',
style: const TextStyle(
fontSize: 30,
height: 1.0,
fontWeight: FontWeight.w800,
),
),
const SizedBox(height: 14),
Text(
esCuidador
? 'Complete sus datos para crear la cuenta del cuidador.'
: 'Complete sus datos para crear la cuenta del paciente.',
style: const TextStyle(
fontSize: 15,
height: 1.2,
color: Color(0xFF2A2A2A),
),
),
const SizedBox(height: 24),
Container(
width: double.infinity,
padding: const EdgeInsets.all(18),
decoration: BoxDecoration(
color: const Color(0xFFF6F6F6),
borderRadius: BorderRadius.circular(26),
boxShadow: [
BoxShadow(
color: Colors.black.withValues(alpha: 0.06),
blurRadius: 22,
offset: const Offset(0, 10),
),
],
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text(
'Nombre completo',
style: TextStyle(
fontSize: 13,
fontWeight: FontWeight.w700,
),
),
const SizedBox(height: 8),
TextField(
controller: nombreController,
decoration: buildDecoration('Ej: Mario Lopez'),
),
const SizedBox(height: 14),
const Text(
'Correo electrónico',
style: TextStyle(
fontSize: 13,
fontWeight: FontWeight.w700,
),
),
const SizedBox(height: 8),
TextField(
controller: correoController,
keyboardType: TextInputType.emailAddress,
decoration: buildDecoration('Ej: correo@ejemplo.com'),
),
],
),
),
const SizedBox(height: 22),
SizedBox(
width: double.infinity,
child: ElevatedButton(
onPressed: continuarRegistro,
style: ElevatedButton.styleFrom(
backgroundColor: const Color(0xFFE7E7E7),
foregroundColor: Colors.black,
elevation: 0,
padding: const EdgeInsets.symmetric(vertical: 16),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(22),
),
),
child: const Text(
'Continuar',
style: TextStyle(
fontWeight: FontWeight.w700,
),
),
),
),
const SizedBox(height: 12),
SizedBox(
width: double.infinity,
child: TextButton(
onPressed: () {
Navigator.pop(context);
},
child: const Text(
'Volver',
style: TextStyle(
color: Colors.black54,
fontWeight: FontWeight.w700,
),
),
),
),
],
),
),
),
),
);
}
}

class PatientCodePage extends StatelessWidget {
final AppUser usuario;

const PatientCodePage({
super.key,
required this.usuario,
});

@override
Widget build(BuildContext context) {
const String patientCode = 'DOC-482193';

return Scaffold(
body: SafeArea(
child: PhoneFrame(
child: SingleChildScrollView(
padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text(
'Código de\nvinculación',
style: TextStyle(
fontSize: 30,
height: 1.0,
fontWeight: FontWeight.w800,
),
),
const SizedBox(height: 14),
Text(
'Comparta este código con su cuidador para que pueda vincular su cuenta con la de ${usuario.nombre}.',
style: const TextStyle(
fontSize: 15,
height: 1.2,
color: Color(0xFF2A2A2A),
),
),
const SizedBox(height: 24),
Container(
width: double.infinity,
padding: const EdgeInsets.all(22),
decoration: BoxDecoration(
color: const Color(0xFFF6F6F6),
borderRadius: BorderRadius.circular(26),
boxShadow: [
BoxShadow(
color: Colors.black.withValues(alpha: 0.06),
blurRadius: 22,
offset: const Offset(0, 10),
),
],
),
child: const Column(
children: [
Text(
'SU CÓDIGO',
style: TextStyle(
fontSize: 12,
letterSpacing: 0.8,
fontWeight: FontWeight.w700,
color: Color(0xFF555555),
),
),
SizedBox(height: 12),
Text(
patientCode,
style: TextStyle(
fontSize: 34,
fontWeight: FontWeight.w800,
),
),
SizedBox(height: 10),
Text(
'Más adelante este código será dinámico y único para cada paciente.',
textAlign: TextAlign.center,
style: TextStyle(
fontSize: 13,
height: 1.2,
color: Color(0xFF555555),
),
),
],
),
),
const SizedBox(height: 22),
SizedBox(
width: double.infinity,
child: ElevatedButton(
onPressed: () {
Navigator.push(
context,
MaterialPageRoute(
builder: (_) => PatientHomePage(usuario: usuario),
),
);
},
style: ElevatedButton.styleFrom(
backgroundColor: const Color(0xFFE7E7E7),
foregroundColor: Colors.black,
elevation: 0,
padding: const EdgeInsets.symmetric(vertical: 16),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(22),
),
),
child: const Text(
'Entrar como paciente',
style: TextStyle(
fontWeight: FontWeight.w700,
),
),
),
),
],
),
),
),
),
);
}
}

class CaregiverLinkPatientPage extends StatefulWidget {
final AppUser usuario;

const CaregiverLinkPatientPage({
super.key,
required this.usuario,
});

@override
State<CaregiverLinkPatientPage> createState() =>
_CaregiverLinkPatientPageState();
}

class _CaregiverLinkPatientPageState extends State<CaregiverLinkPatientPage> {
late final TextEditingController codigoController;
CaregiverRelationship? parentescoSeleccionado;

@override
void initState() {
super.initState();
codigoController = TextEditingController();
parentescoSeleccionado = CaregiverRelationship.familiar;
}

@override
void dispose() {
codigoController.dispose();
super.dispose();
}

InputDecoration buildDecoration(String hintText) {
return InputDecoration(
hintText: hintText,
filled: true,
fillColor: Colors.white,
contentPadding: const EdgeInsets.symmetric(
horizontal: 16,
vertical: 16,
),
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(18),
borderSide: const BorderSide(
color: Color(0xFFE0E0E0),
),
),
enabledBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(18),
borderSide: const BorderSide(
color: Color(0xFFE0E0E0),
),
),
focusedBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(18),
borderSide: const BorderSide(
color: Colors.black,
),
),
);
}

void vincularPaciente() {
final codigo = codigoController.text.trim().toUpperCase();

if (codigo.isEmpty) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text('Escriba el código del paciente.'),
),
);
return;
}

if (parentescoSeleccionado == null) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text('Seleccione la relación con el paciente.'),
),
);
return;
}

final vinculo = CareLink(
patientCode: codigo,
relationship: parentescoSeleccionado!,
);

Navigator.push(
context,
MaterialPageRoute(
builder: (_) => const CaregiverHomePlaceholder(),
),
);

ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text(
'Cuenta de ${widget.usuario.nombre} vinculada como ${caregiverRelationshipLabel(vinculo.relationship).toLowerCase()} del paciente.',
),
),
);
}

@override
Widget build(BuildContext context) {
return Scaffold(
body: SafeArea(
child: PhoneFrame(
child: SingleChildScrollView(
padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text(
'Vincular con\npaciente',
style: TextStyle(
fontSize: 30,
height: 1.0,
fontWeight: FontWeight.w800,
),
),
const SizedBox(height: 14),
Text(
'Ingrese el código compartido por el paciente y seleccione qué relación tiene con ${widget.usuario.nombre}.',
style: const TextStyle(
fontSize: 15,
height: 1.2,
color: Color(0xFF2A2A2A),
),
),
const SizedBox(height: 24),
Container(
width: double.infinity,
padding: const EdgeInsets.all(18),
decoration: BoxDecoration(
color: const Color(0xFFF6F6F6),
borderRadius: BorderRadius.circular(26),
boxShadow: [
BoxShadow(
color: Colors.black.withValues(alpha: 0.06),
blurRadius: 22,
offset: const Offset(0, 10),
),
],
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text(
'Código del paciente',
style: TextStyle(
fontSize: 13,
fontWeight: FontWeight.w700,
),
),
const SizedBox(height: 8),
TextField(
controller: codigoController,
textCapitalization: TextCapitalization.characters,
decoration: buildDecoration('Ej: DOC-482193'),
),
const SizedBox(height: 14),
const Text(
'Relación con el paciente',
style: TextStyle(
fontSize: 13,
fontWeight: FontWeight.w700,
),
),
const SizedBox(height: 8),
DropdownButtonFormField<CaregiverRelationship>(
value: parentescoSeleccionado,
decoration: buildDecoration('Seleccione una opción'),
items: CaregiverRelationship.values.map((item) {
return DropdownMenuItem<CaregiverRelationship>(
value: item,
child: Text(caregiverRelationshipLabel(item)),
);
}).toList(),
onChanged: (value) {
setState(() {
parentescoSeleccionado = value;
});
},
),
const SizedBox(height: 6),
const Text(
'Después esto se podrá editar si hace falta.',
style: TextStyle(
fontSize: 12,
color: Color(0xFF666666),
),
),
],
),
),
const SizedBox(height: 22),
SizedBox(
width: double.infinity,
child: ElevatedButton(
onPressed: vincularPaciente,
style: ElevatedButton.styleFrom(
backgroundColor: const Color(0xFFE7E7E7),
foregroundColor: Colors.black,
elevation: 0,
padding: const EdgeInsets.symmetric(vertical: 16),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(22),
),
),
child: const Text(
'Vincular paciente',
style: TextStyle(
fontWeight: FontWeight.w700,
),
),
),
),
const SizedBox(height: 12),
SizedBox(
width: double.infinity,
child: TextButton(
onPressed: () {
Navigator.pop(context);
},
child: const Text(
'Volver',
style: TextStyle(
color: Colors.black54,
fontWeight: FontWeight.w700,
),
),
),
),
],
),
),
),
),
);
}
}

class PatientHomePage extends StatefulWidget {
  final AppUser usuario;

  const PatientHomePage({
    super.key,
    required this.usuario,
  });

  @override
  State<PatientHomePage> createState() => _PatientHomePageState();
}

class _PatientHomePageState extends State<PatientHomePage> {
int currentIndex = 0;
Timer? _timerActualizacion;

bool _mostrandoDialogoAlarma = false;
bool _mostrandoDialogoStock = false;

final Set<String> _alarmasYaMostradas = <String>{};
final Set<String> _avisosStockYaMostrados = <String>{};

final List<int> compartimientos = [1, 2, 3];
late Map<int, MedicationData?> medicamentosPorCompartimiento;

@override
void initState() {
super.initState();

medicamentosPorCompartimiento = {
1: null,
2: null,
3: null,
};

_timerActualizacion = Timer.periodic(const Duration(seconds: 1), (_) {
if (!mounted) return;

revisarAvisosDeStock();
revisarAlarmasInternas();

setState(() {});
});
}

@override
void dispose() {
_timerActualizacion?.cancel();
super.dispose();
}

int obtenerSiguienteCompartimientoDisponible() {
int numero = 4;

while (compartimientos.contains(numero)) {
numero++;
}

return numero;
}

void agregarCompartimiento() {
setState(() {
final nuevoNumero = obtenerSiguienteCompartimientoDisponible();
compartimientos.add(nuevoNumero);
compartimientos.sort();
medicamentosPorCompartimiento[nuevoNumero] = null;
_alarmasYaMostradas.clear();
});
}

void eliminarCompartimiento(int numero) {
if (numero <= 3) return;

setState(() {
compartimientos.remove(numero);
medicamentosPorCompartimiento.remove(numero);
limpiarAvisosStockDelCompartimiento(numero);
_alarmasYaMostradas.clear();
});
}

Future<void> abrirFormularioAgregar(int numeroCompartimiento) async {
final resultado = await showModalBottomSheet<MedicationData>(
context: context,
isScrollControlled: true,
backgroundColor: Colors.transparent,
builder: (_) => MedicationFormSheet(
titulo: 'Agregar medicamento',
numeroCompartimiento: numeroCompartimiento,
),
);

if (resultado == null) return;

setState(() {
medicamentosPorCompartimiento[numeroCompartimiento] = resultado;
limpiarAvisosStockDelCompartimiento(numeroCompartimiento);
_alarmasYaMostradas.clear();
});
}

Future<void> abrirFormularioEditar(int numeroCompartimiento) async {
final actual = medicamentosPorCompartimiento[numeroCompartimiento];
if (actual == null) return;

final resultado = await showModalBottomSheet<MedicationData>(
context: context,
isScrollControlled: true,
backgroundColor: Colors.transparent,
builder: (_) => MedicationFormSheet(
titulo: 'Editar medicamento',
numeroCompartimiento: numeroCompartimiento,
initialData: actual,
),
);

if (resultado == null) return;

setState(() {
medicamentosPorCompartimiento[numeroCompartimiento] = resultado;
limpiarAvisosStockDelCompartimiento(numeroCompartimiento);
_alarmasYaMostradas.clear();
});
}

void eliminarMedicamento(int numeroCompartimiento) {
setState(() {
medicamentosPorCompartimiento[numeroCompartimiento] = null;
limpiarAvisosStockDelCompartimiento(numeroCompartimiento);
_alarmasYaMostradas.clear();
});
}

List<MapEntry<int, MedicationData>> obtenerMedicamentosProximaToma() {
final medicamentos = medicamentosPorCompartimiento.entries
.where((entry) {
final medicamento = entry.value;
if (medicamento == null) return false;

return medicamento.pastillasRestantes >= medicamento.cantidadPastillas;
})
.map((entry) => MapEntry(entry.key, entry.value!))
.toList();

if (medicamentos.isEmpty) {
return [];
}

medicamentos.sort(
(a, b) => a.value.proximaDosis.compareTo(b.value.proximaDosis),
);

final DateTime primeraFecha = medicamentos.first.value.proximaDosis;

return medicamentos
.where(
(entry) =>
mismaFechaHoraMinuto(entry.value.proximaDosis, primeraFecha),
)
.toList();
}

DateTime? obtenerFechaProximaToma() {
final medicamentos = obtenerMedicamentosProximaToma();

if (medicamentos.isEmpty) {
return null;
}

return medicamentos.first.value.proximaDosis;
}

bool puedeConfirmarProximaToma() {
final fecha = obtenerFechaProximaToma();
if (fecha == null) return false;

final ahora = DateTime.now();
return !ahora.isBefore(fecha);
}

bool hayPastillasSuficientesParaProximaToma() {
final proximos = obtenerMedicamentosProximaToma();
if (proximos.isEmpty) return false;

for (final entry in proximos) {
final medicamento = entry.value;
if (medicamento.pastillasRestantes < medicamento.cantidadPastillas) {
return false;
}
}

return true;
}

int obtenerTomasRestantes(MedicationData medicamento) {
if (medicamento.cantidadPastillas <= 0) return 0;
return medicamento.pastillasRestantes ~/ medicamento.cantidadPastillas;
}

String textoTomasRestantes(MedicationData medicamento) {
final tomasRestantes = obtenerTomasRestantes(medicamento);

if (tomasRestantes <= 0) {
return 'Ya no alcanza para otra toma';
}

if (tomasRestantes == 1) {
return 'Queda 1 toma';
}

return 'Quedan $tomasRestantes tomas';
}

bool tieneStockBajo(MedicationData medicamento) {
final tomasRestantes = obtenerTomasRestantes(medicamento);
return tomasRestantes > 0 && tomasRestantes <= 2;
}

bool sinStockParaProximaToma(MedicationData medicamento) {
return medicamento.pastillasRestantes < medicamento.cantidadPastillas;
}

String construirClaveBaseStock(
int numeroCompartimiento,
MedicationData medicamento,
) {
return '$numeroCompartimiento|${medicamento.nombre}|${medicamento.totalPastillasCargadas}|${medicamento.primeraDosis.toIso8601String()}';
}

void limpiarAvisosStockDelCompartimiento(int numeroCompartimiento) {
_avisosStockYaMostrados.removeWhere(
(clave) =>
clave.startsWith('bajo|$numeroCompartimiento|') ||
clave.startsWith('agotado|$numeroCompartimiento|'),
);
}

Future<void> mostrarDialogoStock({
required String titulo,
required String mensaje,
}) async {
if (!mounted) return;

_mostrandoDialogoStock = true;

await showDialog(
context: context,
barrierDismissible: true,
builder: (dialogContext) {
return AlertDialog(
title: Text(titulo),
content: Text(mensaje),
actions: [
TextButton(
onPressed: () {
Navigator.pop(dialogContext);
},
child: const Text('Entendido'),
),
],
);
},
);

_mostrandoDialogoStock = false;
}

Future<void> revisarAvisosDeStock() async {
if (!mounted) return;
if (_mostrandoDialogoStock || _mostrandoDialogoAlarma) return;

final entries = medicamentosPorCompartimiento.entries
.where((entry) => entry.value != null)
.map((entry) => MapEntry(entry.key, entry.value!))
.toList();

entries.sort((a, b) => a.key.compareTo(b.key));

for (final entry in entries) {
final numeroCompartimiento = entry.key;
final medicamento = entry.value;
final base = construirClaveBaseStock(numeroCompartimiento, medicamento);

final claveAgotado = 'agotado|$base';
if (sinStockParaProximaToma(medicamento) &&
!_avisosStockYaMostrados.contains(claveAgotado)) {
_avisosStockYaMostrados.add(claveAgotado);

await mostrarDialogoStock(
titulo: 'Pastillas agotadas',
mensaje:
'El medicamento ${medicamento.nombre} del compartimiento $numeroCompartimiento ya no tiene suficientes pastillas para la próxima toma. Revise y vuelva a llenar el pastillero.',
);
return;
}
}

for (final entry in entries) {
final numeroCompartimiento = entry.key;
final medicamento = entry.value;
final base = construirClaveBaseStock(numeroCompartimiento, medicamento);

final claveBajo = 'bajo|$base';
if (tieneStockBajo(medicamento) &&
!_avisosStockYaMostrados.contains(claveBajo)) {
_avisosStockYaMostrados.add(claveBajo);

await mostrarDialogoStock(
titulo: 'Quedan pocas pastillas',
mensaje:
'Al medicamento ${medicamento.nombre} del compartimiento $numeroCompartimiento ${textoTomasRestantes(medicamento).toLowerCase()}. Sería bueno volver a llenar el pastillero pronto.',
);
return;
}
}
}

String construirClaveAlarma(List<MapEntry<int, MedicationData>> medicamentos) {
final fecha = medicamentos.first.value.proximaDosis.toIso8601String();
final compartimientos = medicamentos.map((e) => e.key).join('-');
return '$fecha|$compartimientos';
}

Future<void> revisarAlarmasInternas() async {
if (!mounted || _mostrandoDialogoAlarma || _mostrandoDialogoStock) return;

final proximos = obtenerMedicamentosProximaToma();

if (proximos.isEmpty) return;
if (!puedeConfirmarProximaToma()) return;
if (!hayPastillasSuficientesParaProximaToma()) return;

final clave = construirClaveAlarma(proximos);

if (_alarmasYaMostradas.contains(clave)) return;

_alarmasYaMostradas.add(clave);
_mostrandoDialogoAlarma = true;

await showDialog(
context: context,
barrierDismissible: true,
builder: (dialogContext) {
return AlertDialog(
title: const Text('Hora de su medicamento'),
content: Column(
mainAxisSize: MainAxisSize.min,
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
'Ya puede confirmar la toma programada para las ${formatearHora(proximos.first.value.proximaDosis)}.',
),
const SizedBox(height: 14),
...proximos.map(
(entry) => Padding(
padding: const EdgeInsets.only(bottom: 8),
child: Text(
'• Compartimiento ${entry.key}: ${entry.value.nombre} (${entry.value.cantidadTexto})',
),
),
),
],
),
actions: [
TextButton(
onPressed: () {
Navigator.pop(dialogContext);
},
child: const Text('Cerrar'),
),
ElevatedButton(
onPressed: () {
Navigator.pop(dialogContext);
confirmarProximaToma();
},
child: const Text('Confirmar toma'),
),
],
);
},
);

_mostrandoDialogoAlarma = false;
}

Future<void> confirmarProximaToma() async {
  if (!puedeConfirmarProximaToma()) return;
  if (!hayPastillasSuficientesParaProximaToma()) return;

  final proximos = obtenerMedicamentosProximaToma();

  if (proximos.isEmpty) return;

  setState(() {
    for (final entry in proximos) {
      final medicamento = entry.value;

      final nuevasRestantes =
          medicamento.pastillasRestantes - medicamento.cantidadPastillas;

      medicamentosPorCompartimiento[entry.key] = medicamento.copyWith(
        pastillasRestantes: nuevasRestantes < 0 ? 0 : nuevasRestantes,
        proximaDosis: medicamento.proximaDosis.add(
          Duration(hours: medicamento.frecuenciaHoras),
        ),
      );
    }
  });

  try {
    for (final entry in proximos) {
      final actualizado = medicamentosPorCompartimiento[entry.key];
      if (actualizado != null) {
        await notificarTomaConfirmadaAlESP32(
          compartimiento: entry.key,
          medicamento: actualizado,
        );
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          proximos.length == 1 ? 'Toma confirmada' : 'Tomas confirmadas',
        ),
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('La toma se confirmó en la app, pero falló el aviso al ESP32: $e'),
      ),
    );
  }

  WidgetsBinding.instance.addPostFrameCallback((_) {
    revisarAvisosDeStock();
  });
}

Widget buildContenido() {
  switch (currentIndex) {
    case 0:
      return PatientDashboardContent(
        nombrePaciente: widget.usuario.nombre,
        compartimientos: compartimientos,
        medicamentosPorCompartimiento: medicamentosPorCompartimiento,
        onAgregarCompartimiento: agregarCompartimiento,
        onEliminarCompartimiento: eliminarCompartimiento,
        medicamentosProximaToma:
            obtenerMedicamentosProximaToma().map((e) => e.value).toList(),
        fechaProximaToma: obtenerFechaProximaToma(),
        puedeConfirmarToma:
            puedeConfirmarProximaToma() &&
            hayPastillasSuficientesParaProximaToma(),
        onConfirmarProximaToma: confirmarProximaToma,
      );
case 1:
return PatientMedicationsPage(
compartimientos: compartimientos,
medicamentosPorCompartimiento: medicamentosPorCompartimiento,
onAgregarEnCompartimiento: abrirFormularioAgregar,
onEditarEnCompartimiento: abrirFormularioEditar,
onEliminarMedicamento: eliminarMedicamento,
);
case 2:
return CalendarPage(
medicamentosPorCompartimiento: medicamentosPorCompartimiento,
);
case 3:
return AlertsPage(
medicamentosPorCompartimiento: medicamentosPorCompartimiento,
onConfirmarProximaToma: confirmarProximaToma,
puedeConfirmarToma:
puedeConfirmarProximaToma() &&
hayPastillasSuficientesParaProximaToma(),
);
default:
return const SizedBox.shrink();
}
}

@override
Widget build(BuildContext context) {
return Scaffold(
body: SafeArea(
child: PhoneFrame(
child: Column(
children: [
Expanded(
child: buildContenido(),
),
PatientBottomNavigationBar(
currentIndex: currentIndex,
onTap: (index) {
setState(() {
currentIndex = index;
});
},
),
],
),
),
),
);
}
}

class PatientBottomNavigationBar extends StatelessWidget {
final int currentIndex;
final ValueChanged<int> onTap;

const PatientBottomNavigationBar({
super.key,
required this.currentIndex,
required this.onTap,
});

@override
Widget build(BuildContext context) {
const items = [
_BottomNavItemData(
icon: Icons.home_outlined,
activeIcon: Icons.home,
label: 'Inicio',
),
_BottomNavItemData(
icon: Icons.medication_outlined,
activeIcon: Icons.medication,
label: 'Medicamentos',
),
_BottomNavItemData(
icon: Icons.calendar_month_outlined,
activeIcon: Icons.calendar_month,
label: 'Calendario',
),
_BottomNavItemData(
icon: Icons.notifications_none,
activeIcon: Icons.notifications,
label: 'Alertas',
),
];

return Container(
padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
decoration: const BoxDecoration(
color: Color(0xFFE7E7E7),
border: Border(
top: BorderSide(
color: Color(0xFFD3D3D3),
width: 1,
),
),
),
child: Row(
children: List.generate(items.length, (index) {
final item = items[index];
final bool activo = currentIndex == index;

return Expanded(
child: InkWell(
borderRadius: BorderRadius.circular(22),
onTap: () => onTap(index),
child: AnimatedContainer(
duration: const Duration(milliseconds: 180),
padding: const EdgeInsets.symmetric(
vertical: 10,
horizontal: 6,
),
decoration: BoxDecoration(
color: activo
? const Color(0xFFDCDCDC)
: Colors.transparent,
borderRadius: BorderRadius.circular(22),
),
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
Icon(
activo ? item.activeIcon : item.icon,
size: 22,
color: Colors.black,
),
const SizedBox(height: 4),
Text(
item.label,
maxLines: 1,
overflow: TextOverflow.ellipsis,
style: TextStyle(
fontSize: 10,
fontWeight:
activo ? FontWeight.w700 : FontWeight.w500,
color: Colors.black,
),
),
],
),
),
),
);
}),
),
);
}
}

class _BottomNavItemData {
final IconData icon;
final IconData activeIcon;
final String label;

const _BottomNavItemData({
required this.icon,
required this.activeIcon,
required this.label,
});
}

class PatientDashboardContent extends StatelessWidget {
  final String nombrePaciente;
  final List<int> compartimientos;
  final Map<int, MedicationData?> medicamentosPorCompartimiento;
  final VoidCallback onAgregarCompartimiento;
  final Function(int) onEliminarCompartimiento;
  final List<MedicationData> medicamentosProximaToma;
  final DateTime? fechaProximaToma;
  final bool puedeConfirmarToma;
  final VoidCallback onConfirmarProximaToma;

  const PatientDashboardContent({
    super.key,
    required this.nombrePaciente,
    required this.compartimientos,
    required this.medicamentosPorCompartimiento,
    required this.onAgregarCompartimiento,
    required this.onEliminarCompartimiento,
    required this.medicamentosProximaToma,
    required this.fechaProximaToma,
    required this.puedeConfirmarToma,
    required this.onConfirmarProximaToma,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TopGreeting(
            saludo: 'Buenos días,',
            nombre: nombrePaciente,
          ),
          const SizedBox(height: 22),
          NextDoseCard(
            medicamentos: medicamentosProximaToma,
            fechaProximaToma: fechaProximaToma,
            puedeConfirmarToma: puedeConfirmarToma,
            onConfirmarToma: onConfirmarProximaToma,
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'COMPARTIMIENTOS',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333333),
                ),
              ),
              TextButton.icon(
                onPressed: onAgregarCompartimiento,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Agregar'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            itemCount: compartimientos.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.08,
            ),
            itemBuilder: (context, index) {
              final numero = compartimientos[index];
              final medicamento = medicamentosPorCompartimiento[numero];

              return CompartmentCard(
                numero: numero,
                medicamento: medicamento,
                sePuedeEliminar: numero > 3,
                onDelete: () => onEliminarCompartimiento(numero),
              );
            },
          ),
        ],
      ),
    );
  }
}

class PatientMedicationsPage extends StatelessWidget {
final List<int> compartimientos;
final Map<int, MedicationData?> medicamentosPorCompartimiento;
final ValueChanged<int> onAgregarEnCompartimiento;
final ValueChanged<int> onEditarEnCompartimiento;
final ValueChanged<int> onEliminarMedicamento;

const PatientMedicationsPage({
super.key,
required this.compartimientos,
required this.medicamentosPorCompartimiento,
required this.onAgregarEnCompartimiento,
required this.onEditarEnCompartimiento,
required this.onEliminarMedicamento,
});

@override
Widget build(BuildContext context) {
return SingleChildScrollView(
padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text(
'Mis\nMedicamentos',
style: TextStyle(
fontSize: 30,
height: 1.0,
fontWeight: FontWeight.w800,
),
),
const SizedBox(height: 14),
const Text(
'Cada compartimiento puede tener un solo medicamento asignado.',
style: TextStyle(
fontSize: 15,
height: 1.2,
color: Color(0xFF2A2A2A),
),
),
const SizedBox(height: 20),
...compartimientos.map((numero) {
final medicamento = medicamentosPorCompartimiento[numero];
return Padding(
padding: const EdgeInsets.only(bottom: 14),
child: MedicationSlotCard(
numeroCompartimiento: numero,
medicamento: medicamento,
onPrimaryAction: () {
if (medicamento == null) {
onAgregarEnCompartimiento(numero);
} else {
onEditarEnCompartimiento(numero);
}
},
onDelete: medicamento == null
? null
: () => onEliminarMedicamento(numero),
),
);
}),
],
),
);
}
}

class TopGreeting extends StatelessWidget {
final String saludo;
final String nombre;

const TopGreeting({
super.key,
required this.saludo,
required this.nombre,
});

@override
Widget build(BuildContext context) {
return Row(
children: [
Expanded(
child: RichText(
text: TextSpan(
style: const TextStyle(color: Colors.black),
children: [
TextSpan(
text: '$saludo\n',
style: const TextStyle(
fontSize: 14,
fontWeight: FontWeight.w400,
),
),
TextSpan(
text: nombre,
style: const TextStyle(
fontSize: 30,
fontWeight: FontWeight.w800,
height: 1.1,
),
),
],
),
),
),
Container(
width: 48,
height: 48,
decoration: const BoxDecoration(
color: Color(0xFFD3D3D3),
shape: BoxShape.circle,
),
),
],
);
}
}

class NextDoseCard extends StatelessWidget {
final List<MedicationData> medicamentos;
final DateTime? fechaProximaToma;
final bool puedeConfirmarToma;
final VoidCallback onConfirmarToma;

const NextDoseCard({
super.key,
required this.medicamentos,
required this.fechaProximaToma,
required this.puedeConfirmarToma,
required this.onConfirmarToma,
});

@override
Widget build(BuildContext context) {
final bool hayMedicamentos =
medicamentos.isNotEmpty && fechaProximaToma != null;

return Container(
width: double.infinity,
padding: const EdgeInsets.all(18),
decoration: BoxDecoration(
color: const Color(0xFFF6F6F6),
borderRadius: BorderRadius.circular(28),
boxShadow: [
BoxShadow(
color: Colors.black.withValues(alpha: 0.06),
blurRadius: 22,
offset: const Offset(0, 10),
),
],
),
child: !hayMedicamentos
? Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text(
'PRÓXIMA TOMA',
style: TextStyle(
fontSize: 12,
letterSpacing: 0.7,
fontWeight: FontWeight.w600,
color: Color(0xFF444444),
),
),
const SizedBox(height: 12),
const Text(
'Sin medicamentos',
style: TextStyle(
fontSize: 26,
height: 1.0,
fontWeight: FontWeight.w800,
),
),
const SizedBox(height: 10),
const Text(
'Agregue un medicamento para empezar a programar sus tomas.',
style: TextStyle(
fontSize: 14,
height: 1.2,
color: Color(0xFF444444),
),
),
const SizedBox(height: 16),
SizedBox(
width: 170,
child: ElevatedButton(
onPressed: null,
style: ElevatedButton.styleFrom(
backgroundColor: const Color(0xFFE3E3E3),
foregroundColor: Colors.black,
disabledBackgroundColor: const Color(0xFFE3E3E3),
disabledForegroundColor: Colors.black45,
elevation: 0,
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(20),
),
padding: const EdgeInsets.symmetric(vertical: 12),
),
child: const Text('Confirmar toma'),
),
),
],
)
: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text(
'PRÓXIMA TOMA',
style: TextStyle(
fontSize: 12,
letterSpacing: 0.7,
fontWeight: FontWeight.w600,
color: Color(0xFF444444),
),
),
const SizedBox(height: 10),
Text(
formatearHora(fechaProximaToma!),
style: const TextStyle(
fontSize: 34,
height: 1.0,
fontWeight: FontWeight.w800,
),
),
const SizedBox(height: 6),
Text(
etiquetaFecha(fechaProximaToma!),
style: const TextStyle(
fontSize: 14,
fontWeight: FontWeight.w600,
color: Color(0xFF444444),
),
),
const SizedBox(height: 16),
...medicamentos.map(
(medicamento) => Padding(
padding: const EdgeInsets.only(bottom: 10),
child: Container(
width: double.infinity,
padding: const EdgeInsets.all(14),
decoration: BoxDecoration(
color: const Color(0xFFEAEAEA),
borderRadius: BorderRadius.circular(20),
),
child: Row(
children: [
const Icon(
Icons.medication_outlined,
color: Colors.black87,
),
const SizedBox(width: 12),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
medicamento.nombre,
style: const TextStyle(
fontSize: 16,
fontWeight: FontWeight.w800,
),
),
const SizedBox(height: 3),
Text(
'${medicamento.cantidadTexto} • ${medicamento.restantesTexto}',
style: const TextStyle(
fontSize: 13,
color: Color(0xFF444444),
),
),
],
),
),
],
),
),
),
),
const SizedBox(height: 8),
if (!puedeConfirmarToma)
Padding(
padding: const EdgeInsets.only(bottom: 10),
child: Text(
'Disponible a las ${formatearHora(fechaProximaToma!)}',
style: const TextStyle(
fontSize: 13,
color: Color(0xFF666666),
),
),
),
SizedBox(
width: 170,
child: ElevatedButton(
onPressed: puedeConfirmarToma ? onConfirmarToma : null,
style: ElevatedButton.styleFrom(
backgroundColor: const Color(0xFFE3E3E3),
foregroundColor: Colors.black,
disabledBackgroundColor: const Color(0xFFE3E3E3),
disabledForegroundColor: Colors.black45,
elevation: 0,
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(20),
),
padding: const EdgeInsets.symmetric(vertical: 12),
),
child: Text(
medicamentos.length == 1
? 'Confirmar toma'
: 'Confirmar tomas',
),
),
),
],
),
);
}
}

class CompartmentCard extends StatelessWidget {
final int numero;
final MedicationData? medicamento;
final bool sePuedeEliminar;
final VoidCallback? onDelete;

const CompartmentCard({
super.key,
required this.numero,
required this.medicamento,
required this.sePuedeEliminar,
this.onDelete,
});

@override
Widget build(BuildContext context) {
return Stack(
children: [
Container(
width: double.infinity,
height: double.infinity,
padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
decoration: BoxDecoration(
color: const Color(0xFFF6F6F6),
borderRadius: BorderRadius.circular(24),
boxShadow: [
BoxShadow(
color: Colors.black.withValues(alpha: 0.06),
blurRadius: 22,
offset: const Offset(0, 10),
),
],
),
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
const Text(
'Compartimiento',
style: TextStyle(
fontSize: 12,
color: Color(0xFF444444),
),
),
const SizedBox(height: 6),
Text(
'$numero',
style: const TextStyle(
fontSize: 30,
fontWeight: FontWeight.w800,
),
),
const SizedBox(height: 8),
Text(
medicamento?.nombre ?? 'Vacío',
textAlign: TextAlign.center,
style: TextStyle(
fontSize: 12,
fontWeight: FontWeight.w600,
color: medicamento == null
? Colors.black45
: const Color(0xFF222222),
),
),
],
),
),
if (sePuedeEliminar)
Positioned(
top: 8,
right: 8,
child: GestureDetector(
onTap: onDelete,
child: Container(
width: 28,
height: 28,
decoration: const BoxDecoration(
color: Color(0xFF111111),
shape: BoxShape.circle,
),
child: const Icon(
Icons.close,
size: 16,
color: Colors.white,
),
),
),
),
],
);
}
}

class MedicationSlotCard extends StatelessWidget {
final int numeroCompartimiento;
final MedicationData? medicamento;
final VoidCallback onPrimaryAction;
final VoidCallback? onDelete;

const MedicationSlotCard({
super.key,
required this.numeroCompartimiento,
required this.medicamento,
required this.onPrimaryAction,
this.onDelete,
});

@override
Widget build(BuildContext context) {
final ocupado = medicamento != null;

return Container(
width: double.infinity,
padding: const EdgeInsets.all(18),
decoration: BoxDecoration(
color: const Color(0xFFF6F6F6),
borderRadius: BorderRadius.circular(26),
boxShadow: [
BoxShadow(
color: Colors.black.withValues(alpha: 0.06),
blurRadius: 22,
offset: const Offset(0, 10),
),
],
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
'Compartimiento $numeroCompartimiento',
style: const TextStyle(
fontSize: 13,
fontWeight: FontWeight.w700,
color: Color(0xFF333333),
),
),
const SizedBox(height: 10),
Text(
ocupado ? medicamento!.nombre : 'Sin medicamento asignado',
style: const TextStyle(
fontSize: 22,
height: 1.05,
fontWeight: FontWeight.w800,
),
),
const SizedBox(height: 8),
Text(
ocupado
? '${medicamento!.cantidadTexto} • ${medicamento!.frecuenciaTexto}'
: 'Este compartimiento está disponible para agregar un medicamento.',
style: const TextStyle(
fontSize: 14,
height: 1.2,
color: Color(0xFF444444),
),
),
if (ocupado) ...[
const SizedBox(height: 8),
Text(
medicamento!.restantesTexto,
style: const TextStyle(
fontSize: 13,
color: Color(0xFF555555),
fontWeight: FontWeight.w600,
),
),
const SizedBox(height: 8),
Text(
'Hora base: ${formatearHora(medicamento!.primeraDosis)}',
style: const TextStyle(
fontSize: 13,
color: Color(0xFF555555),
),
),
const SizedBox(height: 4),
Text(
'Próxima toma: ${formatearFechaHoraCorta(medicamento!.proximaDosis)}',
style: const TextStyle(
fontSize: 13,
height: 1.2,
color: Color(0xFF555555),
),
),
],
const SizedBox(height: 14),
Row(
children: [
Container(
padding: const EdgeInsets.symmetric(
horizontal: 14,
vertical: 8,
),
decoration: BoxDecoration(
color: ocupado
? const Color(0xFFE3E3E3)
: const Color(0xFFF0F0F0),
borderRadius: BorderRadius.circular(18),
),
child: Text(
ocupado ? 'Asignado' : 'Disponible',
style: TextStyle(
fontSize: 12,
fontWeight: FontWeight.w600,
color: ocupado ? Colors.black : Colors.black54,
),
),
),
const Spacer(),
if (ocupado)
TextButton(
onPressed: onDelete,
child: const Text(
'Quitar',
style: TextStyle(
color: Colors.black54,
fontWeight: FontWeight.w700,
),
),
),
TextButton(
onPressed: onPrimaryAction,
child: Text(
ocupado ? 'Editar' : 'Agregar',
style: const TextStyle(
color: Colors.black,
fontWeight: FontWeight.w700,
),
),
),
],
),
],
),
);
}
}

class MedicationFormSheet extends StatefulWidget {
final String titulo;
final int numeroCompartimiento;
final MedicationData? initialData;

const MedicationFormSheet({
super.key,
required this.titulo,
required this.numeroCompartimiento,
this.initialData,
});

@override
State<MedicationFormSheet> createState() => _MedicationFormSheetState();
}

class _MedicationFormSheetState extends State<MedicationFormSheet> {
static const List<int> frecuencias = [4, 6, 8, 12, 24, 48];

late final TextEditingController nombreController;
late final TextEditingController horaController;
late final TextEditingController totalPastillasController;
late int cantidadSeleccionada;
late int frecuenciaSeleccionada;

@override
void initState() {
super.initState();
nombreController = TextEditingController(
text: widget.initialData?.nombre ?? '',
);
horaController = TextEditingController(
text: formatearHora(
widget.initialData?.primeraDosis ?? redondearAlMinuto(DateTime.now()),
),
);
totalPastillasController = TextEditingController(
text: widget.initialData?.pastillasRestantes.toString() ?? '',
);
cantidadSeleccionada = widget.initialData?.cantidadPastillas ?? 1;
frecuenciaSeleccionada = widget.initialData?.frecuenciaHoras ?? 4;
}

@override
void dispose() {
nombreController.dispose();
horaController.dispose();
totalPastillasController.dispose();
super.dispose();
}

InputDecoration buildDecoration(String hintText) {
return InputDecoration(
hintText: hintText,
filled: true,
fillColor: Colors.white,
contentPadding: const EdgeInsets.symmetric(
horizontal: 16,
vertical: 16,
),
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(18),
borderSide: const BorderSide(
color: Color(0xFFE0E0E0),
),
),
enabledBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(18),
borderSide: const BorderSide(
color: Color(0xFFE0E0E0),
),
),
focusedBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(18),
borderSide: const BorderSide(
color: Colors.black,
),
),
);
}

Future<void> guardar() async {
  final nombre = nombreController.text.trim();
  final textoHora = horaController.text.trim();
  final textoTotalPastillas = totalPastillasController.text.trim();

  final TimeOfDay? horaBase = parsearHoraManual(textoHora);
  final int? totalPastillas = int.tryParse(textoTotalPastillas);

  if (nombre.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Escriba el nombre del medicamento.'),
      ),
    );
    return;
  }

  if (horaBase == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Escriba la hora con formato como 6:30 PM.'),
      ),
    );
    return;
  }

  if (totalPastillas == null || totalPastillas <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Escriba cuántas pastillas va a meter en total.'),
      ),
    );
    return;
  }

  if (totalPastillas < cantidadSeleccionada) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Las pastillas cargadas no pueden ser menores que las pastillas por toma.',
        ),
      ),
    );
    return;
  }

  final DateTime hoy = DateUtils.dateOnly(DateTime.now());
  final DateTime primeraDosis = combinarFechaYHora(hoy, horaBase);
  final DateTime proximaDosis = calcularProximaDosisDesdeHoraBase(
    horaBase: horaBase,
    frecuenciaHoras: frecuenciaSeleccionada,
  );

  final medicamento = MedicationData(
    nombre: nombre,
    cantidadPastillas: cantidadSeleccionada,
    frecuenciaHoras: frecuenciaSeleccionada,
    totalPastillasCargadas: totalPastillas,
    pastillasRestantes: totalPastillas,
    primeraDosis: primeraDosis,
    proximaDosis: proximaDosis,
  );

  try {
    await enviarMedicamentoAlESP32(
      compartimiento: widget.numeroCompartimiento,
      medicamento: medicamento,
    );

    if (!mounted) return;
    Navigator.pop(context, medicamento);
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('No se pudo enviar al ESP32: $e'),
      ),
    );
  }
}

@override
Widget build(BuildContext context) {
return Padding(
padding: EdgeInsets.fromLTRB(
16,
16,
16,
MediaQuery.of(context).viewInsets.bottom + 16,
),
child: Container(
padding: const EdgeInsets.all(20),
decoration: BoxDecoration(
color: const Color(0xFFF8F8F8),
borderRadius: BorderRadius.circular(28),
),
child: SingleChildScrollView(
child: Column(
mainAxisSize: MainAxisSize.min,
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
widget.titulo,
style: const TextStyle(
fontSize: 24,
fontWeight: FontWeight.w800,
),
),
const SizedBox(height: 6),
Text(
'Compartimiento ${widget.numeroCompartimiento}',
style: const TextStyle(
fontSize: 14,
color: Color(0xFF555555),
),
),
const SizedBox(height: 20),
const Text(
'Nombre del medicamento',
style: TextStyle(
fontSize: 13,
fontWeight: FontWeight.w700,
),
),
const SizedBox(height: 8),
TextField(
controller: nombreController,
decoration: buildDecoration('Ej: Acetaminofén'),
),
const SizedBox(height: 14),
const Text(
'Pastillas por toma',
style: TextStyle(
fontSize: 13,
fontWeight: FontWeight.w700,
),
),
const SizedBox(height: 8),
DropdownButtonFormField<int>(
value: cantidadSeleccionada,
decoration: buildDecoration('Seleccione una cantidad'),
items: List.generate(5, (index) => index + 1)
.map(
(cantidad) => DropdownMenuItem<int>(
value: cantidad,
child: Text(
cantidad == 1
? '1 pastilla'
: '$cantidad pastillas',
),
),
)
.toList(),
onChanged: (value) {
if (value == null) return;
setState(() {
cantidadSeleccionada = value;
});
},
),
const SizedBox(height: 14),
const Text(
'Frecuencia de la toma',
style: TextStyle(
fontSize: 13,
fontWeight: FontWeight.w700,
),
),
const SizedBox(height: 8),
DropdownButtonFormField<int>(
value: frecuenciaSeleccionada,
decoration: buildDecoration('Seleccione una frecuencia'),
items: frecuencias
.map(
(frecuencia) => DropdownMenuItem<int>(
value: frecuencia,
child: Text('Cada $frecuencia horas'),
),
)
.toList(),
onChanged: (value) {
if (value == null) return;
setState(() {
frecuenciaSeleccionada = value;
});
},
),
const SizedBox(height: 14),
const Text(
'Pastillas cargadas en el compartimiento',
style: TextStyle(
fontSize: 13,
fontWeight: FontWeight.w700,
),
),
const SizedBox(height: 8),
TextField(
controller: totalPastillasController,
keyboardType: TextInputType.number,
decoration: buildDecoration('Ej: 12'),
),
const SizedBox(height: 6),
const Text(
'Escriba cuántas pastillas va a meter en total.',
style: TextStyle(
fontSize: 12,
color: Color(0xFF666666),
),
),
const SizedBox(height: 14),
const Text(
'Hora base de la primera toma',
style: TextStyle(
fontSize: 13,
fontWeight: FontWeight.w700,
),
),
const SizedBox(height: 8),
TextField(
controller: horaController,
keyboardType: TextInputType.datetime,
decoration: buildDecoration('Ej: 6:30 PM'),
),
const SizedBox(height: 6),
const Text(
'Escriba la hora así: 6:30 PM',
style: TextStyle(
fontSize: 12,
color: Color(0xFF666666),
),
),
const SizedBox(height: 22),
SizedBox(
width: double.infinity,
child: ElevatedButton(
onPressed: guardar,
style: ElevatedButton.styleFrom(
backgroundColor: const Color(0xFFE7E7E7),
foregroundColor: Colors.black,
elevation: 0,
padding: const EdgeInsets.symmetric(vertical: 16),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(22),
),
),
child: const Text(
'Guardar medicamento',
style: TextStyle(
fontWeight: FontWeight.w700,
),
),
),
),
],
),
),
),
);
}
}

class CalendarPage extends StatefulWidget {
final Map<int, MedicationData?> medicamentosPorCompartimiento;

const CalendarPage({
super.key,
required this.medicamentosPorCompartimiento,
});

@override
State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
late DateTime fechaSeleccionada;
late DateTime mesVisible;

@override
void initState() {
super.initState();
final hoy = DateUtils.dateOnly(DateTime.now());
fechaSeleccionada = hoy;
mesVisible = DateTime(hoy.year, hoy.month, 1);
}

bool mismaFecha(DateTime a, DateTime b) {
return a.year == b.year && a.month == b.month && a.day == b.day;
}

String nombreMes(int mes) {
const meses = [
'Enero',
'Febrero',
'Marzo',
'Abril',
'Mayo',
'Junio',
'Julio',
'Agosto',
'Septiembre',
'Octubre',
'Noviembre',
'Diciembre',
];
return meses[mes - 1];
}

void cambiarMes(int delta) {
setState(() {
mesVisible = DateTime(mesVisible.year, mesVisible.month + delta, 1);

if (fechaSeleccionada.year != mesVisible.year ||
fechaSeleccionada.month != mesVisible.month) {
fechaSeleccionada = DateTime(mesVisible.year, mesVisible.month, 1);
}
});
}

int obtenerDosisConfirmadas(MedicationData medicamento) {
final usadas =
medicamento.totalPastillasCargadas - medicamento.pastillasRestantes;

if (usadas <= 0) return 0;

return usadas ~/ medicamento.cantidadPastillas;
}

int obtenerDosisPendientes(MedicationData medicamento) {
if (medicamento.cantidadPastillas <= 0) return 0;

final pendientes =
medicamento.pastillasRestantes ~/ medicamento.cantidadPastillas;

return pendientes < 0 ? 0 : pendientes;
}

List<_CalendarDoseEvent> obtenerEventosParaFecha(DateTime fecha) {
final inicioDia = DateUtils.dateOnly(fecha);
final finDia = inicioDia.add(const Duration(days: 1));

final eventos = <_CalendarDoseEvent>[];

widget.medicamentosPorCompartimiento.forEach((
numeroCompartimiento,
medicamento,
) {
if (medicamento == null) return;

final int dosisConfirmadas = obtenerDosisConfirmadas(medicamento);
final int dosisPendientes = obtenerDosisPendientes(medicamento);

for (int i = 0; i < dosisConfirmadas; i++) {
final toma = medicamento.primeraDosis.add(
Duration(hours: medicamento.frecuenciaHoras * i),
);

if (!toma.isBefore(inicioDia) && toma.isBefore(finDia)) {
eventos.add(
_CalendarDoseEvent(
numeroCompartimiento: numeroCompartimiento,
fechaHora: toma,
medicamento: medicamento,
confirmada: true,
),
);
}
}

for (int i = 0; i < dosisPendientes; i++) {
final toma = medicamento.proximaDosis.add(
Duration(hours: medicamento.frecuenciaHoras * i),
);

if (!toma.isBefore(inicioDia) && toma.isBefore(finDia)) {
eventos.add(
_CalendarDoseEvent(
numeroCompartimiento: numeroCompartimiento,
fechaHora: toma,
medicamento: medicamento,
confirmada: false,
),
);
}
}
});

eventos.sort((a, b) => a.fechaHora.compareTo(b.fechaHora));
return eventos;
}

bool fechaTieneEventos(DateTime fecha) {
return obtenerEventosParaFecha(fecha).isNotEmpty;
}

MapEntry<int, MedicationData>? obtenerSiguienteMedicamento() {
final lista = widget.medicamentosPorCompartimiento.entries
.where((entry) {
final medicamento = entry.value;
if (medicamento == null) return false;

return medicamento.pastillasRestantes >= medicamento.cantidadPastillas;
})
.map((entry) => MapEntry(entry.key, entry.value!))
.toList();

if (lista.isEmpty) return null;

lista.sort((a, b) => a.value.proximaDosis.compareTo(b.value.proximaDosis));
return lista.first;
}

@override
Widget build(BuildContext context) {
final eventosDelDia = obtenerEventosParaFecha(fechaSeleccionada);
final siguiente = obtenerSiguienteMedicamento();

return SingleChildScrollView(
padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text(
'Calendario',
style: TextStyle(
fontSize: 30,
height: 1.0,
fontWeight: FontWeight.w800,
),
),
const SizedBox(height: 14),
const Text(
'Aquí verá el historial confirmado y las tomas que aún quedan pendientes.',
style: TextStyle(
fontSize: 15,
height: 1.2,
color: Color(0xFF2A2A2A),
),
),
const SizedBox(height: 22),
Container(
width: double.infinity,
padding: const EdgeInsets.all(18),
decoration: BoxDecoration(
color: const Color(0xFFF6F6F6),
borderRadius: BorderRadius.circular(28),
boxShadow: [
BoxShadow(
color: Colors.black.withValues(alpha: 0.06),
blurRadius: 22,
offset: const Offset(0, 10),
),
],
),
child: siguiente == null
? const Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
'PRÓXIMA TOMA',
style: TextStyle(
fontSize: 12,
letterSpacing: 0.7,
fontWeight: FontWeight.w600,
color: Color(0xFF444444),
),
),
SizedBox(height: 12),
Text(
'Sin tomas pendientes',
style: TextStyle(
fontSize: 26,
height: 1.0,
fontWeight: FontWeight.w800,
),
),
],
)
: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text(
'PRÓXIMA TOMA',
style: TextStyle(
fontSize: 12,
letterSpacing: 0.7,
fontWeight: FontWeight.w600,
color: Color(0xFF444444),
),
),
const SizedBox(height: 10),
Text(
formatearHora(siguiente.value.proximaDosis),
style: const TextStyle(
fontSize: 34,
height: 1.0,
fontWeight: FontWeight.w800,
),
),
const SizedBox(height: 6),
Text(
siguiente.value.nombre,
style: const TextStyle(
fontSize: 18,
fontWeight: FontWeight.w700,
),
),
const SizedBox(height: 4),
Text(
'Compartimiento ${siguiente.key} • ${siguiente.value.cantidadTexto}',
style: const TextStyle(
fontSize: 13,
color: Color(0xFF555555),
),
),
],
),
),
const SizedBox(height: 22),
Container(
width: double.infinity,
padding: const EdgeInsets.all(18),
decoration: BoxDecoration(
color: const Color(0xFFF6F6F6),
borderRadius: BorderRadius.circular(28),
boxShadow: [
BoxShadow(
color: Colors.black.withValues(alpha: 0.06),
blurRadius: 22,
offset: const Offset(0, 10),
),
],
),
child: Column(
children: [
Row(
children: [
IconButton(
onPressed: () => cambiarMes(-1),
icon: const Icon(Icons.chevron_left),
),
Expanded(
child: Text(
'${nombreMes(mesVisible.month)} ${mesVisible.year}',
textAlign: TextAlign.center,
style: const TextStyle(
fontSize: 18,
fontWeight: FontWeight.w800,
),
),
),
IconButton(
onPressed: () => cambiarMes(1),
icon: const Icon(Icons.chevron_right),
),
],
),
const SizedBox(height: 10),
const Row(
children: [
Expanded(child: Center(child: Text('Lu'))),
Expanded(child: Center(child: Text('Ma'))),
Expanded(child: Center(child: Text('Mi'))),
Expanded(child: Center(child: Text('Ju'))),
Expanded(child: Center(child: Text('Vi'))),
Expanded(child: Center(child: Text('Sa'))),
Expanded(child: Center(child: Text('Do'))),
],
),
const SizedBox(height: 12),
_CalendarMonthGrid(
mesVisible: mesVisible,
fechaSeleccionada: fechaSeleccionada,
mismaFecha: mismaFecha,
fechaTieneEventos: fechaTieneEventos,
onSeleccionarFecha: (fecha) {
setState(() {
fechaSeleccionada = fecha;
});
},
),
],
),
),
const SizedBox(height: 22),
Text(
'Tomas de ${etiquetaFecha(fechaSeleccionada)}',
style: const TextStyle(
fontSize: 20,
fontWeight: FontWeight.w800,
),
),
const SizedBox(height: 14),
if (eventosDelDia.isEmpty)
Container(
width: double.infinity,
padding: const EdgeInsets.all(18),
decoration: BoxDecoration(
color: const Color(0xFFF6F6F6),
borderRadius: BorderRadius.circular(26),
boxShadow: [
BoxShadow(
color: Colors.black.withValues(alpha: 0.06),
blurRadius: 22,
offset: const Offset(0, 10),
),
],
),
child: const Text(
'No hay tomas confirmadas ni pendientes para este día.',
style: TextStyle(
fontSize: 14,
color: Color(0xFF444444),
),
),
)
else
...eventosDelDia.map(
(evento) => Padding(
padding: const EdgeInsets.only(bottom: 14),
child: Container(
width: double.infinity,
padding: const EdgeInsets.all(18),
decoration: BoxDecoration(
color: const Color(0xFFF6F6F6),
borderRadius: BorderRadius.circular(26),
boxShadow: [
BoxShadow(
color: Colors.black.withValues(alpha: 0.06),
blurRadius: 22,
offset: const Offset(0, 10),
),
],
),
child: Row(
children: [
Container(
width: 76,
padding: const EdgeInsets.symmetric(vertical: 12),
decoration: BoxDecoration(
color: const Color(0xFFE7E7E7),
borderRadius: BorderRadius.circular(18),
),
child: Text(
formatearHora(evento.fechaHora),
textAlign: TextAlign.center,
style: const TextStyle(
fontSize: 13,
fontWeight: FontWeight.w800,
),
),
),
const SizedBox(width: 14),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
evento.medicamento.nombre,
style: const TextStyle(
fontSize: 18,
fontWeight: FontWeight.w800,
),
),
const SizedBox(height: 4),
Text(
'${evento.medicamento.cantidadTexto} • ${evento.medicamento.frecuenciaTexto}',
style: const TextStyle(
fontSize: 13,
color: Color(0xFF555555),
),
),
const SizedBox(height: 4),
Text(
'Compartimiento ${evento.numeroCompartimiento}',
style: const TextStyle(
fontSize: 13,
color: Color(0xFF555555),
),
),
const SizedBox(height: 8),
Container(
padding: const EdgeInsets.symmetric(
horizontal: 12,
vertical: 6,
),
decoration: BoxDecoration(
color: evento.confirmada
? const Color(0xFFE3E3E3)
: const Color(0xFFF0F0F0),
borderRadius: BorderRadius.circular(16),
),
child: Text(
evento.confirmada ? 'Tomada' : 'Pendiente',
style: const TextStyle(
fontSize: 12,
fontWeight: FontWeight.w700,
color: Colors.black87,
),
),
),
],
),
),
],
),
),
),
),
],
),
);
}
}

class _CalendarDoseEvent {
final int numeroCompartimiento;
final DateTime fechaHora;
final MedicationData medicamento;
final bool confirmada;

_CalendarDoseEvent({
required this.numeroCompartimiento,
required this.fechaHora,
required this.medicamento,
required this.confirmada,
});
}

class _CalendarMonthGrid extends StatelessWidget {
final DateTime mesVisible;
final DateTime fechaSeleccionada;
final bool Function(DateTime a, DateTime b) mismaFecha;
final bool Function(DateTime fecha) fechaTieneEventos;
final ValueChanged<DateTime> onSeleccionarFecha;

const _CalendarMonthGrid({
required this.mesVisible,
required this.fechaSeleccionada,
required this.mismaFecha,
required this.fechaTieneEventos,
required this.onSeleccionarFecha,
});

@override
Widget build(BuildContext context) {
final primerDiaMes = DateTime(mesVisible.year, mesVisible.month, 1);
final diasEnMes = DateTime(mesVisible.year, mesVisible.month + 1, 0).day;
final espaciosIniciales = primerDiaMes.weekday - 1;

int totalCeldas = espaciosIniciales + diasEnMes;
if (totalCeldas % 7 != 0) {
totalCeldas += 7 - (totalCeldas % 7);
}

final hoy = DateUtils.dateOnly(DateTime.now());

return GridView.builder(
itemCount: totalCeldas,
shrinkWrap: true,
physics: const NeverScrollableScrollPhysics(),
gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
crossAxisCount: 7,
mainAxisSpacing: 8,
crossAxisSpacing: 8,
childAspectRatio: 0.92,
),
itemBuilder: (context, index) {
if (index < espaciosIniciales || index >= espaciosIniciales + diasEnMes) {
return const SizedBox.shrink();
}

final dia = index - espaciosIniciales + 1;
final fecha = DateTime(mesVisible.year, mesVisible.month, dia);

final seleccionado = mismaFecha(fecha, fechaSeleccionada);
final esHoy = mismaFecha(fecha, hoy);
final tieneEventos = fechaTieneEventos(fecha);

return InkWell(
borderRadius: BorderRadius.circular(16),
onTap: () => onSeleccionarFecha(fecha),
child: Container(
decoration: BoxDecoration(
color: seleccionado
? const Color(0xFF111111)
: esHoy
? const Color(0xFFE3E3E3)
: const Color(0xFFEFEFEF),
borderRadius: BorderRadius.circular(16),
),
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Text(
'$dia',
style: TextStyle(
fontSize: 14,
fontWeight: FontWeight.w700,
color: seleccionado ? Colors.white : Colors.black,
),
),
const SizedBox(height: 4),
if (tieneEventos)
Container(
width: 6,
height: 6,
decoration: BoxDecoration(
color: seleccionado ? Colors.white : Colors.black87,
shape: BoxShape.circle,
),
),
],
),
),
);
},
);
}
}

class AlertsPage extends StatelessWidget {
final Map<int, MedicationData?> medicamentosPorCompartimiento;
final VoidCallback onConfirmarProximaToma;
final bool puedeConfirmarToma;

const AlertsPage({
super.key,
required this.medicamentosPorCompartimiento,
required this.onConfirmarProximaToma,
required this.puedeConfirmarToma,
});

int obtenerTomasRestantes(MedicationData medicamento) {
if (medicamento.cantidadPastillas <= 0) return 0;
return medicamento.pastillasRestantes ~/ medicamento.cantidadPastillas;
}

List<MapEntry<int, MedicationData>> obtenerAlarmasActivas() {
final ahora = DateTime.now();

final lista = medicamentosPorCompartimiento.entries
.where((entry) {
final medicamento = entry.value;
if (medicamento == null) return false;

if (medicamento.pastillasRestantes < medicamento.cantidadPastillas) {
return false;
}

return !ahora.isBefore(medicamento.proximaDosis);
})
.map((entry) => MapEntry(entry.key, entry.value!))
.toList();

lista.sort((a, b) => a.value.proximaDosis.compareTo(b.value.proximaDosis));
return lista;
}

List<MapEntry<int, MedicationData>> obtenerProximasAlarmas() {
final ahora = DateTime.now();

final lista = medicamentosPorCompartimiento.entries
.where((entry) {
final medicamento = entry.value;
if (medicamento == null) return false;

if (medicamento.pastillasRestantes < medicamento.cantidadPastillas) {
return false;
}

return medicamento.proximaDosis.isAfter(ahora);
})
.map((entry) => MapEntry(entry.key, entry.value!))
.toList();

lista.sort((a, b) => a.value.proximaDosis.compareTo(b.value.proximaDosis));
return lista;
}

List<MapEntry<int, MedicationData>> obtenerStockBajo() {
final lista = medicamentosPorCompartimiento.entries
.where((entry) {
final medicamento = entry.value;
if (medicamento == null) return false;

final tomasRestantes = obtenerTomasRestantes(medicamento);
return tomasRestantes > 0 && tomasRestantes <= 2;
})
.map((entry) => MapEntry(entry.key, entry.value!))
.toList();

lista.sort((a, b) => a.key.compareTo(b.key));
return lista;
}

List<MapEntry<int, MedicationData>> obtenerSinStockSuficiente() {
final lista = medicamentosPorCompartimiento.entries
.where((entry) {
final medicamento = entry.value;
if (medicamento == null) return false;

return medicamento.pastillasRestantes < medicamento.cantidadPastillas;
})
.map((entry) => MapEntry(entry.key, entry.value!))
.toList();

lista.sort((a, b) => a.key.compareTo(b.key));
return lista;
}

@override
Widget build(BuildContext context) {
final activas = obtenerAlarmasActivas();
final proximas = obtenerProximasAlarmas();
final stockBajo = obtenerStockBajo();
final sinStock = obtenerSinStockSuficiente();

return SingleChildScrollView(
padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text(
'Alertas',
style: TextStyle(
fontSize: 30,
height: 1.0,
fontWeight: FontWeight.w800,
),
),
const SizedBox(height: 14),
const Text(
'Aquí puede revisar las tomas activas, las próximas alarmas y el estado del stock.',
style: TextStyle(
fontSize: 15,
height: 1.2,
color: Color(0xFF2A2A2A),
),
),
const SizedBox(height: 22),
const Text(
'ALARMAS ACTIVAS AHORA',
style: TextStyle(
fontSize: 12,
letterSpacing: 0.6,
fontWeight: FontWeight.w700,
color: Color(0xFF333333),
),
),
const SizedBox(height: 12),
if (activas.isEmpty)
const _AlertEmptyCard(
texto: 'No hay alarmas activas en este momento.',
)
else ...[
...activas.map(
(entry) => Padding(
padding: const EdgeInsets.only(bottom: 14),
child: _AlertMedicationCard(
titulo: entry.value.nombre,
subtitulo:
'Compartimiento ${entry.key} • ${entry.value.cantidadTexto}',
detalle:
'Programada para ${formatearFechaHoraCorta(entry.value.proximaDosis)}',
estadoTexto: 'Activa ahora',
),
),
),
const SizedBox(height: 4),
SizedBox(
width: double.infinity,
child: ElevatedButton(
onPressed: puedeConfirmarToma ? onConfirmarProximaToma : null,
style: ElevatedButton.styleFrom(
backgroundColor: const Color(0xFFE7E7E7),
foregroundColor: Colors.black,
disabledBackgroundColor: const Color(0xFFE7E7E7),
disabledForegroundColor: Colors.black45,
elevation: 0,
padding: const EdgeInsets.symmetric(vertical: 16),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(22),
),
),
child: const Text(
'Confirmar toma activa',
style: TextStyle(fontWeight: FontWeight.w700),
),
),
),
],
const SizedBox(height: 24),
const Text(
'PRÓXIMAS ALARMAS',
style: TextStyle(
fontSize: 12,
letterSpacing: 0.6,
fontWeight: FontWeight.w700,
color: Color(0xFF333333),
),
),
const SizedBox(height: 12),
if (proximas.isEmpty)
const _AlertEmptyCard(
texto: 'No hay próximas alarmas programadas.',
)
else
...proximas.take(10).map(
(entry) => Padding(
padding: const EdgeInsets.only(bottom: 14),
child: _AlertMedicationCard(
titulo: entry.value.nombre,
subtitulo:
'Compartimiento ${entry.key} • ${entry.value.cantidadTexto}',
detalle:
'Próxima toma: ${formatearFechaHoraCorta(entry.value.proximaDosis)}',
estadoTexto: 'Pendiente',
),
),
),
const SizedBox(height: 24),
const Text(
'STOCK BAJO',
style: TextStyle(
fontSize: 12,
letterSpacing: 0.6,
fontWeight: FontWeight.w700,
color: Color(0xFF333333),
),
),
const SizedBox(height: 12),
if (stockBajo.isEmpty)
const _AlertEmptyCard(
texto: 'No hay medicamentos con stock bajo.',
)
else
...stockBajo.map(
(entry) {
final tomas = obtenerTomasRestantes(entry.value);
return Padding(
padding: const EdgeInsets.only(bottom: 14),
child: _AlertMedicationCard(
titulo: entry.value.nombre,
subtitulo:
'Compartimiento ${entry.key} • ${entry.value.cantidadTexto}',
detalle: tomas == 1
? 'Queda 1 toma disponible. Conviene llenar el pastillero.'
: 'Quedan $tomas tomas disponibles. Conviene llenar el pastillero.',
estadoTexto: 'Stock bajo',
),
);
},
),
const SizedBox(height: 24),
const Text(
'SIN STOCK SUFICIENTE',
style: TextStyle(
fontSize: 12,
letterSpacing: 0.6,
fontWeight: FontWeight.w700,
color: Color(0xFF333333),
),
),
const SizedBox(height: 12),
if (sinStock.isEmpty)
const _AlertEmptyCard(
texto: 'Todos los medicamentos alcanzan para la siguiente toma.',
)
else
...sinStock.map(
(entry) => Padding(
padding: const EdgeInsets.only(bottom: 14),
child: _AlertMedicationCard(
titulo: entry.value.nombre,
subtitulo:
'Compartimiento ${entry.key} • ${entry.value.cantidadTexto}',
detalle:
'Solo quedan ${entry.value.pastillasRestantes} pastillas. No alcanza para la próxima dosis.',
estadoTexto: 'Rellenar',
),
),
),
],
),
);
}
}

class _AlertMedicationCard extends StatelessWidget {
final String titulo;
final String subtitulo;
final String detalle;
final String estadoTexto;

const _AlertMedicationCard({
required this.titulo,
required this.subtitulo,
required this.detalle,
required this.estadoTexto,
});

@override
Widget build(BuildContext context) {
return Container(
width: double.infinity,
padding: const EdgeInsets.all(18),
decoration: BoxDecoration(
color: const Color(0xFFF6F6F6),
borderRadius: BorderRadius.circular(26),
boxShadow: [
BoxShadow(
color: Colors.black.withValues(alpha: 0.06),
blurRadius: 22,
offset: const Offset(0, 10),
),
],
),
child: Row(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Container(
width: 42,
height: 42,
decoration: const BoxDecoration(
color: Color(0xFFE7E7E7),
shape: BoxShape.circle,
),
child: const Icon(Icons.notifications_active_outlined),
),
const SizedBox(width: 14),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
titulo,
style: const TextStyle(
fontSize: 18,
fontWeight: FontWeight.w800,
),
),
const SizedBox(height: 4),
Text(
subtitulo,
style: const TextStyle(
fontSize: 13,
color: Color(0xFF555555),
),
),
const SizedBox(height: 6),
Text(
detalle,
style: const TextStyle(
fontSize: 13,
height: 1.2,
color: Color(0xFF444444),
),
),
const SizedBox(height: 10),
Container(
padding: const EdgeInsets.symmetric(
horizontal: 12,
vertical: 6,
),
decoration: BoxDecoration(
color: const Color(0xFFEAEAEA),
borderRadius: BorderRadius.circular(16),
),
child: Text(
estadoTexto,
style: const TextStyle(
fontSize: 12,
fontWeight: FontWeight.w700,
),
),
),
],
),
),
],
),
);
}
}

class _AlertEmptyCard extends StatelessWidget {
final String texto;

const _AlertEmptyCard({
required this.texto,
});

@override
Widget build(BuildContext context) {
return Container(
width: double.infinity,
padding: const EdgeInsets.all(18),
decoration: BoxDecoration(
color: const Color(0xFFF6F6F6),
borderRadius: BorderRadius.circular(26),
boxShadow: [
BoxShadow(
color: Colors.black.withValues(alpha: 0.06),
blurRadius: 22,
offset: const Offset(0, 10),
),
],
),
child: Text(
texto,
style: const TextStyle(
fontSize: 14,
color: Color(0xFF444444),
),
),
);
}
}

class CaregiverLinkedPatientData {
final String nombre;
final Map<int, MedicationData?> medicamentosPorCompartimiento;

const CaregiverLinkedPatientData({
required this.nombre,
required this.medicamentosPorCompartimiento,
});
}

List<MapEntry<int, MedicationData>> caregiverObtenerMedicamentosProximaToma(
Map<int, MedicationData?> medicamentosPorCompartimiento,
) {
final medicamentos = medicamentosPorCompartimiento.entries
.where((entry) {
final medicamento = entry.value;
if (medicamento == null) return false;

return medicamento.pastillasRestantes >= medicamento.cantidadPastillas;
})
.map((entry) => MapEntry(entry.key, entry.value!))
.toList();

if (medicamentos.isEmpty) {
return [];
}

medicamentos.sort(
(a, b) => a.value.proximaDosis.compareTo(b.value.proximaDosis),
);

final DateTime primeraFecha = medicamentos.first.value.proximaDosis;

return medicamentos.where(
(entry) => mismaFechaHoraMinuto(entry.value.proximaDosis, primeraFecha),
).toList();
}

DateTime? caregiverObtenerFechaProximaToma(
Map<int, MedicationData?> medicamentosPorCompartimiento,
) {
final medicamentos =
caregiverObtenerMedicamentosProximaToma(medicamentosPorCompartimiento);

if (medicamentos.isEmpty) {
return null;
}

return medicamentos.first.value.proximaDosis;
}

class CaregiverHomePlaceholder extends StatefulWidget {
const CaregiverHomePlaceholder({super.key});

@override
State<CaregiverHomePlaceholder> createState() =>
_CaregiverHomePlaceholderState();
}

class _CaregiverHomePlaceholderState extends State<CaregiverHomePlaceholder> {
int currentIndex = 0;
late final CaregiverLinkedPatientData pacienteVinculado;
@override
void initState() {
super.initState();

final ahora = redondearAlMinuto(DateTime.now());

pacienteVinculado = CaregiverLinkedPatientData(
nombre: 'Don Carlos',
medicamentosPorCompartimiento: {
1: MedicationData(
nombre: 'Losartán',
cantidadPastillas: 1,
frecuenciaHoras: 12,
totalPastillasCargadas: 12,
pastillasRestantes: 8,
primeraDosis: ahora.subtract(const Duration(hours: 4)),
proximaDosis: ahora.add(const Duration(hours: 2)),
),
2: MedicationData(
nombre: 'Metformina',
cantidadPastillas: 1,
frecuenciaHoras: 8,
totalPastillasCargadas: 10,
pastillasRestantes: 5,
primeraDosis: ahora.subtract(const Duration(hours: 6)),
proximaDosis: ahora.add(const Duration(hours: 2)),
),
3: MedicationData(
nombre: 'Acetaminofén',
cantidadPastillas: 2,
frecuenciaHoras: 24,
totalPastillasCargadas: 8,
pastillasRestantes: 6,
primeraDosis: ahora.subtract(const Duration(hours: 10)),
proximaDosis: ahora.add(const Duration(hours: 10)),
),
},
);
}

Widget buildContenido() {
switch (currentIndex) {
case 0:
return CaregiverDashboardPage(
paciente: pacienteVinculado,
);
case 1:
return CaregiverPatientPage(
paciente: pacienteVinculado,
);
case 2:
return CaregiverHistoryPage(
paciente: pacienteVinculado,
);
case 3:
return CaregiverAlertsPage(
paciente: pacienteVinculado,
);
default:
return const SizedBox.shrink();
}
}

@override
Widget build(BuildContext context) {
return Scaffold(
body: SafeArea(
child: PhoneFrame(
child: Column(
children: [
Expanded(
child: buildContenido(),
),
CaregiverBottomNavigationBar(
currentIndex: currentIndex,
onTap: (index) {
setState(() {
currentIndex = index;
});
},
),
],
),
),
),
);
}
}

class CaregiverBottomNavigationBar extends StatelessWidget {
final int currentIndex;
final ValueChanged<int> onTap;

const CaregiverBottomNavigationBar({
super.key,
required this.currentIndex,
required this.onTap,
});

@override
Widget build(BuildContext context) {
const items = [
_BottomNavItemData(
icon: Icons.home_outlined,
activeIcon: Icons.home,
label: 'Inicio',
),
_BottomNavItemData(
icon: Icons.person_outline,
activeIcon: Icons.person,
label: 'Paciente',
),
_BottomNavItemData(
icon: Icons.history,
activeIcon: Icons.history,
label: 'Historial',
),
_BottomNavItemData(
icon: Icons.notifications_none,
activeIcon: Icons.notifications,
label: 'Alertas',
),
];

return Container(
padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
decoration: const BoxDecoration(
color: Color(0xFFE7E7E7),
border: Border(
top: BorderSide(
color: Color(0xFFD3D3D3),
width: 1,
),
),
),
child: Row(
children: List.generate(items.length, (index) {
final item = items[index];
final bool activo = currentIndex == index;

return Expanded(
child: InkWell(
borderRadius: BorderRadius.circular(22),
onTap: () => onTap(index),
child: AnimatedContainer(
duration: const Duration(milliseconds: 180),
padding: const EdgeInsets.symmetric(
vertical: 10,
horizontal: 6,
),
decoration: BoxDecoration(
color: activo
? const Color(0xFFDCDCDC)
: Colors.transparent,
borderRadius: BorderRadius.circular(22),
),
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
Icon(
activo ? item.activeIcon : item.icon,
size: 22,
color: Colors.black,
),
const SizedBox(height: 4),
Text(
item.label,
maxLines: 1,
overflow: TextOverflow.ellipsis,
style: TextStyle(
fontSize: 10,
fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
color: Colors.black,
),
),
],
),
),
),
);
}),
),
);
}
}

class CaregiverDashboardPage extends StatelessWidget {
final CaregiverLinkedPatientData paciente;

const CaregiverDashboardPage({
super.key,
required this.paciente,
});

@override
Widget build(BuildContext context) {
final medicamentosProximos = caregiverObtenerMedicamentosProximaToma(
paciente.medicamentosPorCompartimiento,
);

final fechaProximaToma = caregiverObtenerFechaProximaToma(
paciente.medicamentosPorCompartimiento,
);

return SingleChildScrollView(
padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
TopGreeting(
saludo: 'Buenos días,',
nombre: 'Cuidador',
),
const SizedBox(height: 22),
Container(
width: double.infinity,
padding: const EdgeInsets.all(18),
decoration: BoxDecoration(
color: const Color(0xFFF6F6F6),
borderRadius: BorderRadius.circular(28),
boxShadow: [
BoxShadow(
color: Colors.black.withValues(alpha: 0.06),
blurRadius: 22,
offset: const Offset(0, 10),
),
],
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text(
'PACIENTE VINCULADO',
style: TextStyle(
fontSize: 12,
letterSpacing: 0.7,
fontWeight: FontWeight.w600,
color: Color(0xFF444444),
),
),
const SizedBox(height: 10),
Text(
paciente.nombre,
style: const TextStyle(
fontSize: 28,
height: 1.0,
fontWeight: FontWeight.w800,
),
),
const SizedBox(height: 8),
const Text(
'Desde aquí podrá revisar sus tomas, alertas y seguimiento general.',
style: TextStyle(
fontSize: 14,
height: 1.2,
color: Color(0xFF444444),
),
),
],
),
),
const SizedBox(height: 22),
Container(
width: double.infinity,
padding: const EdgeInsets.all(18),
decoration: BoxDecoration(
color: const Color(0xFFF6F6F6),
borderRadius: BorderRadius.circular(28),
boxShadow: [
BoxShadow(
color: Colors.black.withValues(alpha: 0.06),
blurRadius: 22,
offset: const Offset(0, 10),
),
],
),
child: fechaProximaToma == null
? const Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
'PRÓXIMA TOMA',
style: TextStyle(
fontSize: 12,
letterSpacing: 0.7,
fontWeight: FontWeight.w600,
color: Color(0xFF444444),
),
),
SizedBox(height: 12),
Text(
'Sin tomas pendientes',
style: TextStyle(
fontSize: 26,
height: 1.0,
fontWeight: FontWeight.w800,
),
),
],
)
: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text(
'PRÓXIMA TOMA',
style: TextStyle(
fontSize: 12,
letterSpacing: 0.7,
fontWeight: FontWeight.w600,
color: Color(0xFF444444),
),
),
const SizedBox(height: 10),
Text(
formatearHora(fechaProximaToma),
style: const TextStyle(
fontSize: 34,
height: 1.0,
fontWeight: FontWeight.w800,
),
),
const SizedBox(height: 6),
Text(
etiquetaFecha(fechaProximaToma),
style: const TextStyle(
fontSize: 14,
fontWeight: FontWeight.w600,
color: Color(0xFF444444),
),
),
const SizedBox(height: 16),
...medicamentosProximos.map(
(entry) => Padding(
padding: const EdgeInsets.only(bottom: 10),
child: Container(
width: double.infinity,
padding: const EdgeInsets.all(14),
decoration: BoxDecoration(
color: const Color(0xFFEAEAEA),
borderRadius: BorderRadius.circular(20),
),
child: Row(
children: [
const Icon(
Icons.medication_outlined,
color: Colors.black87,
),
const SizedBox(width: 12),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
entry.value.nombre,
style: const TextStyle(
fontSize: 16,
fontWeight: FontWeight.w800,
),
),
const SizedBox(height: 3),
Text(
'Compartimiento ${entry.key} • ${entry.value.cantidadTexto}',
style: const TextStyle(
fontSize: 13,
color: Color(0xFF444444),
),
),
],
),
),
],
),
),
),
),
],
),
),
const SizedBox(height: 22),
const Text(
'RESUMEN DEL DÍA',
style: TextStyle(
fontSize: 12,
letterSpacing: 0.6,
fontWeight: FontWeight.w700,
color: Color(0xFF333333),
),
),
const SizedBox(height: 12),
CaregiverInfoCard(
titulo: 'Medicamentos activos',
detalle:
'El paciente tiene ${paciente.medicamentosPorCompartimiento.values.where((m) => m != null).length} medicamentos cargados en este momento.',
icono: Icons.medication_outlined,
),
const SizedBox(height: 14),
CaregiverInfoCard(
titulo: 'Próxima revisión sugerida',
detalle: fechaProximaToma == null
? 'No hay tomas pendientes por revisar.'
: 'Conviene revisar la toma de ${paciente.nombre} ${etiquetaFecha(fechaProximaToma).toLowerCase()} a las ${formatearHora(fechaProximaToma)}.',
icono: Icons.access_time,
),
const SizedBox(height: 14),
const CaregiverInfoCard(
titulo: 'Alertas importantes',
detalle: 'Luego aquí mostraremos stock bajo, retrasos o falta de confirmación.',
icono: Icons.notifications_active_outlined,
),
],
),
);
}
}

class CaregiverPatientPage extends StatelessWidget {
final CaregiverLinkedPatientData paciente;

const CaregiverPatientPage({
super.key,
required this.paciente,
});

@override
Widget build(BuildContext context) {
final medicamentosActivos = paciente.medicamentosPorCompartimiento.entries
.where((entry) => entry.value != null)
.map((entry) => MapEntry(entry.key, entry.value!))
.toList();

return SingleChildScrollView(
padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text(
'Paciente',
style: TextStyle(
fontSize: 30,
height: 1.0,
fontWeight: FontWeight.w800,
),
),
const SizedBox(height: 14),
const Text(
'Aquí podrá ver la información general del paciente vinculado.',
style: TextStyle(
fontSize: 15,
height: 1.2,
color: Color(0xFF2A2A2A),
),
),
const SizedBox(height: 20),
CaregiverInfoCard(
titulo: 'Nombre del paciente',
detalle: paciente.nombre,
icono: Icons.person_outline,
),
const SizedBox(height: 14),
const CaregiverInfoCard(
titulo: 'Relación con el cuidador',
detalle: 'Familiar responsable',
icono: Icons.people_outline,
),
const SizedBox(height: 20),
const Text(
'MEDICAMENTOS DEL PACIENTE',
style: TextStyle(
fontSize: 12,
letterSpacing: 0.6,
fontWeight: FontWeight.w700,
color: Color(0xFF333333),
),
),
const SizedBox(height: 12),
...medicamentosActivos.map(
(entry) => Padding(
padding: const EdgeInsets.only(bottom: 14),
child: CaregiverInfoCard(
titulo: entry.value.nombre,
detalle:
'Compartimiento ${entry.key} • ${entry.value.cantidadTexto} • ${entry.value.frecuenciaTexto}',
icono: Icons.medication_outlined,
),
),
),
],
),
);
}
}

class CaregiverHistoryPage extends StatelessWidget {
final CaregiverLinkedPatientData paciente;

const CaregiverHistoryPage({
super.key,
required this.paciente,
});

@override
Widget build(BuildContext context) {
return SingleChildScrollView(
padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text(
'Historial',
style: TextStyle(
fontSize: 30,
height: 1.0,
fontWeight: FontWeight.w800,
),
),
const SizedBox(height: 14),
const Text(
'Aquí verá las tomas confirmadas y los movimientos importantes.',
style: TextStyle(
fontSize: 15,
height: 1.2,
color: Color(0xFF2A2A2A),
),
),
const SizedBox(height: 20),
const CaregiverInfoCard(
titulo: 'Sin historial todavía',
detalle: 'Más adelante aquí aparecerán las tomas realizadas.',
icono: Icons.history,
),
],
),
);
}
}

class CaregiverAlertsPage extends StatelessWidget {
final CaregiverLinkedPatientData paciente;

const CaregiverAlertsPage({
super.key,
required this.paciente,
});

@override
Widget build(BuildContext context) {
return SingleChildScrollView(
padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text(
'Alertas del cuidador',
style: TextStyle(
fontSize: 30,
height: 1.0,
fontWeight: FontWeight.w800,
),
),
const SizedBox(height: 14),
const Text(
'Aquí aparecerán las novedades que el cuidador debe revisar.',
style: TextStyle(
fontSize: 15,
height: 1.2,
color: Color(0xFF2A2A2A),
),
),
const SizedBox(height: 20),
const CaregiverInfoCard(
titulo: 'Sin alertas por ahora',
detalle: 'Aquí luego mostraremos retrasos, stock bajo o falta de confirmación.',
icono: Icons.notifications_none,
),
],
),
);
}
}

class CaregiverInfoCard extends StatelessWidget {
final String titulo;
final String detalle;
final IconData icono;

const CaregiverInfoCard({
super.key,
required this.titulo,
required this.detalle,
required this.icono,
});

@override
Widget build(BuildContext context) {
return Container(
width: double.infinity,
padding: const EdgeInsets.all(18),
decoration: BoxDecoration(
color: const Color(0xFFF6F6F6),
borderRadius: BorderRadius.circular(26),
boxShadow: [
BoxShadow(
color: Colors.black.withValues(alpha: 0.06),
blurRadius: 22,
offset: const Offset(0, 10),
),
],
),
child: Row(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Container(
width: 42,
height: 42,
decoration: const BoxDecoration(
color: Color(0xFFE7E7E7),
shape: BoxShape.circle,
),
child: Icon(icono),
),
const SizedBox(width: 14),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
titulo,
style: const TextStyle(
fontSize: 18,
fontWeight: FontWeight.w800,
),
),
const SizedBox(height: 6),
Text(
detalle,
style: const TextStyle(
fontSize: 14,
height: 1.2,
color: Color(0xFF444444),
),
),
],
),
),
],
),
);
}
}