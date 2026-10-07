import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mather_sathi/core/flags/remote_flags.dart';
import 'package:mather_sathi/core/l10n/gen/app_localizations_bn.dart';
import 'package:mather_sathi/features/kb/domain/kb_models.dart';
import 'package:mather_sathi/features/profile/domain/user_profile.dart';
import 'package:mather_sathi/features/tts/tts_controller.dart';
import 'package:mather_sathi/features/tts/tts_script.dart';
import 'package:mather_sathi/features/profile/providers/profile_provider.dart';
import 'package:mather_sathi/providers/core_providers.dart';

import '../../support/fakes.dart';
import '../../support/phase4_fakes.dart';

final _l = AppLocalizationsBn();

Disease disease({bool published = true, bool withMedicine = true}) => Disease(
      id: 'rice_blast', crop: 'rice', published: published, nameBn: 'ধানের ব্লাস্ট রোগ',
      descriptionBn: 'একটি ছত্রাকজনিত রোগ।', symptomsBn: const ['দাগ'], causeBn: 'ছত্রাক',
      urgency: Urgency.high, immediateBn: const ['সার বন্ধ রাখুন', 'ক্ষেত দেখুন', 'তৃতীয় কাজ'],
      medicine: withMedicine
          ? const [Medicine(nameBn: 'ওষুধ ক', activeIngredient: 'x', doseBn: '২ গ্রাম', intervalBn: '৭ দিন পর পর', preHarvestIntervalDays: 7)]
          : const [],
      preventionBn: const ['সুষম সার'], seeExpert: true,
    );

void main() {
  group('script', () {
    test('follows the spec template and ends with the safety line', () {
      final s = buildDiseaseScript(_l, disease());
      expect(s, contains('রোগের নাম: ধানের ব্লাস্ট রোগ।'));
      expect(s, contains('একটি ছত্রাকজনিত রোগ।'));
      expect(s, contains('এখনই যা করবেন: সার বন্ধ রাখুন। ক্ষেত দেখুন।'));
      expect(s, isNot(contains('তৃতীয় কাজ')), reason: 'only the first two immediate actions are read');
      expect(s, contains('ওষুধ: ওষুধ ক। মাত্রা: ২ গ্রাম।'));
      expect(s, contains('৭ দিন পর পর।'));
      expect(s, endsWith('${_l.safetyLine}।'));
      expect(s, isNot(contains('।।')));
    });

    test('no medicine means no medicine lines and no safety line', () {
      final s = buildDiseaseScript(_l, disease(withMedicine: false));
      expect(s, isNot(contains('ওষুধ:')));
      expect(s, isNot(contains(_l.safetyLine)));
    });

    test('draft (unreviewed) medicine is never read aloud', () {
      final s = buildDiseaseScript(_l, disease(published: false));
      expect(s, isNot(contains('ওষুধ ক')));
      expect(s, isNot(contains(_l.safetyLine)));
    });

    test('emoji and symbols are stripped for speech', () {
      expect(cleanForSpeech('আপনার ফসলে 🌿 রোগ নেই ⚠️'), 'আপনার ফসলে রোগ নেই');
      expect(buildMessageScript(_l.resultHealthy, ['ক', 'খ']), 'আপনার ফসলে কোনো পরিচিত রোগ দেখা যায়নি। ক। খ।');
    });

    test('splitSentences packs sentences up to the limit, never splits mid-sentence when it fits', () {
      expect(splitSentences('এক। দুই। তিন।', maxLen: 300), ['এক। দুই। তিন।']);
      expect(splitSentences('abcd. efgh. ijkl.', maxLen: 12), ['abcd. efgh.', 'ijkl.']);
      expect(splitSentences('', maxLen: 10), isEmpty);
    });

    test('an over-long sentence is split on spaces and every chunk fits', () {
      final long = List.filled(200, 'শব্দ').join(' ');
      final chunks = splitSentences(long, maxLen: 300);
      expect(chunks.length, greaterThan(1));
      expect(chunks.every((c) => c.length <= 300), isTrue);
      expect(chunks.join(' '), long);
    });
  });

  group('TtsController', () {
    late FakeTtsEngine engine;
    late ProviderContainer c;

    ProviderContainer make({String speed = 'normal', bool installed = true}) {
      engine = FakeTtsEngine(installed: installed);
      c = ProviderContainer(overrides: [
        ttsEngineProvider.overrideWithValue(engine),
        profileStoreProvider.overrideWithValue(FakeProfileStore(UserProfile(ttsSpeed: speed, onboardingDone: true))),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    // Three chunks: each > half the limit so the splitter cannot pack two together.
    final script = List.generate(3, (i) => '${'ক' * 200}$i।').join(' ');
    TtsController ctl() => c.read(ttsControllerProvider.notifier);
    TtsStatus status() => c.read(ttsControllerProvider);
    Future<void> tick() => Future<void>.delayed(Duration.zero);

    test('plays chunks in order, then returns to idle', () async {
      make();
      await c.read(profileProvider.future);
      await ctl().speak(script);
      expect(status(), TtsStatus.speaking);
      for (var i = 0; i < 3; i++) {
        await tick();
        engine.finishChunk();
      }
      await tick();
      expect(engine.spoken, hasLength(3));
      expect(engine.spoken.first, startsWith('ক'));
      expect(status(), TtsStatus.idle);
    });

    test('pause then resume continues from the current chunk', () async {
      make();
      await c.read(profileProvider.future);
      await ctl().speak(script);
      await tick();
      await tick();
      engine.finishChunk(); // chunk 0 done, chunk 1 now speaking
      await tick();
      expect(engine.spoken, hasLength(2));
      await ctl().pause();
      expect(status(), TtsStatus.paused);
      await ctl().resume();
      await tick();
      expect(status(), TtsStatus.speaking);
      expect(engine.spoken.length, 3);
      expect(engine.spoken[2], engine.spoken[1], reason: 'chunk 1 is repeated from its start, chunk 0 is not');
    });

    test('rapid pause/resume never plays two streams at once', () async {
      make();
      await c.read(profileProvider.future);
      await ctl().speak(script);
      await tick();
      await tick();
      for (var i = 0; i < 6; i++) {
        final p = ctl().pause();
        final r = ctl().resume();
        await Future.wait([p, r]);
        await tick();
      }
      await ctl().pause();
      await ctl().resume();
      await tick();
      expect(engine.maxActive, 1);
      expect(status(), TtsStatus.speaking);
    });

    test('stop resets to idle and the next speak starts from the top', () async {
      make();
      await c.read(profileProvider.future);
      await ctl().speak(script);
      await tick();
      await tick();
      engine.finishChunk();
      await tick();
      await ctl().stop();
      expect(status(), TtsStatus.idle);
      await ctl().speak(script);
      await tick();
      await tick();
      expect(engine.spoken.last, engine.spoken.first);
    });

    test('a missing Bangla voice yields the unavailable state until acknowledged', () async {
      make(installed: false);
      await c.read(profileProvider.future);
      await ctl().speak(script);
      expect(status(), TtsStatus.unavailable);
      expect(engine.spoken, isEmpty);
      ctl().acknowledgeUnavailable();
      expect(status(), TtsStatus.idle);
    });

    test('speech rate follows the profile speed setting', () async {
      for (final (speed, rate) in [('slow', RemoteFlags.defaults.ttsRateSlow), ('normal', RemoteFlags.defaults.ttsRateNormal), ('fast', RemoteFlags.defaults.ttsRateFast)]) {
        make(speed: speed);
        await c.read(profileProvider.future);
        await ctl().speak(script);
        await tick();
        await tick();
        expect(engine.rate, rate, reason: speed);
        await ctl().stop();
      }
    });

    test('pause is ignored unless speaking, resume unless paused', () async {
      make();
      await ctl().pause();
      await ctl().resume();
      expect(status(), TtsStatus.idle);
      expect(engine.spoken, isEmpty);
    });
  });
}
