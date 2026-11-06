import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/data/import/schema_org.dart';

void main() {
  test('durées ISO 8601', () {
    expect(SchemaOrg.minutes('PT1H30M'), 90);
    expect(SchemaOrg.minutes('PT90M'), 90);
    expect(SchemaOrg.minutes('P0DT20M'), 20);
    expect(SchemaOrg.minutes('pt15m'), 15);
    expect(SchemaOrg.minutes('PT0.5H'), 30);
    expect(SchemaOrg.minutes('PT0S'), isNull);
    expect(SchemaOrg.minutes('20 min'), isNull);
    expect(SchemaOrg.minutes(null), isNull);
  });

  test('portions : personnes ou pièces', () {
    expect(SchemaOrg.servings('4'), (4, ''));
    expect(SchemaOrg.servings('4 personnes'), (4, ''));
    expect(SchemaOrg.servings('6 pers.'), (6, ''));
    expect(SchemaOrg.servings('4 servings'), (4, ''));
    expect(SchemaOrg.servings('8 parts égales'), (8, ''));
    expect(SchemaOrg.servings('12 blinis'), (12, 'blinis'));
    expect(SchemaOrg.servings('Une dizaine'), isNull);
  });
}
