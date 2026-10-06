import '../../core/l10n/gen/app_localizations.dart';

/// The 8 launch crops. Ids match the KB `crop` field and the model labels.
const kLaunchCropIds = [
  'rice', 'jute', 'potato', 'tomato', 'brinjal', 'chili', 'onion', 'mustard',
];

const _cropEmoji = {
  'rice': '🌾', 'jute': '🪴', 'potato': '🥔', 'tomato': '🍅',
  'brinjal': '🍆', 'chili': '🌶️', 'onion': '🧅', 'mustard': '🌻',
};

String cropEmoji(String id) => _cropEmoji[id] ?? '🌱';

String cropName(AppLocalizations l, String id) => switch (id) {
      'rice' => l.cropRice,
      'jute' => l.cropJute,
      'potato' => l.cropPotato,
      'tomato' => l.cropTomato,
      'brinjal' => l.cropBrinjal,
      'chili' => l.cropChili,
      'onion' => l.cropOnion,
      'mustard' => l.cropMustard,
      _ => id,
    };
