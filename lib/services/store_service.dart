static Future<void> signInWithGoogle({bool rememberMe = true}) async {
  final GoogleSignIn googleSignIn = GoogleSignIn(
    serverClientId:
        '994131871524-dbn081ucefsf4vi4v0jl1m4gc11di90p.apps.googleusercontent.com',
  );

  final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
  if (googleUser == null) {
    throw Exception('Connexion Google annulée.');
  }

  final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

  final credential = GoogleAuthProvider.credential(
    accessToken: googleAuth.accessToken,
    idToken: googleAuth.idToken,
  );

  final userCred =
      await FirebaseAuth.instance.signInWithCredential(credential);
  final user = userCred.user;
  if (user == null) {
    throw Exception('Connexion Google impossible.');
  }

  await _saveRememberMe(rememberMe);

  final docRef =
      FirebaseFirestore.instance.collection(_storesCollection).doc(user.uid);
  final doc = await docRef.get();
  if (!doc.exists) {
    final profile = StoreProfile(
      uid: user.uid,
      nom: user.displayName ?? '',
      tel: '',
      adresse: '',
      actif: false,
      subscriptionStatus: SubscriptionStatus.essai,
      trialEndDate:
          DateTime.now().add(const Duration(days: kEssaiGratuitJours)),
    );
    await docRef.set(profile.toMap());
  }
  await _registerFcmToken(user.uid);
}
