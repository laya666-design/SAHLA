/// Rôle choisi au premier lancement de l'application.
/// 1 compte = 1 rôle (pas de multi-rôles).
enum UserRole {
  conducteur,
  magasin,
  depanneuse;

  String get storageValue {
    switch (this) {
      case UserRole.conducteur:
        return 'conducteur';
      case UserRole.magasin:
        return 'magasin';
      case UserRole.depanneuse:
        return 'depanneuse';
    }
  }

  String labelFr() {
    switch (this) {
      case UserRole.conducteur:
        return 'Conducteur';
      case UserRole.magasin:
        return 'Magasin de pièces';
      case UserRole.depanneuse:
        return 'Dépanneuse';
    }
  }

  String labelAr() {
    switch (this) {
      case UserRole.conducteur:
        return 'سائق';
      case UserRole.magasin:
        return 'محل قطع غيار';
      case UserRole.depanneuse:
        return 'سطحّة';
    }
  }

  static UserRole? fromStorage(String? value) {
    switch (value) {
      case 'conducteur':
        return UserRole.conducteur;
      case 'magasin':
        return UserRole.magasin;
      case 'depanneuse':
        return UserRole.depanneuse;
      default:
        return null;
    }
  }
}
