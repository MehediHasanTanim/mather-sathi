// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bengali Bangla (`bn`).
class AppLocalizationsBn extends AppLocalizations {
  AppLocalizationsBn([String locale = 'bn']) : super(locale);

  @override
  String get appName => 'কৃষি সহায়';

  @override
  String get tabScan => 'রোগ শনাক্ত';

  @override
  String get tabHistory => 'ইতিহাস';

  @override
  String get tabAlerts => 'সতর্কতা';

  @override
  String get tabSettings => 'সেটিংস';

  @override
  String get homeTitle => 'ছবি তুলে রোগ শনাক্ত করুন';

  @override
  String get historyTitle => 'ইতিহাস';

  @override
  String get alertsTitle => 'আপনার এলাকায় সাম্প্রতিক রোগবালাই';

  @override
  String get settingsTitle => 'সেটিংস';

  @override
  String get comingSoon => 'শীঘ্রই আসছে';

  @override
  String get tryAgain => 'আবার চেষ্টা করুন';

  @override
  String get loadError => 'কিছু ভুল হয়েছে। আবার চেষ্টা করুন';

  @override
  String get next => 'পরবর্তী';

  @override
  String get back => 'আগের';

  @override
  String get start => 'শুরু করুন';

  @override
  String get onboardingSlide1 => 'স্বাগতম! ফসলের রোগ এখন ঘরে বসেই শনাক্ত করুন';

  @override
  String get onboardingSlide2 => 'শুধু ছবি তুলুন — এআই বাকি কাজ করবে';

  @override
  String get onboardingSlide3 => 'সহজ বাংলায় চিকিৎসার পরামর্শ পান';

  @override
  String get onboardingSlide4 => 'আপনার জেলা বেছে নিন';

  @override
  String get selectDistrict => 'জেলা বেছে নিন';

  @override
  String get selectUpazila => 'উপজেলা বেছে নিন';

  @override
  String get selectDistrictFirst => 'আগে জেলা বেছে নিন';

  @override
  String get selectCrop => 'প্রধান ফসল বেছে নিন';

  @override
  String get searchHint => 'খুঁজুন';

  @override
  String get noResults => 'কিছু পাওয়া যায়নি';

  @override
  String get consentTitle => 'আপনার তথ্য ও গোপনীয়তা';

  @override
  String get consentReports => 'এলাকার রোগ সতর্কতায় অংশ নিন';

  @override
  String get consentReportsDesc =>
      'আপনার জেলা, উপজেলা, ফসল ও রোগের নাম বেনামে জানানো হবে। কোনো ছবি, নাম বা ফোন নম্বর যাবে না।';

  @override
  String get consentBackup => 'ছবি ক্লাউডে ব্যাকআপ রাখুন';

  @override
  String get consentBackupDesc =>
      'চালু করলে ছবি ৩০ দিন পর্যন্ত নিরাপদে জমা থাকবে।';

  @override
  String get consentContribute => 'অ্যাপ উন্নত করতে আমার ছবি ব্যবহারের অনুমতি';

  @override
  String get consentContributeDesc =>
      'চালু করলে আপনার ছবি দিয়ে ভবিষ্যতে রোগ শনাক্তকরণ আরও ভালো করা হতে পারে।';

  @override
  String get aiDisclosure =>
      'ইন্টারনেট থাকলে রোগ শনাক্ত করার সময় আপনার ছবিটি ছোট করে একটি এআই সেবায় পাঠানো হয়। ইন্টারনেট না থাকলে ছবি ফোনেই থাকে।';

  @override
  String get cropRice => 'ধান';

  @override
  String get cropJute => 'পাট';

  @override
  String get cropPotato => 'আলু';

  @override
  String get cropTomato => 'টমেটো';

  @override
  String get cropBrinjal => 'বেগুন';

  @override
  String get cropChili => 'মরিচ';

  @override
  String get cropOnion => 'পেঁয়াজ';

  @override
  String get cropMustard => 'সরিষা';

  @override
  String get banglaCheckTitle => 'বাংলা লেখা পরীক্ষা';

  @override
  String get banglaCheckSample =>
      'ক্ষেত্র, শস্য, দৃষ্টি, বৃষ্টি, ধ্বংস, কর্তৃপক্ষ, গ্রন্থ, ব্রাহ্মণবাড়িয়া, স্প্রে, ঝাঁঝালো';

  @override
  String banglaCheckDigits(String digits) {
    return 'সংখ্যা: $digits';
  }

  @override
  String get takePhoto => 'ছবি তুলুন';

  @override
  String get pickFromGallery => 'গ্যালারি থেকে নিন';

  @override
  String get otherCrop => 'অন্যান্য ফসল';

  @override
  String get otherCropHint => 'ফসলের নাম লিখুন';

  @override
  String get cancel => 'বাতিল';

  @override
  String get ok => 'ঠিক আছে';

  @override
  String get guidanceTitle => 'ছবি তুলুন';

  @override
  String get guidanceClose => 'পাতার কাছ থেকে তুলুন';

  @override
  String get guidanceLight => 'আলো যেন ভালো থাকে';

  @override
  String get guidanceFrame => 'রোগাক্রান্ত অংশ ফ্রেমে রাখুন';

  @override
  String get guidanceBlur => 'ঝাপসা ছবি দেবেন না';

  @override
  String get previewTitle => 'ছবি দেখুন';

  @override
  String get preparing => 'ছবি প্রস্তুত করা হচ্ছে…';

  @override
  String get retake => 'আবার তুলুন';

  @override
  String get analyze => 'বিশ্লেষণ করুন';

  @override
  String get selectCropFirst => 'আগে ফসল বেছে নিন';

  @override
  String get photoReady => 'ছবি ঠিক আছে';

  @override
  String get pickError => 'ছবি নেওয়া যায়নি। আবার চেষ্টা করুন';

  @override
  String get tipBlurry => 'ছবিটি একটু ঝাপসা — আবার চেষ্টা করুন';

  @override
  String get tipTooDark => 'আলো কম — আলোতে গিয়ে আবার ছবি তুলুন';

  @override
  String get tipTooSmall => 'ছবির মান কম — আরও কাছ থেকে তুলুন';

  @override
  String get tipNotAPlant =>
      'এটি গাছের ছবি বলে মনে হচ্ছে না — রোগাক্রান্ত পাতা ফ্রেমে রাখুন';

  @override
  String tipWrongCrop(String crop) {
    return 'এটি $crop বলে মনে হচ্ছে না — ফসল ঠিক আছে?';
  }
}
