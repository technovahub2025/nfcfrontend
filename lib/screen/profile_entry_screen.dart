import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/platform_tags.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/nfc_profile_service.dart';

class ProfileEntryScreen extends StatefulWidget {
  const ProfileEntryScreen({super.key});

  @override
  State<ProfileEntryScreen> createState() => _ProfileEntryScreenState();
}

class _ProfileEntryScreenState extends State<ProfileEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{
    for (final key in [
      'name',
      'phone',
      'email',
      'address',
      'bio',
      'googleBusiness',
      'instagram',
      'linkedin',
      'facebook',
    ])
      key: TextEditingController(),
  };
  bool _saving = false;
  Completer<String?>? _writeCompletion;
  String? _writeStatus;
  bool _loading = true;
  bool _loadFailed = false;
  bool _profilePageReady = false;
  String? _profileId;
  static const _savedProfileKey = 'html_profile_id';
  String? _error;
  String? _success;
  static const _ink = Color(0xFF16243B);
  static const _blue = Color(0xFF3165E8);
  static const _muted = Color(0xFF68778D);

  @override
  void initState() {
    super.initState();
    _loadSavedProfile();
  }

  Future<void> _loadSavedProfile() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
      _error = null;
    });
    try {
      final preferences = await SharedPreferences.getInstance();
      _profileId = preferences.getString(_savedProfileKey);
      if (_profileId != null) {
        final profile = await NFCProfileService.getProfile(_profileId!);
        if (!mounted) return;
        if (profile == null) {
          throw StateError('Saved profile could not be loaded');
        }
        for (final entry in _fields.entries) {
          entry.value.text = profile[entry.key]?.toString() ?? '';
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadFailed = true;
        _error = 'Your saved profile could not be loaded. Please retry.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openProfilePage() async {
    if (_profileId == null) return;
    try {
      final opened = await launchUrl(
        Uri.parse(NFCProfileService.generateProfileHtmlUrl(_profileId!)),
        mode: LaunchMode.externalApplication,
      );
      if (opened) return;
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _error = 'Profile saved. Tap View HTML Profile to try opening it again.';
    });
  }

  Future<void> _createNewUser() async {
    if (_saving || _loading) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!await preferences.remove(_savedProfileKey)) {
        throw StateError('Could not clear the saved profile selection.');
      }
      if (!mounted) return;
      _formKey.currentState?.reset();
      for (final controller in _fields.values) {
        controller.clear();
      }
      setState(() {
        _profileId = null;
        _profilePageReady = false;
        _loadFailed = false;
        _success = null;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not start a new user. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _cancelWrite();
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _cancelWrite() {
    final completion = _writeCompletion;
    if (completion != null && !completion.isCompleted) {
      completion.complete('Card write canceled.');
    }
  }

  Future<String?> _writeCard(String url) async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return 'Card was not written. Use the Android or iOS app on an NFC-enabled phone.';
    }
    final completion = Completer<String?>();
    _writeCompletion = completion;
    var handlingTag = false;
    var formatted = false;
    var sessionStarted = false;
    final message = NdefMessage([NdefRecord.createUri(Uri.parse(url))]);
    try {
      if (!await NfcManager.instance.isAvailable()) {
        return 'Card was not written. Enable NFC on your phone and try Save again.';
      }
      if (!mounted || completion.isCompleted) return 'Card write canceled.';
      setState(
        () => _writeStatus =
            'Hold your NFC card against the phone until the write is confirmed.',
      );
      sessionStarted = true;
      await NfcManager.instance.startSession(
        alertMessage:
            'Hold your NFC card against the phone to save your profile.',
        invalidateAfterFirstRead: false,
        onDiscovered: (tag) async {
          if (completion.isCompleted || handlingTag) return;
          handlingTag = true;
          try {
            final ndef = Ndef.from(tag);
            if (ndef == null) {
              final formatable = NdefFormatable.from(tag);
              if (formatable == null || formatted) {
                throw StateError('This card does not support NDEF.');
              }
              await formatable.format(message);
              formatted = true;
              if (mounted && !completion.isCompleted) {
                setState(
                  () => _writeStatus =
                      'Card formatted and written. Remove and tap the same card again to verify.',
                );
              }
              return;
            }
            if (!formatted) {
              if (!ndef.isWritable) throw StateError('This card is read-only.');
              if (message.byteLength > ndef.maxSize) {
                throw StateError(
                  'The profile link is too large for this card.',
                );
              }
              await ndef.write(message);
            }
            if (completion.isCompleted) return;
            final actual = await ndef.read();
            final expected = message.records.single;
            if (actual.records.length != 1 ||
                actual.records.single.typeNameFormat !=
                    expected.typeNameFormat ||
                !listEquals(actual.records.single.type, expected.type) ||
                !listEquals(
                  actual.records.single.identifier,
                  expected.identifier,
                ) ||
                !listEquals(actual.records.single.payload, expected.payload)) {
              throw StateError(
                'Card verification failed. Tap Save and try again.',
              );
            }
            if (!completion.isCompleted) completion.complete(null);
          } catch (error) {
            if (!completion.isCompleted) {
              completion.complete('Card write could not be confirmed: $error');
            }
          } finally {
            handlingTag = false;
          }
        },
        onError: (error) async {
          if (!completion.isCompleted) {
            completion.complete(
              'Card write could not be confirmed: ${error.message}',
            );
          }
        },
      );
      return await completion.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          const error =
              'Card write timed out. Tap Save and hold the card against the phone again.';
          if (!completion.isCompleted) completion.complete(error);
          return error;
        },
      );
    } catch (error) {
      return 'Card write could not be confirmed: $error';
    } finally {
      if (!completion.isCompleted) completion.complete('Card write stopped.');
      if (sessionStarted) {
        try {
          await NfcManager.instance.stopSession();
        } catch (_) {}
      }
      _writeCompletion = null;
      if (mounted) setState(() => _writeStatus = null);
    }
  }

  Future<void> _saveProfile() async {
    if (_saving ||
        _loading ||
        _loadFailed ||
        !_formKey.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
      _success = null;
      _profilePageReady = false;
    });
    final details = {
      for (final entry in _fields.entries) entry.key: entry.value.text.trim(),
    };
    final profile = _profileId == null
        ? await NFCProfileService.createProfile(
            name: details['name']!,
            phone: details['phone'],
            email: details['email'],
            address: details['address'],
            bio: details['bio'],
            googleBusiness: details['googleBusiness'],
            instagram: details['instagram'],
            linkedin: details['linkedin'],
            facebook: details['facebook'],
          )
        : await NFCProfileService.updateProfile(
            profileId: _profileId!,
            name: details['name'],
            phone: details['phone'],
            email: details['email'],
            address: details['address'],
            bio: details['bio'],
            googleBusiness: details['googleBusiness'],
            instagram: details['instagram'],
            linkedin: details['linkedin'],
            facebook: details['facebook'],
          );
    if (!mounted) return;
    String? html;
    if (profile != null) {
      _profileId ??= (profile['_id'] ?? profile['id'])?.toString();
      if (_profileId != null) {
        try {
          final preferences = await SharedPreferences.getInstance();
          await preferences.setString(_savedProfileKey, _profileId!);
        } catch (_) {
          if (mounted) {
            setState(
              () => _error =
                  'Profile saved, but its link could not be remembered on this device.',
            );
          }
        }
        html = await NFCProfileService.getProfileHtml(_profileId!);
      }
      if (!mounted) return;
    }
    setState(() {
      if (profile == null) {
        _error =
            'Backend save could not be confirmed. Check your connection and try again.';
      } else {
        _success = 'Your profile was saved successfully in the backend.';
        if (html == null) {
          _error =
              'Profile saved, but the HTML profile page could not be loaded.';
        } else {
          _profilePageReady = true;
          _success =
              'Your profile was saved successfully in the backend. HTML profile page is ready.';
        }
      }
    });
    if (profile != null && _profileId != null) {
      try {
        final url = NFCProfileService.generateProfileHtmlUrl(_profileId!);
        final writeError = await _writeCard(url);
        if (!mounted) return;
        setState(() {
          if (writeError == null) {
            _success =
                'Profile saved and written to your NFC card. Write verified successfully.';
          } else {
            _error = [
              ?_error,
              'Profile saved on the server. $writeError',
            ].join('\n');
          }
        });
      } catch (error) {
        if (mounted) {
          setState(
            () =>
                _error = 'Profile saved, but the card was not written: $error',
          );
        }
      }
    } else if (profile != null) {
      setState(
        () => _error =
            'Profile saved, but no profile ID was returned. Card was not written.',
      );
    }
    if (mounted) setState(() => _saving = false);
  }

  Widget _field(
    String key,
    String label, {
    TextInputType keyboard = TextInputType.text,
    int lines = 1,
    int? maxLength,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: _fields[key],
        enabled: !_saving && !_loading && !_loadFailed,
        keyboardType: lines > 1 ? TextInputType.multiline : keyboard,
        maxLines: lines,
        maxLength: maxLength,
        textInputAction: lines > 1
            ? TextInputAction.newline
            : TextInputAction.next,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(_fieldIcon(key), size: 20, color: _muted),
          filled: true,
          fillColor: const Color(0xFFF7F9FC),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
          labelStyle: const TextStyle(color: _muted),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE4E9F1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _blue, width: 1.5),
          ),
          counterText: '',
        ),
        validator: (value) {
          final text = value?.trim() ?? '';
          if (key == 'name' && text.isEmpty) return 'Please enter your name';
          if (key == 'email' &&
              text.isNotEmpty &&
              !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)) {
            return 'Please enter a valid email address';
          }
          return null;
        },
      ),
    );
  }

  IconData _fieldIcon(String key) => switch (key) {
    'name' => Icons.person_outline_rounded,
    'phone' => Icons.phone_outlined,
    'email' => Icons.mail_outline_rounded,
    'address' => Icons.location_on_outlined,
    'bio' => Icons.notes_rounded,
    'googleBusiness' => Icons.storefront_outlined,
    _ => Icons.link_rounded,
  };

  Widget _section(String title, String subtitle, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5EAF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: _muted, height: 1.5)),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _preview() {
    return AnimatedBuilder(
      animation: Listenable.merge(_fields.values),
      builder: (context, _) {
        final name = _fields['name']!.text.trim();
        final bio = _fields['bio']!.text.trim();
        final email = _fields['email']!.text.trim();
        final phone = _fields['phone']!.text.trim();
        return Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF172B4E), Color(0xFF2453A1)],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: _blue.withValues(alpha: 0.15),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.nfc_rounded, color: Color(0xFFAAC9FF)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'YOUR DIGITAL CARD',
                      style: TextStyle(
                        color: Color(0xFFAAC9FF),
                        fontSize: 11,
                        letterSpacing: 1.8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: name.isEmpty
                    ? const Icon(
                        Icons.person_outline_rounded,
                        size: 32,
                        color: Colors.white,
                      )
                    : Text(
                        String.fromCharCode(name.runes.first).toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
              const SizedBox(height: 20),
              Text(
                name.isEmpty ? 'Your name here' : name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                bio.isEmpty ? 'A little about you. A new way to connect.' : bio,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFFCDDDF7), height: 1.6),
              ),
              const SizedBox(height: 24),
              Divider(color: Colors.white.withValues(alpha: 0.16)),
              if (email.isNotEmpty || phone.isNotEmpty) ...[
                const SizedBox(height: 12),
                if (email.isNotEmpty)
                  _previewContact(Icons.mail_outline, email),
                if (phone.isNotEmpty)
                  _previewContact(Icons.phone_outlined, phone),
              ],
              const SizedBox(height: 16),
              const Text(
                'One tap. A lasting connection.',
                style: TextStyle(color: Color(0xFFAAC9FF), fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _previewContact(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFFAAC9FF)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
      ],
    ),
  );

  Widget _notice(String message, {bool error = false}) {
    final color = error ? const Color(0xFFAF3434) : const Color(0xFF217553);
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              error ? Icons.info_outline : Icons.check_circle_outline,
              color: color,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: TextStyle(color: color, height: 1.5)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F6FB),
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 76,
        titleSpacing: 24,
        title: const Row(
          children: [
            Icon(Icons.nfc_rounded, color: _blue, size: 28),
            SizedBox(width: 10),
            Text(
              'NFC Connect',
              style: TextStyle(
                color: _ink,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: Form(
                key: _formKey,
                onChanged: () {
                  if (_success != null || _error != null) {
                    setState(() {
                      _success = null;
                      _error = null;
                    });
                  }
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _profileId == null
                          ? 'Create Your NFC Profile'
                          : 'Edit Current NFC Profile',
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Make every introduction count. Build a profile that travels with you.',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 15,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: _saving || _loading ? null : _createNewUser,
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('Create New User'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _profileId == null
                          ? 'Save will create a separate profile for this user.'
                          : 'Save updates the current user. For another person, tap Create New User first.',
                      style: const TextStyle(color: _muted, height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final form = Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _section(
                              'Personal details',
                              'Start with the essentials people need to reach you.',
                              [
                                _field('name', 'Name *', maxLength: 120),
                                _field(
                                  'phone',
                                  'Phone',
                                  keyboard: TextInputType.phone,
                                  maxLength: 40,
                                ),
                                _field(
                                  'email',
                                  'Email',
                                  keyboard: TextInputType.emailAddress,
                                  maxLength: 150,
                                ),
                                _field(
                                  'address',
                                  'Address',
                                  lines: 2,
                                  maxLength: 250,
                                ),
                                _field('bio', 'Bio', lines: 3, maxLength: 500),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _section(
                              'Stay connected',
                              'Add your social profiles and business links.',
                              [
                                ExpansionTile(
                                  title: const Text('Social links (optional)'),
                                  tilePadding: EdgeInsets.zero,
                                  shape: const Border(),
                                  collapsedShape: const Border(),
                                  iconColor: _blue,
                                  children: [
                                    _field(
                                      'googleBusiness',
                                      'Google Business',
                                      maxLength: 150,
                                    ),
                                    _field(
                                      'instagram',
                                      'Instagram',
                                      maxLength: 150,
                                    ),
                                    _field(
                                      'linkedin',
                                      'LinkedIn',
                                      maxLength: 250,
                                    ),
                                    _field(
                                      'facebook',
                                      'Facebook',
                                      maxLength: 250,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            if (_success != null) _notice(_success!),
                            if (_error != null) _notice(_error!, error: true),
                            if (_writeStatus != null) ...[
                              _notice(_writeStatus!),
                              TextButton(
                                onPressed: _cancelWrite,
                                child: const Text('Cancel card write'),
                              ),
                            ],
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _blue,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: const Color(
                                  0xFFDDE5F3,
                                ),
                                minimumSize: const Size.fromHeight(56),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              onPressed: _saving || _loading || _loadFailed
                                  ? null
                                  : _saveProfile,
                              icon: _saving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: _blue,
                                      ),
                                    )
                                  : const Icon(Icons.check_rounded),
                              label: Text(
                                _saving
                                    ? (_writeStatus == null
                                          ? 'Saving...'
                                          : 'Writing card...')
                                    : 'Save Profile',
                              ),
                            ),
                            if (_loading) const LinearProgressIndicator(),
                            if (_loadFailed)
                              TextButton(
                                onPressed: _loadSavedProfile,
                                child: const Text('Retry loading profile'),
                              ),
                            if (_profilePageReady) ...[
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _blue,
                                  minimumSize: const Size.fromHeight(52),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: _saving ? null : _openProfilePage,
                                icon: const Icon(Icons.open_in_browser),
                                label: const Text('View HTML Profile'),
                              ),
                            ],
                            const SizedBox(height: 14),
                            const Text(
                              'Tap Save, then hold your NFC card against the phone to write your profile link.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _muted,
                                fontSize: 12,
                                height: 1.5,
                              ),
                            ),
                          ],
                        );
                        if (constraints.maxWidth < 840) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _preview(),
                              const SizedBox(height: 24),
                              form,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 340,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _preview(),
                                  const SizedBox(height: 24),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    child: Text(
                                      'A preview of your details. Your saved profile opens as a shareable web page.',
                                      style: TextStyle(
                                        color: _muted,
                                        height: 1.6,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 32),
                            Expanded(child: form),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
