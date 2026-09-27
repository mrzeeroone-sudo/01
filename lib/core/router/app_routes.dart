class AppRoutes {
  const AppRoutes._();

  static const signIn = '/sign-in';
  static const join = '/join';
  static const home = '/home';
  static const tasks = '/tasks';

  /// المسارات المتاحة بدون دخول.
  static const public = {signIn, join};
}
