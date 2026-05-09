import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/signup_page.dart';
import '../features/auth/state/auth_controller.dart';
import '../features/competition/presentation/competition_dashboard_page.dart';
import '../features/competition/presentation/competition_settings_page.dart';
import '../features/competition/presentation/host_competition_page.dart';
import '../features/competition/presentation/join_competition_page.dart';
import '../features/competition/presentation/phase_control_page.dart';
import '../features/competition/presentation/teams_control_page.dart';
import '../features/home/presentation/home_page.dart';
import '../features/leaderboard/presentation/leaderboard_page.dart';
import '../features/model_submission/presentation/model_submission_page.dart';
import '../features/validation/presentation/validation_page.dart';
import '../features/evaluation/presentation/evaluation_page.dart';
import '../features/data_validation/presentation/data_validation_page.dart';
import '../features/gallery/presentation/gallery_page.dart';
import '../features/profile/presentation/profile_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);
  final isLoggedIn = authState.valueOrNull != null;
  return GoRouter(
    initialLocation: HomePage.routePath,
    redirect: (context, state) {
      if (authState.isLoading) return null;

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
        path: ProfilePage.routePath,
        name: ProfilePage.routeName,
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        path: CompetitionDashboardPage.routePath,
        name: CompetitionDashboardPage.routeName,
        builder: (context, state) {
          final id = state.pathParameters['id'];
          if (id == null || id.isEmpty) return const HomePage();
          return CompetitionDashboardPage(competitionId: id);
        },
      ),
      GoRoute(
        path: CompetitionSettingsPage.routePath,
        name: CompetitionSettingsPage.routeName,
        builder: (context, state) {
          final id = state.pathParameters['id'];
          if (id == null || id.isEmpty) return const HomePage();
          return CompetitionSettingsPage(competitionId: id);
        },
      ),
      GoRoute(
        path: TeamsControlPage.routePath,
        name: TeamsControlPage.routeName,
        builder: (context, state) {
          final id = state.pathParameters['id'];
          if (id == null || id.isEmpty) return const HomePage();
          return TeamsControlPage(competitionId: id);
        },
      ),
      GoRoute(
        path: PhaseControlPage.routePath,
        name: PhaseControlPage.routeName,
        builder: (context, state) {
          final id = state.pathParameters['id'];
          if (id == null || id.isEmpty) return const HomePage();
          return PhaseControlPage(competitionId: id);
        },
      ),
      GoRoute(
        path: LeaderboardPage.routePath,
        name: LeaderboardPage.routeName,
        builder: (context, state) {
          final id = state.pathParameters['id'];
          if (id == null || id.isEmpty) return const HomePage();
          return LeaderboardPage(competitionId: id);
        },
      ),
      GoRoute(
        path: ModelSubmissionPage.routePath,
        name: ModelSubmissionPage.routeName,
        builder: (context, state) {
          final id = state.pathParameters['id'];
          if (id == null || id.isEmpty) return const HomePage();
          return ModelSubmissionPage(competitionId: id);
        },
      ),
      GoRoute(
        path: ValidationPage.routePath,
        name: ValidationPage.routeName,
        builder: (context, state) {
          final id = state.pathParameters['id'];
          if (id == null || id.isEmpty) return const HomePage();
          return ValidationPage(competitionId: id);
        },
      ),
      GoRoute(
        path: EvaluationPage.routePath,
        name: EvaluationPage.routeName,
        builder: (context, state) {
          final id = state.pathParameters['id'];
          if (id == null || id.isEmpty) return const HomePage();
          return EvaluationPage(competitionId: id);
        },
      ),
      GoRoute(
        path: DataValidationPage.routePath,
        name: DataValidationPage.routeName,
        builder: (context, state) {
          final id = state.pathParameters['id'];
          if (id == null || id.isEmpty) return const HomePage();
          return DataValidationPage(competitionId: id);
        },
      ),
      GoRoute(
        path: GalleryPage.routePath,
        name: GalleryPage.routeName,
        builder: (context, state) {
          final id = state.pathParameters['id'];
          if (id == null || id.isEmpty) return const HomePage();
          return GalleryPage(competitionId: id);
        },
      ),
    ],
  );
});
