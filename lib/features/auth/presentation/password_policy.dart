/// Client-side feedback for the password policy configured in Firebase Auth.
abstract final class PasswordPolicy {
  static String? validate(String? value) {
    final password = value ?? '';
    if (password.length < 12) {
      return 'Use ao menos 12 caracteres';
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return 'Inclua ao menos uma letra minúscula';
    }
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Inclua ao menos uma letra maiúscula';
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'Inclua ao menos um número';
    }
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
      return 'Inclua ao menos um símbolo';
    }
    return null;
  }
}
