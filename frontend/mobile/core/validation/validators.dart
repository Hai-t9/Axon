class Validators {
  static String? fullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Full name is required.';
    }
    return null;
  }

  static String? email(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Email is required.';
    }
    if (!trimmed.contains('@') || !trimmed.contains('.')) {
      return 'Enter a valid email.';
    }
    return null;
  }

  static String? password(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Password is required.';
    }
    if (trimmed.length < 8) {
      return 'Use at least 8 characters.';
    }
    return null;
  }

  static String? competitionName(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Competition name is required.';
    }
    if (trimmed.length < 3) {
      return 'Use at least 3 characters.';
    }
    return null;
  }

  static String? invitationLink(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Invitation link is required.';
    }
    return null;
  }
}
