class AssetsPaths {
  // Tmail's SVG/PNG icon assets ship under `assets/tmail/` in this repo
  // (the host bluebubbles app already uses `assets/images/` for its own
  // PNGs — collision-prone). Updating these constants is the load-bearing
  // line: every SvgPicture.asset(imagePaths.icXxx) callsite reads from
  // here. Without this prefix, flutter_svg gets an empty stream from a
  // non-existent path and throws "Invalid SVG data" all over the mail UI.
  static const images = 'assets/tmail/images/';
  static const icons = 'assets/tmail/icons/';
  static const configurationImages = 'configurations/icons/';
  static const animations = 'assets/tmail/animations/';
}