enum AppearanceMode { system, light, dark }

AppearanceMode appearanceModeFromStoredValue(String? value) => switch (value) {
  'light' => AppearanceMode.light,
  'dark' => AppearanceMode.dark,
  _ => AppearanceMode.system,
};
