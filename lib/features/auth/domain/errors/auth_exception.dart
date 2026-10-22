/// Erro de autenticação independente do provedor.
///
/// O [code] segue os códigos do Firebase Auth (`invalid-credential`,
/// `email-already-in-use`...), que são o vocabulário que as telas já usam
/// pra montar as mensagens. Se um dia trocar de provedor, o repositório
/// traduz os códigos dele para estes.
class AuthException implements Exception {
  const AuthException(this.code, [this.message]);

  final String code;
  final String? message;

  @override
  String toString() => 'AuthException($code${message == null ? '' : ': $message'})';
}
