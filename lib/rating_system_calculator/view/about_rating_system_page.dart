import 'package:flutter/material.dart';
import 'package:app_ui/app_ui.dart';
import 'package:rtu_mirea_app/rating_system_calculator/rating_system_calculator.dart';
import 'package:unicons/unicons.dart';

class AboutRatingSystemPage extends StatelessWidget {
  const AboutRatingSystemPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dark.background01,
      appBar: AppBar(backgroundColor: AppColors.dark.background01, title: const Text("Sistema de evaluación")),
      body: const SafeArea(child: Padding(padding: EdgeInsets.all(24), child: RatingSystemCalculatorView())),
    );
  }
}

class RatingSystemCalculatorView extends StatefulWidget {
  const RatingSystemCalculatorView({super.key});

  @override
  State<RatingSystemCalculatorView> createState() => _RatingSystemCalculatorViewState();
}

class _RatingSystemCalculatorViewState extends State<RatingSystemCalculatorView> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverList(
          delegate: SliverChildListDelegate([
            Text("Sistema de evaluación por puntos", style: AppTextStyle.h4),
const SizedBox(height: 16),
Text(
  "Esta sección permite consultar y dar seguimiento a los puntos obtenidos por el estudiante en sus actividades académicas.",
  style: AppTextStyle.body,
),
const ShortDescriptionCard(
  icon: UniconsSolid.check_circle,
  text: 'Registro de puntos por materia',
),
const ShortDescriptionCard(
  icon: UniconsSolid.exclamation_circle,
  text: 'La información mostrada deberá ajustarse a los criterios de evaluación definidos por cada docente.',
),
const SizedBox(height: 24),
Text("Puntos principales", style: AppTextStyle.h6),
Text(
  "Actividades base de la materia",
  style: AppTextStyle.body.copyWith(color: AppColors.dark.primary),
),
const SizedBox(height: 16),
Text(
  "Corresponden a las actividades principales definidas por el docente, como tareas, prácticas, proyectos, exámenes parciales o evidencias académicas.",
  style: AppTextStyle.body,
),
const SizedBox(height: 24),
Text("Participación y trabajo en clase", style: AppTextStyle.h6),
Text(
  "Seguimiento académico",
  style: AppTextStyle.body.copyWith(color: AppColors.dark.primary),
),
const SizedBox(height: 16),
Text(
  "Este apartado puede utilizarse para registrar participación, asistencia, prácticas en clase o actividades desarrolladas durante las sesiones.",
  style: AppTextStyle.body,
),
const SizedBox(height: 24),
Text("Puntos adicionales", style: AppTextStyle.h6),
Text(
  "Actividades complementarias",
  style: AppTextStyle.body.copyWith(color: AppColors.dark.primary),
),
const SizedBox(height: 16),
Text(
  "Incluye actividades extra, entregas complementarias o criterios adicionales que el docente considere dentro de la evaluación.",
  style: AppTextStyle.body,
),
const SizedBox(height: 24),
Text("Uso de la calculadora", style: AppTextStyle.h6),
const SizedBox(height: 16),
Text(
  "La calculadora funciona como una herramienta de apoyo para que el estudiante pueda estimar su avance académico. Los resultados son informativos y no sustituyen la calificación oficial registrada por la institución.",
  style: AppTextStyle.body,
),
const SizedBox(height: 24),
Text("Tabla de referencia", style: AppTextStyle.h6),
const SizedBox(height: 16),
const ScoresTable(),
          ]),
        ),
      ],
    );
  }
}
