import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../presentation/screens/splash_screen.dart';
import '../../presentation/screens/login_screen.dart';
import '../../presentation/screens/role_selection_screen.dart';
import '../../presentation/screens/password_change_screen.dart';
import '../../presentation/screens/patient_list_screen.dart';
import '../../presentation/screens/patient_registration_screen.dart';
import '../../presentation/screens/chat_screen.dart';
import '../../presentation/screens/doctor_dashboard.dart';
import '../../presentation/screens/doctor_patient_list_screen.dart';
import '../../presentation/screens/patient_detail_screen.dart';
import '../../presentation/screens/doctor_patient_detail_screen.dart';
import '../../presentation/screens/emergency_screen.dart';
import '../../presentation/screens/admin_dashboard.dart';
import '../../presentation/screens/prescription_screen.dart';
import '../../presentation/screens/activity_log_screen.dart';
import '../../presentation/screens/doctor_sheet_screen.dart';
import '../../presentation/screens/asha_register_screen.dart';
import '../../presentation/screens/tho_dashboard_screen.dart';
import '../../presentation/screens/gramnidan_register_detail_screen.dart';
import '../../core/models/user_role.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  redirect: (context, state) async {
    final user = Supabase.instance.client.auth.currentUser;
    final loggingIn = state.matchedLocation.startsWith('/auth/login');
    final selectingRole = state.matchedLocation == '/auth/role';
    final changingPassword = state.matchedLocation == '/auth/change-password';
    final onSplash = state.matchedLocation == '/splash';

    if (onSplash) return null;

    if (user == null) {
      return loggingIn || selectingRole ? null : '/auth/role';
    }

    final profile = await Supabase.instance.client
        .from('user_profiles')
        .select('role, is_active, must_change_password')
        .eq('id', user.id)
        .maybeSingle();

    final role = UserRole.fromString((profile?['role'] as String?) ?? 'asha');
    final isActive = profile?['is_active'] as bool? ?? true;
    final mustChangePassword = profile?['must_change_password'] as bool? ?? false;

    if (!isActive) {
      return '/auth/login';
    }

    if (mustChangePassword && !changingPassword) {
      return '/auth/change-password';
    }

    if ((loggingIn || changingPassword) && !mustChangePassword) {
      switch (role) {
        case UserRole.asha:
          return '/dashboard/asha';
        case UserRole.doctor:
          return '/dashboard/doctor';
        case UserRole.tho:
          return '/dashboard/tho';
        case UserRole.admin:
          return '/admin';
      }
    }

    final location = state.matchedLocation;
    final isAshaRoute = location.startsWith('/dashboard/asha') ||
                        location.startsWith('/patient/') ||
                        location.startsWith('/gramnidan/') ||
                        location.startsWith('/emergency/');
    final isDoctorRoute = location.startsWith('/dashboard/doctor') ||
                          location.startsWith('/prescription/') ||
                          location.startsWith('/doctor-sheet/');
    final isAdminRoute = location.startsWith('/admin') ||
                         location.startsWith('/activity/');
    final isThoRoute = location.startsWith('/dashboard/tho');

    if (role == UserRole.asha && (isDoctorRoute || isAdminRoute || isThoRoute)) {
      return '/dashboard/asha';
    }
    if (role == UserRole.doctor && (isAshaRoute || isAdminRoute || isThoRoute)) {
      return '/dashboard/doctor';
    }
    if (role == UserRole.tho && (isAshaRoute || isDoctorRoute || isAdminRoute)) {
      return '/dashboard/tho';
    }
    if (role == UserRole.admin && (isAshaRoute || isDoctorRoute || isThoRoute)) {
      return '/admin';
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    // Login after the user has selected the role they are signing in as.
    GoRoute(
      path: '/auth/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/auth/role',
      builder: (context, state) => const RoleSelectionScreen(),
    ),
    GoRoute(
      path: '/auth/change-password',
      builder: (context, state) => const PasswordChangeScreen(),
    ),

    // ASHA Worker Routes

    // ASHA Worker Routes
    GoRoute(
      path: '/dashboard/asha',
      builder: (context, state) => const PatientListScreen(),
    ),
    GoRoute(
      path: '/dashboard/asha/registers',
      builder: (context, state) {
        final initialType = (state.extra as String?) ?? state.uri.queryParameters['type'];
        return AshaRegisterScreen(initialRegisterType: initialType);
      },
    ),
    GoRoute(
      path: '/gramnidan/register/:id',
      builder: (context, state) => GramNidanRegisterDetailScreen(
        registerId: state.pathParameters['id']!,
      ),
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
      path: '/dashboard/doctor/patients',
      builder: (context, state) => const DoctorPatientListScreen(),
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
    GoRoute(
      path: '/doctor-sheet/:patientId',
      builder: (context, state) => DoctorSheetScreen(
        patientId: state.pathParameters['patientId']!,
      ),
    ),

    // THO Routes
    GoRoute(
      path: '/dashboard/tho',
      builder: (context, state) => const ThoDashboardScreen(),
    ),
    GoRoute(
      path: '/dashboard/tho/register/:id',
      builder: (context, state) => GramNidanRegisterDetailScreen(
        registerId: state.pathParameters['id']!,
      ),
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
