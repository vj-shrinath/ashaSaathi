import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../presentation/screens/splash_screen.dart';
import '../../presentation/screens/login_screen.dart';
import '../../presentation/screens/otp_screen.dart';
import '../../presentation/screens/role_selection_screen.dart';
import '../../presentation/screens/patient_list_screen.dart';
import '../../presentation/screens/patient_registration_screen.dart';
import '../../presentation/screens/chat_screen.dart';
import '../../presentation/screens/doctor_dashboard.dart';
import '../../presentation/screens/patient_detail_screen.dart';
import '../../presentation/screens/doctor_patient_detail_screen.dart';
import '../../presentation/screens/emergency_screen.dart';
import '../../presentation/screens/admin_dashboard.dart';
import '../../presentation/screens/prescription_screen.dart';
import '../../presentation/screens/activity_log_screen.dart';
import '../../core/models/user_role.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  redirect: (context, state) async {
    final user = Supabase.instance.client.auth.currentUser;
    final loggingIn = state.matchedLocation.startsWith('/auth/login');
    final selectingRole = state.matchedLocation == '/auth/role';
    final onSplash = state.matchedLocation == '/splash';
    final onOtp = state.matchedLocation == '/auth/otp';

    if (onSplash || onOtp) return null;

    if (user == null) {
      if (loggingIn || selectingRole) return null;
      return '/auth/role';
    }

    final roleStr = user.userMetadata?['role'] as String?;
    final hasRole = roleStr != null && roleStr.isNotEmpty;

    if (!hasRole && !selectingRole) {
      return '/auth/role';
    }

    if (hasRole) {
      final role = UserRole.fromString(roleStr);
      
      if (loggingIn || selectingRole) {
        switch (role) {
          case UserRole.asha:
            return '/dashboard/asha';
          case UserRole.doctor:
            return '/dashboard/doctor';
          case UserRole.admin:
            return '/admin';
        }
      }

      final location = state.matchedLocation;
      final isAshaRoute = location.startsWith('/dashboard/asha') ||
                          location.startsWith('/patient/') ||
                          location.startsWith('/emergency/');
      final isDoctorRoute = location.startsWith('/dashboard/doctor') ||
                            location.startsWith('/prescription/');
      final isAdminRoute = location.startsWith('/admin') ||
                           location.startsWith('/activity/');

      if (role == UserRole.asha && (isDoctorRoute || isAdminRoute)) {
        return '/dashboard/asha';
      }
      if (role == UserRole.doctor && (isAshaRoute || isAdminRoute)) {
        return '/dashboard/doctor';
      }
      if (role == UserRole.admin && (isAshaRoute || isDoctorRoute)) {
        return '/admin';
      }
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    // Generic login (shows role switcher)
    GoRoute(
      path: '/auth/login',
      builder: (context, state) => const RoleSelectionScreen(),
    ),
    // Role-specific logins
    GoRoute(
      path: '/auth/login/asha',
      builder: (context, state) => const LoginScreen(forcedRole: UserRole.asha),
    ),
    GoRoute(
      path: '/auth/login/doctor',
      builder: (context, state) => const LoginScreen(forcedRole: UserRole.doctor),
    ),
    GoRoute(
      path: '/auth/login/admin',
      builder: (context, state) => const LoginScreen(forcedRole: UserRole.admin),
    ),
    GoRoute(
      path: '/auth/otp',
      builder: (context, state) {
        final phone = state.extra as String? ?? '';
        return OtpScreen(phone: phone);
      },
    ),
    GoRoute(
      path: '/auth/role',
      builder: (context, state) => const RoleSelectionScreen(),
    ),

    // ASHA Worker Routes
    GoRoute(
      path: '/dashboard/asha',
      builder: (context, state) => const PatientListScreen(),
    ),
    GoRoute(
      path: '/patient/new',
      builder: (context, state) => const PatientRegistrationScreen(),
    ),
    GoRoute(
      path: '/chat/:patientId/:visitId',
      builder: (context, state) {
        final patientId = state.pathParameters['patientId']!;
        final visitId = state.pathParameters['visitId']!;
        return ChatScreen(patientId: patientId, visitId: visitId);
      },
    ),
    GoRoute(
      path: '/patient/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return PatientDetailScreen(patientId: id);
      },
    ),
    GoRoute(
      path: '/emergency/:patientId',
      builder: (context, state) {
        final id = state.pathParameters['patientId']!;
        return EmergencyScreen(patientId: id);
      },
    ),

    // Doctor Routes
    GoRoute(
      path: '/dashboard/doctor',
      builder: (context, state) => const DoctorDashboardScreen(),
    ),
    GoRoute(
      path: '/dashboard/doctor/patient/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return DoctorPatientDetailScreen(patientId: id);
      },
    ),
    GoRoute(
      path: '/prescription/:patientId/:visitId',
      builder: (context, state) {
        final patientId = state.pathParameters['patientId']!;
        final visitId = state.pathParameters['visitId']!;
        return PrescriptionScreen(patientId: patientId, visitId: visitId);
      },
    ),

    // Admin Routes
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminDashboardScreen(),
    ),
    GoRoute(
      path: '/activity/logs',
      builder: (context, state) => const ActivityLogScreen(),
    ),
  ],
);
