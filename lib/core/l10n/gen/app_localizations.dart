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
