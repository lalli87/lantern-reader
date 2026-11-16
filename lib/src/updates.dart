import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app.dart';

const githubRepo = 'lalli87/lantern-reader';
const releasesPage = 'https://github.com/$githubRepo/releases';
const playStorePage = 'https://play.google.com/store/apps/details?id=com.lalli87.lantern_reader';

/// The running app's version, read once from the installed package.
class AppVersion {
  AppVersion(this.version, this.build, this.fromPlay);
  final String version;
  final String build;
  final bool fromPlay;
  String get label => build.isEmpty || build == '0' ? version : '$version ($build)';

  static AppVersion? _cached;
  static Future<AppVersion> get() async {
    if (_cached != null) return _cached!;
    try {
      final i = await PackageInfo.fromPlatform();
      return _cached = AppVersion(i.version, i.buildNumber, i.installerStore == 'com.android.vending');
    } catch (_) {
      return AppVersion('?', '', false);
    }
  }
}

class ReleaseInfo {
  ReleaseInfo({required this.version, required this.notes, required this.pageUrl, this.apkUrl, this.apkSize = 0, this.published});
  final String version;
  final String notes;
  final String pageUrl;
  final String? apkUrl;
  final int apkSize;
  final DateTime? published;
}

/// Compares dotted versions such as 0.2.10 and 0.2.9 numerically. Positive when [a] is newer.
int compareVersions(String a, String b) {
  List<int> parts(String v) => v.replaceFirst(RegExp(r'^v'), '').split(RegExp(r'[.+\-]')).map((p) => int.tryParse(p) ?? 0).toList();
  final x = parts(a), y = parts(b);
  for (var i = 0; i < x.length || i < y.length; i++) {
    final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (d != 0) return d;
  }
  return 0;
}

/// Reads a GitHub "latest release" response.
ReleaseInfo parseRelease(Map<String, dynamic> j) {
  String? apk;
  var size = 0;
  for (final a in (j['assets'] as List? ?? const [])) {
    final name = (a['name'] as String? ?? '').toLowerCase();
    if (name.endsWith('.apk')) {
      apk = a['browser_download_url'] as String?;
      size = (a['size'] as num?)?.toInt() ?? 0;
      break;
    }
  }
  // CI appends file descriptions to the commit message; keep only the change description.
  var notes = (j['body'] as String? ?? '').split(RegExp(r'\n- \*\*lantern-reader\.')).first;
  notes = notes.replaceAll(RegExp(r'\n*(Co-Authored-By|Claude-Session):.*', caseSensitive: false), '').trim();
  return ReleaseInfo(
    version: (j['tag_name'] as String? ?? '').replaceFirst(RegExp(r'^v'), ''),
    notes: notes,
    pageUrl: j['html_url'] as String? ?? releasesPage,
    apkUrl: apk,
    apkSize: size,
    published: DateTime.tryParse(j['published_at'] as String? ?? ''),
  );
}

/// Asks GitHub for the newest release. Throws when offline or GitHub refuses.
Future<ReleaseInfo> fetchLatestRelease() async {
  final r = await http.get(
    Uri.parse('https://api.github.com/repos/$githubRepo/releases/latest'),
    headers: {'Accept': 'application/vnd.github+json'},
  ).timeout(const Duration(seconds: 15));
  if (r.statusCode != 200) throw Exception('GitHub answered ${r.statusCode}');
  return parseRelease(jsonDecode(r.body) as Map<String, dynamic>);
}

/// Checks for a newer version. With [manual] the result is always reported; otherwise only a new,
/// not-skipped version is shown, at most once a day.
Future<void> checkForUpdates(BuildContext context, {bool manual = false}) async {
  if (!manual) {
    if (!settings.autoUpdateCheck) return;
    final last = DateTime.fromMillisecondsSinceEpoch(settings.lastUpdateCheck);
    if (DateTime.now().difference(last) < const Duration(hours: 20)) return;
  }
  final current = await AppVersion.get();
  final ReleaseInfo latest;
  try {
    latest = await fetchLatestRelease();
  } catch (e) {
    if (manual && context.mounted) toast(context, 'Could not check for updates. Check your connection and try again.');
    return;
  }
  settings.set('lastUpdateCheck', DateTime.now().millisecondsSinceEpoch);
  settings.set('latestKnownVersion', latest.version);
  if (!context.mounted) return;
  final newer = compareVersions(latest.version, current.version) > 0;
  if (!newer) {
    if (manual) toast(context, 'You have the latest version (${current.version}).');
    return;
  }
  if (!manual && settings.skippedVersion == latest.version) return;
  await showUpdateDialog(context, current, latest);
}

Future<void> showUpdateDialog(BuildContext context, AppVersion current, ReleaseInfo latest) async {
  final mb = latest.apkSize > 0 ? ' · ${(latest.apkSize / 1e6).toStringAsFixed(0)} MB' : '';
  final choice = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text('Version ${latest.version} is available'),
      content: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('You have ${current.version}$mb', style: Theme.of(c).textTheme.bodySmall),
          const SizedBox(height: 12),
          const Text("What's new", style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(latest.notes.isEmpty ? 'No notes for this version.' : latest.notes),
          if (!current.fromPlay) ...[
            const SizedBox(height: 12),
            Text('The APK downloads in your browser. Open it from the notification to install over this version; '
                'your library stays.', style: Theme.of(c).textTheme.bodySmall),
          ],
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, 'skip'), child: const Text('Skip this version')),
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Later')),
        FilledButton(onPressed: () => Navigator.pop(c, 'get'), child: Text(current.fromPlay ? 'Open Play Store' : 'Download')),
      ],
    ),
  );
  if (choice == 'skip') {
    settings.set('skippedVersion', latest.version);
  } else if (choice == 'get') {
    final url = current.fromPlay ? playStorePage : (latest.apkUrl ?? latest.pageUrl);
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication).catchError((_) => false);
    if (!ok && context.mounted) toast(context, 'Could not open $url');
  }
}

Future<void> openReleasesPage(BuildContext context) async {
  final ok = await launchUrl(Uri.parse(releasesPage), mode: LaunchMode.externalApplication).catchError((_) => false);
  if (!ok && context.mounted) toast(context, 'Could not open the releases page.');
}
