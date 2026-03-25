part of 'main.dart';

String loc(AppLanguage language, String key, [String? unused]) {
  switch (language) {
    case AppLanguage.en:
      return key;
    case AppLanguage.ru:
      return ruTranslations[key] ?? key;
    case AppLanguage.zh:
      return zhTranslations[key] ?? key;
  }
}

String tr(String key, [String? unused]) {
  return loc(_activeLanguage, key);
}
