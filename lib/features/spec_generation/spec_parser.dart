class SpecParser {
  static String clean(String raw) {
    var s = raw.trim();
    if (s.startsWith('```markdown')) {
      s = s.substring('```markdown'.length);
    } else if (s.startsWith('```')) {
      final firstNewline = s.indexOf('\n', 3);
      if (firstNewline != -1) {
        s = s.substring(firstNewline + 1);
      }
    }
    if (s.endsWith('```')) {
      s = s.substring(0, s.length - 3);
    }
    return s.trim();
  }
}
