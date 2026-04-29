import 'package:go_router/go_router.dart';
import 'pages/captcha_auto_login_page.dart';
import 'pages/main_menu_page.dart';
import 'pages/score_result_page.dart';
import 'pages/open_score_page.dart';
import 'pages/score_tracking_page.dart';
import 'pages/course_schedule_page.dart';
import 'pages/course_assistant/course_assistant_page.dart';
import 'pages/course_selection_schedule_page.dart';
import 'pages/announcement_page.dart';
import 'pages/exam_task/exam_task_page.dart';
import 'pages/graduation_page.dart';
import 'pages/calendar_page.dart';
import 'pages/settings_page.dart';
import 'pages/info_page.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'login',
      builder: (context, state) => const CaptchaAutoLoginPage(),
    ),
    GoRoute(
      path: '/home',
      name: 'home',
      builder: (context, state) => const MainMenuPage(),
    ),
    GoRoute(
      path: '/scores',
      name: 'scores',
      builder: (context, state) => const ScoreResultPage(),
    ),
    GoRoute(
      path: '/open-scores',
      name: 'openScores',
      builder: (context, state) => const OpenScorePage(),
    ),
    GoRoute(
      path: '/score-tracking',
      name: 'scoreTracking',
      builder: (context, state) => const ScoreTrackingPage(),
    ),
    GoRoute(
      path: '/schedule',
      name: 'schedule',
      builder: (context, state) => const CourseSchedulePage(),
    ),
    GoRoute(
      path: '/assistant',
      name: 'assistant',
      builder: (context, state) => const CourseAssistantPage(),
    ),
    GoRoute(
      path: '/selection',
      name: 'selection',
      builder: (context, state) => const CourseSelectionSchedulePage(),
    ),
    GoRoute(
      path: '/announcements',
      name: 'announcements',
      builder: (context, state) => const AnnouncementPage(),
    ),
    GoRoute(
      path: '/tasks',
      name: 'tasks',
      builder: (context, state) => const ExamTaskPage(),
    ),
    GoRoute(
      path: '/graduation',
      name: 'graduation',
      builder: (context, state) => const GraduationPage(),
    ),
    GoRoute(
      path: '/calendar',
      name: 'calendar',
      builder: (context, state) => const CalendarPage(),
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsPage(),
    ),
    GoRoute(
      path: '/info',
      name: 'info',
      builder: (context, state) => const InfoPage(),
    ),
  ],
);