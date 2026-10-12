import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:control_asistencia/models/attendance_model.dart';
import 'package:control_asistencia/widgets/shift_journey_card.dart';

void main() {
  testWidgets('ShiftJourneyCard renders journey information properly', (WidgetTester tester) async {
    final journey = ShiftJourneyRecord(
      id: 'j1',
      userId: 'test_u1',
      userName: 'Juan Pérez',
      workDate: '2026-09-20',
      shift: AttendanceShift.MORNING,
      checkIn: AttendanceModel(
        id: '1',
        userId: 'test_u1',
        userName: 'Juan Pérez',
        type: AttendanceType.CHECK_IN,
        timestamp: DateTime(2026, 9, 20, 8, 5),
        status: AttendanceStatus.ON_TIME,
        shift: AttendanceShift.MORNING,
        workDate: '2026-09-20',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShiftJourneyCard(journey: journey, showUserName: true),
        ),
      ),
    );

    expect(find.text('Juan Pérez'), findsOneWidget);
    expect(find.text('Mañana'), findsOneWidget);
    expect(find.text('Sin salida'), findsOneWidget);
  });
}
