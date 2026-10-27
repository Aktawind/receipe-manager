# Règles R8 de l'application (chargées automatiquement par le plugin Gradle de Flutter).
#
# Certains plugins appellent leur code Android depuis Dart par JNI (bindings jnigen), en
# cherchant les méthodes par leur nom. R8 ne voit pas ces appels : sans ces règles, il
# supprime ou renomme les méthodes et l'app échoue au démarrage (NoSuchMethodError).

# shared_preferences_android (bindings JNI, méthodes suspend)
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# Classes Kotlin que la bibliothèque jni (package:jni) charge par leur nom pour appeler les
# méthodes suspend. Liste obtenue en cherchant les noms de classes JNI dans le code Dart des
# dépendances (voir CLAUDE.md, section R8).
-keep class kotlin.Unit { *; }
-keep class kotlin.Result { *; }
-keep class kotlin.Result$Failure { *; }
-keep class kotlin.coroutines.Continuation { *; }
-keep class kotlin.coroutines.intrinsics.IntrinsicsKt { *; }
-keep class kotlin.coroutines.intrinsics.CoroutineSingletons { *; }
