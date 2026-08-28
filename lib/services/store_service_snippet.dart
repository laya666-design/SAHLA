  static Future<bool> connectWithPhoneAsId(String phoneNumber) async {
    // Session anonyme pour avoir un uid Firebase stable sur cet appareil.
    var user = FirebaseAuth.instance.currentUser;
    if (user == null || !user.isAnonymous) {
      // Si déjà connecté avec un vrai compte, on ne force pas l'anonyme.
      if (user == null) {
        final cred = await FirebaseAuth.instance.signInAnonymously();
        user = cred.user;
      }
    }
    final uid = user!.uid;

    // Cherche un magasin déjà lié à ce numéro (reconnexion sur nouvel appareil
    // non supportée en mode numéro-as-id sans backend dédié ; on crée / met
    // à jour le profil lié à cet uid).
    final docRef =
        FirebaseFirestore.instance.collection(_storesCollection).doc(uid);
    final doc = await docRef.get();
    if (doc.exists) {
      // Met à jour le téléphone si besoin.
      await docRef.update({'tel': phoneNumber});
      await _registerFcmToken(uid);
      return false;
    }
    final profile = StoreProfile(
      uid: uid,
      nom: '',
      tel: phoneNumber,
      adresse: '',
      actif: false,
      subscriptionStatus: SubscriptionStatus.essai,
      trialEndDate:
          DateTime.now().add(const Duration(days: kEssaiGratuitJours)),
    );
    await docRef.set(profile.toMap());
    await _registerFcmToken(uid);
    return true;
  }

  /// Crée un profil minimal si c'est la première connexion par téléphone
  /// (comme pour Google) : `actif: false` en attendant validation
