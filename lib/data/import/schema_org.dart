/// Valeurs du format standard schema.org/Recipe, commun aux sites de recettes
/// (JSON-LD, microdonnées) et à l'export de Recipe Keeper.
abstract final class SchemaOrg {
  /// Durée ISO 8601 (« PT1H30M », « P0DT20M », « PT90M ») en minutes ;
  /// `null` si elle est absente, illisible ou nulle (« PT0S »).
  static int? minutes(String? value) {
    final text = (value ?? '').trim().toUpperCase();
    final match = RegExp(
      r'^P(?:(\d+)D)?(?:T(?:(\d+(?:\.\d+)?)H)?(?:(\d+(?:\.\d+)?)M)?(?:(\d+)S)?)?$',
    ).firstMatch(text);
    if (match == null) return null;
    double part(int group) => double.tryParse(match.group(group) ?? '') ?? 0;
    final minutes = (part(1) * 1440 + part(2) * 60 + part(3) + part(4) / 60)
        .round();
    return minutes > 0 ? minutes : null;
  }

  /// « 4 », « 4 personnes », « 12 blinis » : le nombre, et l'unité quand ce
  /// sont des pièces (vide pour des personnes) ; `null` sans nombre.
  static (int, String)? servings(String text) {
    final match = RegExp(r'(\d+)\s*(.*)').firstMatch(text.trim());
    if (match == null) return null;
    final unit = match.group(2)!.trim();
    final people = RegExp(
      r'^(pers(onnes?|\.)?|portions?|parts?|servings?|people|couverts?)?(\s|$)',
      caseSensitive: false,
    );
    return (int.parse(match.group(1)!), people.hasMatch(unit) ? '' : unit);
  }
}
