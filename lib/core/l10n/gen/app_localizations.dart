import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bn.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('bn')];

  /// No description provided for @appName.
  ///
  /// In bn, this message translates to:
  /// **'কৃষি সহায়'**
  String get appName;

  /// No description provided for @tabScan.
  ///
  /// In bn, this message translates to:
  /// **'রোগ শনাক্ত'**
  String get tabScan;

  /// No description provided for @tabHistory.
  ///
  /// In bn, this message translates to:
  /// **'ইতিহাস'**
  String get tabHistory;

  /// No description provided for @tabAlerts.
  ///
  /// In bn, this message translates to:
  /// **'সতর্কতা'**
  String get tabAlerts;

  /// No description provided for @tabSettings.
  ///
  /// In bn, this message translates to:
  /// **'সেটিংস'**
  String get tabSettings;

  /// No description provided for @homeTitle.
  ///
  /// In bn, this message translates to:
  /// **'ছবি তুলে রোগ শনাক্ত করুন'**
  String get homeTitle;

  /// No description provided for @historyTitle.
  ///
  /// In bn, this message translates to:
  /// **'ইতিহাস'**
  String get historyTitle;

  /// No description provided for @alertsTitle.
  ///
  /// In bn, this message translates to:
  /// **'আপনার এলাকায় সাম্প্রতিক রোগবালাই'**
  String get alertsTitle;

  /// No description provided for @settingsTitle.
  ///
  /// In bn, this message translates to:
  /// **'সেটিংস'**
  String get settingsTitle;

  /// No description provided for @comingSoon.
  ///
  /// In bn, this message translates to:
  /// **'শীঘ্রই আসছে'**
  String get comingSoon;

  /// No description provided for @tryAgain.
  ///
  /// In bn, this message translates to:
  /// **'আবার চেষ্টা করুন'**
  String get tryAgain;

  /// No description provided for @loadError.
  ///
  /// In bn, this message translates to:
  /// **'কিছু ভুল হয়েছে। আবার চেষ্টা করুন'**
  String get loadError;

  /// No description provided for @next.
  ///
  /// In bn, this message translates to:
  /// **'পরবর্তী'**
  String get next;

  /// No description provided for @back.
  ///
  /// In bn, this message translates to:
  /// **'আগের'**
  String get back;

  /// No description provided for @start.
  ///
  /// In bn, this message translates to:
  /// **'শুরু করুন'**
  String get start;

  /// No description provided for @onboardingSlide1.
  ///
  /// In bn, this message translates to:
  /// **'স্বাগতম! ফসলের রোগ এখন ঘরে বসেই শনাক্ত করুন'**
  String get onboardingSlide1;

  /// No description provided for @onboardingSlide2.
  ///
  /// In bn, this message translates to:
  /// **'শুধু ছবি তুলুন — এআই বাকি কাজ করবে'**
  String get onboardingSlide2;

  /// No description provided for @onboardingSlide3.
  ///
  /// In bn, this message translates to:
  /// **'সহজ বাংলায় চিকিৎসার পরামর্শ পান'**
  String get onboardingSlide3;

  /// No description provided for @onboardingSlide4.
  ///
  /// In bn, this message translates to:
  /// **'আপনার জেলা বেছে নিন'**
  String get onboardingSlide4;

  /// No description provided for @selectDistrict.
  ///
  /// In bn, this message translates to:
  /// **'জেলা বেছে নিন'**
  String get selectDistrict;

  /// No description provided for @selectUpazila.
  ///
  /// In bn, this message translates to:
  /// **'উপজেলা বেছে নিন'**
  String get selectUpazila;

  /// No description provided for @selectDistrictFirst.
  ///
  /// In bn, this message translates to:
  /// **'আগে জেলা বেছে নিন'**
  String get selectDistrictFirst;

  /// No description provided for @selectCrop.
  ///
  /// In bn, this message translates to:
  /// **'প্রধান ফসল বেছে নিন'**
  String get selectCrop;

  /// No description provided for @searchHint.
  ///
  /// In bn, this message translates to:
  /// **'খুঁজুন'**
  String get searchHint;

  /// No description provided for @noResults.
  ///
  /// In bn, this message translates to:
  /// **'কিছু পাওয়া যায়নি'**
  String get noResults;

  /// No description provided for @consentTitle.
  ///
  /// In bn, this message translates to:
  /// **'আপনার তথ্য ও গোপনীয়তা'**
  String get consentTitle;

  /// No description provided for @consentReports.
  ///
  /// In bn, this message translates to:
  /// **'এলাকার রোগ সতর্কতায় অংশ নিন'**
  String get consentReports;

  /// No description provided for @consentReportsDesc.
  ///
  /// In bn, this message translates to:
  /// **'আপনার জেলা, উপজেলা, ফসল ও রোগের নাম বেনামে জানানো হবে। কোনো ছবি, নাম বা ফোন নম্বর যাবে না।'**
  String get consentReportsDesc;

  /// No description provided for @consentBackup.
  ///
  /// In bn, this message translates to:
  /// **'ছবি ক্লাউডে ব্যাকআপ রাখুন'**
  String get consentBackup;

  /// No description provided for @consentBackupDesc.
  ///
  /// In bn, this message translates to:
  /// **'চালু করলে ছবি ৩০ দিন পর্যন্ত নিরাপদে জমা থাকবে।'**
  String get consentBackupDesc;

  /// No description provided for @consentContribute.
  ///
  /// In bn, this message translates to:
  /// **'অ্যাপ উন্নত করতে আমার ছবি ব্যবহারের অনুমতি'**
  String get consentContribute;

  /// No description provided for @consentContributeDesc.
  ///
  /// In bn, this message translates to:
  /// **'চালু করলে আপনার ছবি দিয়ে ভবিষ্যতে রোগ শনাক্তকরণ আরও ভালো করা হতে পারে।'**
  String get consentContributeDesc;

  /// No description provided for @aiDisclosure.
  ///
  /// In bn, this message translates to:
  /// **'ইন্টারনেট থাকলে রোগ শনাক্ত করার সময় আপনার ছবিটি ছোট করে একটি এআই সেবায় পাঠানো হয়। ইন্টারনেট না থাকলে ছবি ফোনেই থাকে।'**
  String get aiDisclosure;

  /// No description provided for @cropRice.
  ///
  /// In bn, this message translates to:
  /// **'ধান'**
  String get cropRice;

  /// No description provided for @cropJute.
  ///
  /// In bn, this message translates to:
  /// **'পাট'**
  String get cropJute;

  /// No description provided for @cropPotato.
  ///
  /// In bn, this message translates to:
  /// **'আলু'**
  String get cropPotato;

  /// No description provided for @cropTomato.
  ///
  /// In bn, this message translates to:
  /// **'টমেটো'**
  String get cropTomato;

  /// No description provided for @cropBrinjal.
  ///
  /// In bn, this message translates to:
  /// **'বেগুন'**
  String get cropBrinjal;

  /// No description provided for @cropChili.
  ///
  /// In bn, this message translates to:
  /// **'মরিচ'**
  String get cropChili;

  /// No description provided for @cropOnion.
  ///
  /// In bn, this message translates to:
  /// **'পেঁয়াজ'**
  String get cropOnion;

  /// No description provided for @cropMustard.
  ///
  /// In bn, this message translates to:
  /// **'সরিষা'**
  String get cropMustard;

  /// No description provided for @banglaCheckTitle.
  ///
  /// In bn, this message translates to:
  /// **'বাংলা লেখা পরীক্ষা'**
  String get banglaCheckTitle;

  /// No description provided for @banglaCheckSample.
  ///
  /// In bn, this message translates to:
  /// **'ক্ষেত্র, শস্য, দৃষ্টি, বৃষ্টি, ধ্বংস, কর্তৃপক্ষ, গ্রন্থ, ব্রাহ্মণবাড়িয়া, স্প্রে, ঝাঁঝালো'**
  String get banglaCheckSample;

  /// No description provided for @banglaCheckDigits.
  ///
  /// In bn, this message translates to:
  /// **'সংখ্যা: {digits}'**
  String banglaCheckDigits(String digits);

  /// No description provided for @takePhoto.
  ///
  /// In bn, this message translates to:
  /// **'ছবি তুলুন'**
  String get takePhoto;

  /// No description provided for @pickFromGallery.
  ///
  /// In bn, this message translates to:
  /// **'গ্যালারি থেকে নিন'**
  String get pickFromGallery;

  /// No description provided for @otherCrop.
  ///
  /// In bn, this message translates to:
  /// **'অন্যান্য ফসল'**
  String get otherCrop;

  /// No description provided for @otherCropHint.
  ///
  /// In bn, this message translates to:
  /// **'ফসলের নাম লিখুন'**
  String get otherCropHint;

  /// No description provided for @cancel.
  ///
  /// In bn, this message translates to:
  /// **'বাতিল'**
  String get cancel;

  /// No description provided for @ok.
  ///
  /// In bn, this message translates to:
  /// **'ঠিক আছে'**
  String get ok;

  /// No description provided for @guidanceTitle.
  ///
  /// In bn, this message translates to:
  /// **'ছবি তুলুন'**
  String get guidanceTitle;

  /// No description provided for @guidanceClose.
  ///
  /// In bn, this message translates to:
  /// **'পাতার কাছ থেকে তুলুন'**
  String get guidanceClose;

  /// No description provided for @guidanceLight.
  ///
  /// In bn, this message translates to:
  /// **'আলো যেন ভালো থাকে'**
  String get guidanceLight;

  /// No description provided for @guidanceFrame.
  ///
  /// In bn, this message translates to:
  /// **'রোগাক্রান্ত অংশ ফ্রেমে রাখুন'**
  String get guidanceFrame;

  /// No description provided for @guidanceBlur.
  ///
  /// In bn, this message translates to:
  /// **'ঝাপসা ছবি দেবেন না'**
  String get guidanceBlur;

  /// No description provided for @previewTitle.
  ///
  /// In bn, this message translates to:
  /// **'ছবি দেখুন'**
  String get previewTitle;

  /// No description provided for @preparing.
  ///
  /// In bn, this message translates to:
  /// **'ছবি প্রস্তুত করা হচ্ছে…'**
  String get preparing;

  /// No description provided for @retake.
  ///
  /// In bn, this message translates to:
  /// **'আবার তুলুন'**
  String get retake;

  /// No description provided for @analyze.
  ///
  /// In bn, this message translates to:
  /// **'বিশ্লেষণ করুন'**
  String get analyze;

  /// No description provided for @selectCropFirst.
  ///
  /// In bn, this message translates to:
  /// **'আগে ফসল বেছে নিন'**
  String get selectCropFirst;

  /// No description provided for @photoReady.
  ///
  /// In bn, this message translates to:
  /// **'ছবি ঠিক আছে'**
  String get photoReady;

  /// No description provided for @pickError.
  ///
  /// In bn, this message translates to:
  /// **'ছবি নেওয়া যায়নি। আবার চেষ্টা করুন'**
  String get pickError;

  /// No description provided for @tipBlurry.
  ///
  /// In bn, this message translates to:
  /// **'ছবিটি একটু ঝাপসা — আবার চেষ্টা করুন'**
  String get tipBlurry;

  /// No description provided for @tipTooDark.
  ///
  /// In bn, this message translates to:
  /// **'আলো কম — আলোতে গিয়ে আবার ছবি তুলুন'**
  String get tipTooDark;

  /// No description provided for @tipTooSmall.
  ///
  /// In bn, this message translates to:
  /// **'ছবির মান কম — আরও কাছ থেকে তুলুন'**
  String get tipTooSmall;

  /// No description provided for @tipNotAPlant.
  ///
  /// In bn, this message translates to:
  /// **'এটি গাছের ছবি বলে মনে হচ্ছে না — রোগাক্রান্ত পাতা ফ্রেমে রাখুন'**
  String get tipNotAPlant;

  /// No description provided for @tipWrongCrop.
  ///
  /// In bn, this message translates to:
  /// **'এটি {crop} বলে মনে হচ্ছে না — ফসল ঠিক আছে?'**
  String tipWrongCrop(String crop);

  /// No description provided for @analyzing.
  ///
  /// In bn, this message translates to:
  /// **'বিশ্লেষণ করা হচ্ছে…'**
  String get analyzing;

  /// No description provided for @resultTitle.
  ///
  /// In bn, this message translates to:
  /// **'ফলাফল'**
  String get resultTitle;

  /// No description provided for @resultHealthy.
  ///
  /// In bn, this message translates to:
  /// **'আপনার ফসলে কোনো পরিচিত রোগ দেখা যায়নি 🌿'**
  String get resultHealthy;

  /// No description provided for @resultUnknown.
  ///
  /// In bn, this message translates to:
  /// **'নিশ্চিত হওয়া যায়নি'**
  String get resultUnknown;

  /// No description provided for @resultUnknownHint.
  ///
  /// In bn, this message translates to:
  /// **'ছবিটি ভালো মানের হলে আবার চেষ্টা করুন, অথবা কৃষি কর্মকর্তার সাথে যোগাযোগ করুন'**
  String get resultUnknownHint;

  /// No description provided for @confHigh.
  ///
  /// In bn, this message translates to:
  /// **'নিশ্চিতমাত্রা বেশি ✅'**
  String get confHigh;

  /// No description provided for @confMedium.
  ///
  /// In bn, this message translates to:
  /// **'সম্ভাব্য রোগ ⚠️ — বিশেষজ্ঞকে দেখান'**
  String get confMedium;

  /// No description provided for @confLow.
  ///
  /// In bn, this message translates to:
  /// **'ছবি থেকে নিশ্চিত হওয়া যায়নি — আরও কাছ থেকে ছবি তুলুন'**
  String get confLow;

  /// No description provided for @urgentTreatment.
  ///
  /// In bn, this message translates to:
  /// **'জরুরি চিকিৎসা দরকার'**
  String get urgentTreatment;

  /// No description provided for @sectionDescription.
  ///
  /// In bn, this message translates to:
  /// **'রোগের বিবরণ'**
  String get sectionDescription;

  /// No description provided for @sectionSymptoms.
  ///
  /// In bn, this message translates to:
  /// **'লক্ষণসমূহ'**
  String get sectionSymptoms;

  /// No description provided for @sectionPrevention.
  ///
  /// In bn, this message translates to:
  /// **'প্রতিরোধ'**
  String get sectionPrevention;

  /// No description provided for @seeExpert.
  ///
  /// In bn, this message translates to:
  /// **'কৃষি কর্মকর্তার পরামর্শ নিন'**
  String get seeExpert;

  /// No description provided for @aiDisclaimer.
  ///
  /// In bn, this message translates to:
  /// **'এটি এআই-ভিত্তিক পরামর্শ; চূড়ান্ত সিদ্ধান্তের আগে কৃষি কর্মকর্তার সাথে কথা বলুন'**
  String get aiDisclaimer;

  /// No description provided for @draftKbBanner.
  ///
  /// In bn, this message translates to:
  /// **'এটি পরীক্ষামূলক ও যাচাই না করা তথ্য। এর ভিত্তিতে কোনো ওষুধ প্রয়োগ করবেন না।'**
  String get draftKbBanner;

  /// No description provided for @needsInternet.
  ///
  /// In bn, this message translates to:
  /// **'এই ফসলের জন্য ইন্টারনেট দরকার'**
  String get needsInternet;

  /// No description provided for @offlineModelMissing.
  ///
  /// In bn, this message translates to:
  /// **'ইন্টারনেট চালু করে আবার চেষ্টা করুন'**
  String get offlineModelMissing;

  /// No description provided for @dailyCapReached.
  ///
  /// In bn, this message translates to:
  /// **'আজকের সীমা শেষ — আগামীকাল আবার চেষ্টা করুন'**
  String get dailyCapReached;

  /// No description provided for @diagnosisFailed.
  ///
  /// In bn, this message translates to:
  /// **'বিশ্লেষণ করা যায়নি। আবার চেষ্টা করুন'**
  String get diagnosisFailed;

  /// No description provided for @listen.
  ///
  /// In bn, this message translates to:
  /// **'শুনুন'**
  String get listen;

  /// No description provided for @pauseListening.
  ///
  /// In bn, this message translates to:
  /// **'থামান'**
  String get pauseListening;

  /// No description provided for @resumeListening.
  ///
  /// In bn, this message translates to:
  /// **'আবার শুনুন'**
  String get resumeListening;

  /// No description provided for @stopListening.
  ///
  /// In bn, this message translates to:
  /// **'বন্ধ করুন'**
  String get stopListening;

  /// No description provided for @ttsUnavailableTitle.
  ///
  /// In bn, this message translates to:
  /// **'বাংলা কণ্ঠস্বর পাওয়া যাচ্ছে না'**
  String get ttsUnavailableTitle;

  /// No description provided for @ttsUnavailableBody.
  ///
  /// In bn, this message translates to:
  /// **'শুনতে হলে ফোনের সেটিংসে ‘Google টেক্সট-টু-স্পিচ’ অ্যাপে বাংলা ভাষার ভয়েস ডাউনলোড করুন।'**
  String get ttsUnavailableBody;

  /// No description provided for @ttsDiseaseName.
  ///
  /// In bn, this message translates to:
  /// **'রোগের নাম'**
  String get ttsDiseaseName;

  /// No description provided for @ttsImmediate.
  ///
  /// In bn, this message translates to:
  /// **'এখনই যা করবেন'**
  String get ttsImmediate;

  /// No description provided for @sectionTreatment.
  ///
  /// In bn, this message translates to:
  /// **'চিকিৎসা'**
  String get sectionTreatment;

  /// No description provided for @immediateLabel.
  ///
  /// In bn, this message translates to:
  /// **'এখনই করুন'**
  String get immediateLabel;

  /// No description provided for @medicineLabel.
  ///
  /// In bn, this message translates to:
  /// **'ওষুধ'**
  String get medicineLabel;

  /// No description provided for @doseLabel.
  ///
  /// In bn, this message translates to:
  /// **'মাত্রা'**
  String get doseLabel;

  /// No description provided for @intervalLabel.
  ///
  /// In bn, this message translates to:
  /// **'কতদিন পর পর'**
  String get intervalLabel;

  /// No description provided for @preHarvestLabel.
  ///
  /// In bn, this message translates to:
  /// **'ফসল তোলার আগে বিরতি'**
  String get preHarvestLabel;

  /// No description provided for @preHarvestDays.
  ///
  /// In bn, this message translates to:
  /// **'{days} দিন'**
  String preHarvestDays(String days);

  /// No description provided for @safetyLine.
  ///
  /// In bn, this message translates to:
  /// **'স্প্রের সময় মাস্ক ও গ্লাভস পরুন, ওষুধের মোড়কের নির্দেশনা পড়ুন'**
  String get safetyLine;

  /// No description provided for @urgencyMedium.
  ///
  /// In bn, this message translates to:
  /// **'দ্রুত নজর দিন'**
  String get urgencyMedium;

  /// No description provided for @urgencyLow.
  ///
  /// In bn, this message translates to:
  /// **'প্রতিরোধমূলক ব্যবস্থা নিন'**
  String get urgencyLow;

  /// No description provided for @wasCorrect.
  ///
  /// In bn, this message translates to:
  /// **'ফলাফলটি কি সঠিক ছিল?'**
  String get wasCorrect;

  /// No description provided for @yes.
  ///
  /// In bn, this message translates to:
  /// **'হ্যাঁ'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In bn, this message translates to:
  /// **'না'**
  String get no;

  /// No description provided for @whatWasIt.
  ///
  /// In bn, this message translates to:
  /// **'আসল রোগ কী ছিল?'**
  String get whatWasIt;

  /// No description provided for @dontKnow.
  ///
  /// In bn, this message translates to:
  /// **'জানি না'**
  String get dontKnow;

  /// No description provided for @feedbackThanks.
  ///
  /// In bn, this message translates to:
  /// **'ধন্যবাদ, আপনার মতামত সংরক্ষিত হয়েছে'**
  String get feedbackThanks;

  /// No description provided for @kbUpdated.
  ///
  /// In bn, this message translates to:
  /// **'তথ্য হালনাগাদ হয়েছে'**
  String get kbUpdated;

  /// No description provided for @kbEntryGone.
  ///
  /// In bn, this message translates to:
  /// **'এই রোগের বিস্তারিত তথ্য আর পাওয়া যাচ্ছে না'**
  String get kbEntryGone;

  /// No description provided for @callExpert.
  ///
  /// In bn, this message translates to:
  /// **'কর্মকর্তার নম্বর'**
  String get callExpert;

  /// No description provided for @changeCrop.
  ///
  /// In bn, this message translates to:
  /// **'ফসল বদলান'**
  String get changeCrop;

  /// No description provided for @healthyTipsTitle.
  ///
  /// In bn, this message translates to:
  /// **'প্রতিরোধের পরামর্শ'**
  String get healthyTipsTitle;

  /// No description provided for @resultNotFound.
  ///
  /// In bn, this message translates to:
  /// **'ফলাফল পাওয়া যায়নি'**
  String get resultNotFound;

  /// No description provided for @generalAdviceTitle.
  ///
  /// In bn, this message translates to:
  /// **'সাধারণ পরামর্শ'**
  String get generalAdviceTitle;

  /// No description provided for @savingResult.
  ///
  /// In bn, this message translates to:
  /// **'ফলাফল সংরক্ষণ করা হচ্ছে…'**
  String get savingResult;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['bn'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bn':
      return AppLocalizationsBn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
