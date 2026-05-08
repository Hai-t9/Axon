import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/signup_page.dart';
import '../features/auth/state/auth_controller.dart';
import '../features/competition/presentation/competition_dashboard_page.dart';
import '../features/competition/presentation/competition_settings_page.dart';
import '../features/competition/presentation/host_competition_page.dart';
import '../features/competition/presentation/join_competition_page.dart';
import '../features/home/presentation/home_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);
  final isLoggedIn = authState.valueOrNull != null;
  return GoRouter(
    initialLocation: HomePage.routePath,
    redirect: (context, state) {
      final isAuthRoute = state.matchedLocation == LoginPage.routePath ||
          state.matchedLocation == SignupPage.routePath;
      if (!isLoggedIn && !isAuthRoute) {
        return LoginPage.routePath;
      }
      if (isLoggedIn && isAuthRoute) {
        return HomePage.routePath;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: HomePage.routePath,
        name: HomePage.routeName,
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: LoginPage.routePath,
        name: LoginPage.routeName,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: SignupPage.routePath,
        name: SignupPage.routeName,
        builder: (context, state) => const SignupPage(),
      ),
      GoRoute(
        path: JoinCompetitionPage.routePath,
        name: JoinCompetitionPage.routeName,
        builder: (context, state) => const JoinCompetitionPage(),
      ),
      GoRoute(
        path: HostCompetitionPage.routePath,
        name: HostCompetitionPage.routeName,
        builder: (context, state) => const HostCompetitionPage(),
      ),
      GoRoute(
        path: CompetitionDashboardPage.routePath,
        name: CompetitionDashboardPage.routeName,
        builder: (context, state) {
          final id = state.pathParameters['id'];
          if (id == null || id.isEmpty) {
            return const HomePage();
          }
          return CompetitionDashboardPage(competitionId: id);
        },
      ),
      GoRoute(
        path: CompetitionSettingsPage.routePath,
        name: CompetitionSettingsPage.routeName,
        builder: (context, state) {
          final id = state.pathParameters['id'];
          if (id == null || id.isEmpty) {
            return const HomePage();
          }
          return CompetitionSettingsPage(competitionId: id);
        },
      ),
    ],
  );
});
