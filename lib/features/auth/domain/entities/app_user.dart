/// Usuário autenticado, do ponto de vista do app (entidade de domínio).
///
/// Substitui o uso direto do `User` do firebase_auth nas telas: elas só
/// precisam do id e do nome, e assim não ficam presas ao Firebase.
class AppUser {
  const AppUser({required this.id, this.name, this.email});

  final String id;
  final String? name;
  final String? email;

  /// Primeiro nome para saudações ("Bom dia, Maria").
  String? get firstName {
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed.split(' ').first;
  }
}
