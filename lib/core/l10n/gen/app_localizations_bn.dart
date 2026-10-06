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

  @override
  String get analyzing => 'বিশ্লেষণ করা হচ্ছে…';

  @override
  String get resultTitle => 'ফলাফল';

  @override
  String get resultHealthy => 'আপনার ফসলে কোনো পরিচিত রোগ দেখা যায়নি 🌿';

  @override
  String get resultUnknown => 'নিশ্চিত হওয়া যায়নি';

  @override
  String get resultUnknownHint =>
      'ছবিটি ভালো মানের হলে আবার চেষ্টা করুন, অথবা কৃষি কর্মকর্তার সাথে যোগাযোগ করুন';

  @override
  String get confHigh => 'নিশ্চিতমাত্রা বেশি ✅';

  @override
  String get confMedium => 'সম্ভাব্য রোগ ⚠️ — বিশেষজ্ঞকে দেখান';

  @override
  String get confLow =>
      'ছবি থেকে নিশ্চিত হওয়া যায়নি — আরও কাছ থেকে ছবি তুলুন';

  @override
  String get urgentTreatment => 'জরুরি চিকিৎসা দরকার';

  @override
  String get sectionDescription => 'রোগের বিবরণ';

  @override
  String get sectionSymptoms => 'লক্ষণসমূহ';

  @override
  String get sectionPrevention => 'প্রতিরোধ';

  @override
  String get seeExpert => 'কৃষি কর্মকর্তার পরামর্শ নিন';

  @override
  String get aiDisclaimer =>
      'এটি এআই-ভিত্তিক পরামর্শ; চূড়ান্ত সিদ্ধান্তের আগে কৃষি কর্মকর্তার সাথে কথা বলুন';

  @override
  String get draftKbBanner =>
      'এটি পরীক্ষামূলক ও যাচাই না করা তথ্য। এর ভিত্তিতে কোনো ওষুধ প্রয়োগ করবেন না।';

  @override
  String get needsInternet => 'এই ফসলের জন্য ইন্টারনেট দরকার';

  @override
  String get offlineModelMissing => 'ইন্টারনেট চালু করে আবার চেষ্টা করুন';

  @override
  String get dailyCapReached => 'আজকের সীমা শেষ — আগামীকাল আবার চেষ্টা করুন';

  @override
  String get diagnosisFailed => 'বিশ্লেষণ করা যায়নি। আবার চেষ্টা করুন';

  @override
  String get listen => 'শুনুন';

  @override
  String get pauseListening => 'থামান';

  @override
  String get resumeListening => 'আবার শুনুন';

  @override
  String get stopListening => 'বন্ধ করুন';

  @override
  String get ttsUnavailableTitle => 'বাংলা কণ্ঠস্বর পাওয়া যাচ্ছে না';

  @override
  String get ttsUnavailableBody =>
      'শুনতে হলে ফোনের সেটিংসে ‘Google টেক্সট-টু-স্পিচ’ অ্যাপে বাংলা ভাষার ভয়েস ডাউনলোড করুন।';

  @override
  String get ttsDiseaseName => 'রোগের নাম';

  @override
  String get ttsImmediate => 'এখনই যা করবেন';

  @override
  String get sectionTreatment => 'চিকিৎসা';

  @override
  String get immediateLabel => 'এখনই করুন';

  @override
  String get medicineLabel => 'ওষুধ';

  @override
  String get doseLabel => 'মাত্রা';

  @override
  String get intervalLabel => 'কতদিন পর পর';

  @override
  String get preHarvestLabel => 'ফসল তোলার আগে বিরতি';

  @override
  String preHarvestDays(String days) {
    return '$days দিন';
  }

  @override
  String get safetyLine =>
      'স্প্রের সময় মাস্ক ও গ্লাভস পরুন, ওষুধের মোড়কের নির্দেশনা পড়ুন';

  @override
  String get urgencyMedium => 'দ্রুত নজর দিন';

  @override
  String get urgencyLow => 'প্রতিরোধমূলক ব্যবস্থা নিন';

  @override
  String get wasCorrect => 'ফলাফলটি কি সঠিক ছিল?';

  @override
  String get yes => 'হ্যাঁ';

  @override
  String get no => 'না';

  @override
  String get whatWasIt => 'আসল রোগ কী ছিল?';

  @override
  String get dontKnow => 'জানি না';

  @override
  String get feedbackThanks => 'ধন্যবাদ, আপনার মতামত সংরক্ষিত হয়েছে';

  @override
  String get kbUpdated => 'তথ্য হালনাগাদ হয়েছে';

  @override
  String get kbEntryGone => 'এই রোগের বিস্তারিত তথ্য আর পাওয়া যাচ্ছে না';

  @override
  String get callExpert => 'কর্মকর্তার নম্বর';

  @override
  String get changeCrop => 'ফসল বদলান';

  @override
  String get healthyTipsTitle => 'প্রতিরোধের পরামর্শ';

  @override
  String get resultNotFound => 'ফলাফল পাওয়া যায়নি';

  @override
  String get generalAdviceTitle => 'সাধারণ পরামর্শ';

  @override
  String get savingResult => 'ফলাফল সংরক্ষণ করা হচ্ছে…';

  @override
  String get historyEmpty => 'এখনও কোনো ছবি পরীক্ষা করা হয়নি';

  @override
  String get historyHealthy => 'সুস্থ';

  @override
  String get historyUnknown => 'নিশ্চিত হওয়া যায়নি';

  @override
  String get badgeUrgent => 'জরুরি';

  @override
  String get badgeWatch => 'নজর রাখুন';

  @override
  String get badgePrevent => 'প্রতিরোধ';

  @override
  String get offlineMode => 'অফলাইন মোড';

  @override
  String get offlineCaveat => 'ইন্টারনেট চালু করে আরও নিখুঁত ফলাফল পান';
}
