import BuildProfile from 'BuildProfile';

// Local diagnostic package only. Restore this switch to false after collection.
const PINMONY_TRANSLATION_DIAGNOSTIC_PACKAGE: boolean = false;
export const PINMONY_TRANSLATION_DIAGNOSTIC_ENABLED: boolean =
  BuildProfile.DEBUG && PINMONY_TRANSLATION_DIAGNOSTIC_PACKAGE;
