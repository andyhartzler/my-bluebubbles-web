/// Helpers for building PostgREST filter strings that contain user input.
///
/// Two distinct escape layers are involved:
///   1. ILIKE pattern characters (`%`, `_`, `\`) — inside the value itself.
///   2. PostgREST `.or(...)` reserved characters (`,`, `(`, `)`, `"`) — around
///      the value when the value is embedded in an `or` filter.
///
/// Calling `.or('name.ilike.%$raw%')` without both layers breaks on:
///   - `raw` containing `,`  → splits the OR clause, runs a bogus second filter
///   - `raw` containing `(`/`)` → PostgREST parser error; whole query 400s
///   - `raw` containing `%`/`_` → unintended wildcard matches
///   - `raw` containing `"` → PostgREST tokenizer treats value boundary wrong
library;

final _ilikeMetacharacters = RegExp(r'[\\%_]');
final _orReservedCharacters = RegExp(r'[,()"]');

/// Escapes ILIKE metacharacters (`\`, `%`, `_`) so user input matches literally.
String escapeForIlike(String input) {
  if (!_ilikeMetacharacters.hasMatch(input)) return input.trim();
  return input
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_')
      .trim();
}

/// Wraps a value in PostgREST double quotes when it contains reserved
/// characters (`,`, `(`, `)`, `"`). Backslashes and inner quotes are escaped.
/// Values without reserved characters are returned unchanged so the query URL
/// stays readable.
String escapeForOr(String value) {
  if (!_orReservedCharacters.hasMatch(value)) return value;
  final inner = value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
  return '"$inner"';
}

/// Builds an ILIKE-against-many-columns OR clause safe for PostgREST `.or()`.
/// Each column produces `col.ilike.<quoted-pattern>` where the pattern is
/// `%$escaped%` wrapped with wildcards after ILIKE metacharacter escaping.
String buildIlikeOrClauses(Iterable<String> columns, String rawQuery) {
  final pattern = '%${escapeForIlike(rawQuery)}%';
  final safe = escapeForOr(pattern);
  return columns.map((c) => '$c.ilike.$safe').join(',');
}

/// Builds an equality OR clause safe for PostgREST `.or()`. Used for phone
/// lookups where the same value might live in `phone` or `phone_e164`.
String buildEqOrClauses(Iterable<String> columns, String rawValue) {
  final safe = escapeForOr(rawValue);
  return columns.map((c) => '$c.eq.$safe').join(',');
}
