// lib/shared/widgets/privacy_policy_dialog.dart
//
// Concise honest privacy policy. The app stores game-state locally on
// the device, makes no network calls, transmits nothing automatically.
// Crash reports are local-only and only leave the device if the user
// explicitly copies them from Diagnostics.
//
// Strings are inline English: this matches the broader space_math
// localization policy and avoids fragmenting ARB across many small
// edits. The voc variant is in the voc repo (German source).

import 'package:flutter/material.dart';

import '../../core/theme/space_theme.dart';

class PrivacyPolicyDialog extends StatelessWidget {
  const PrivacyPolicyDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: SpaceTheme.deepSpace,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.shield_outlined,
                      color: SpaceTheme.starYellow, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Privacy Policy',
                      style: SpaceTheme.headlineStyle.copyWith(fontSize: 22),
                    ),
                  ),
                  IconButton(
                    autofocus: true,
                    onPressed: () => Navigator.of(context).pop(),
                    icon:
                        const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
              const Divider(color: Colors.white24),
              const Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 8),
                      _PolicySection(
                        title: 'Short version',
                        body:
                            'This app stores your child\'s game progress on '
                            'their device. Nothing is uploaded to any server. '
                            'Nothing is shared with any third party. We have '
                            'no analytics, no advertising, no tracking, no '
                            'account system, no personally identifying '
                            'information collected — ever.',
                      ),
                      _PolicySection(
                        title: 'What is stored, where',
                        body:
                            'The following live on this device only, in '
                            'standard Flutter SharedPreferences and one log '
                            'file in the app\'s sandboxed documents '
                            'directory:\n\n'
                            '• Game progress (score, current level per '
                            'game, achievements unlocked)\n'
                            '• Spaced-repetition state (which math problems '
                            'have been seen, how often, how well)\n'
                            '• Cognitive-profile statistics (per-skill '
                            'attempt and success counts)\n'
                            '• Streak counter (current and longest '
                            'consecutive-day play streak)\n'
                            '• Settings (selected grade, language, '
                            'sound on/off, custom problem ranges)\n'
                            '• A rolling 50-entry crash log, written only '
                            'when the app actually crashes\n\n'
                            'None of this data identifies your child. No '
                            'name, no email, no birthdate, no device ID, '
                            'no IP address is collected or stored.',
                      ),
                      _PolicySection(
                        title: 'Network',
                        body:
                            'This app makes no automatic network calls. '
                            'It does not phone home. The vocabulary content '
                            'is bundled inside the app at install time, not '
                            'fetched.\n\n'
                            'The only outbound network requests happen if '
                            'you tap an external link in the Imprint (e.g. '
                            'the publisher\'s website), which opens your '
                            'system browser.',
                      ),
                      _PolicySection(
                        title: 'Crash reports',
                        body:
                            'When the app crashes, a short technical record '
                            '(error message, stack trace) is written to a '
                            'local file. You can view it in Settings → '
                            'Diagnostics. The log never leaves your device '
                            'unless you choose to share it by tapping "Copy '
                            'to clipboard" and pasting it somewhere yourself '
                            '(e.g. into an email or bug report).',
                      ),
                      _PolicySection(
                        title: 'Children (COPPA, GDPR-K)',
                        body:
                            'This app is designed for primary-school '
                            'learners. We have intentionally designed it '
                            'with COPPA (US) and GDPR-K (EU, including '
                            'Article 8 in Germany) in mind: no personal '
                            'data of any kind is collected, processed, or '
                            'transmitted, which means the consent '
                            'requirements of those frameworks do not apply '
                            'to this app. We collect nothing — there is '
                            'nothing to consent to.',
                      ),
                      _PolicySection(
                        title: 'Your right to clear data',
                        body:
                            'You can delete all locally-stored data at any '
                            'time from Settings → Reset all data. This '
                            'wipes every value listed above. You can also '
                            'uninstall the app — Flutter\'s standard '
                            'sandbox storage is removed automatically by '
                            'iOS and Android when you do.',
                      ),
                      _PolicySection(
                        title: 'Changes',
                        body:
                            'If we ever do start collecting data — for '
                            'example, to add a backup feature or '
                            'multi-device sync — this policy will be '
                            'updated, the changes will be highlighted on '
                            'first launch after the update, and any new '
                            'data collection will be opt-in.',
                      ),
                      SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  final String title;
  final String body;
  const _PolicySection({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: SpaceTheme.titleStyle
                .copyWith(fontSize: 16, color: SpaceTheme.starYellow),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: SpaceTheme.bodyStyle.copyWith(fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }
}
