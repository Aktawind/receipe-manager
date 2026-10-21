# Règles R8 de l'application (chargées automatiquement par le plugin Gradle de Flutter).
#
# Certains plugins appellent leur code Android depuis Dart par JNI (bindings jnigen), en
# cherchant les méthodes par leur nom. R8 ne voit pas ces appels : sans ces règles, il
# supprime ou renomme les méthodes et l'app échoue au démarrage (NoSuchMethodError).

# shared_preferences_android (bindings JNI, méthodes suspend)
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# Les signatures JNI des méthodes suspend mentionnent Continuation : son nom doit rester intact.
-keep class kotlin.coroutines.Continuation { *; }
