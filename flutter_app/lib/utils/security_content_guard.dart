class SecurityContentGuard {
  static final List<String> _bannedWords = [
    'porn', 'xxx', 'sex', 'nude', 'adult', 'casino', 'betting', 'dream11',
    'rummy', 'earn money', 'free recharge', 'crypto', 'hack', 'mod apk',
    'call girl', 'lottery', 'teen patti', 'satta'
  ];

  static final List<String> _allowedTlds = [
    '.gov.in', '.nic.in', '.ac.in', '.edu.in', '.res.in',
    '.com', '.in', '.online', '.org', '.net'
  ];

  static String? validateContent(String text) {
    final lower = text.toLowerCase();

    for (final bad in _bannedWords) {
      if (lower.contains(bad)) {
        return 'Post blocked: Inappropriate or promotional content detected.';
      }
    }

    final urlRegex = RegExp(r'((https?:\/\/|www\.)[^\s]+)', caseSensitive: false);
    final matches = urlRegex.allMatches(text);

    for (final match in matches) {
      final rawUrl = match.group(0)!;
      final uri = Uri.tryParse(rawUrl.startsWith('http') ? rawUrl : 'https://$rawUrl');

      if (uri != null && uri.host.isNotEmpty) {
        final host = uri.host.toLowerCase().replaceAll('www.', '');
        final bool isAllowed = _allowedTlds.any((tld) => host.endsWith(tld));

        if (!isAllowed) {
          return 'Link blocked: Only .gov.in, .nic.in, .com, .in, .online and official portals are allowed.';
        }
      }
    }

    return null;
  }
}
