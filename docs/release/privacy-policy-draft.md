# Privacy policy (DRAFT: needs legal review before it is published)

This is a plain-language draft of what the app actually does, taken from the code and Design §15.2. It is not legal advice. Check Bangladeshi data-protection requirements and the AI provider's retention terms, then host the final text at a public URL.

## English

**Who we are:** <operator name and contact e-mail, 🔧>.

**What the app does:** you photograph a crop leaf; the app suggests a likely disease and what to do, using a knowledge base reviewed by an agronomist. It is AI-based advice, not a professional diagnosis.

**What we collect and why**
- **The photo you take for a diagnosis.** Sent over an encrypted connection to our server and on to an AI service provider to identify the disease. We remove location and camera data (EXIF) first. We do not keep the photo on the server after answering, unless you turn on one of the two options below. <Confirm the AI provider's own retention period, 🔧.>
- **Your diagnosis history** (crop, disease result, date, your 👍/👎 answer, district). Stored on your phone and backed up to our servers under an anonymous id so it can be restored and counted. You can delete it at any time (Settings → ইতিহাস মুছুন).
- **Regional reports** (district, upazila, crop, disease; no photo, no name). Used to show other farmers a warning when several farmers in the same area report the same disease. Turn off in Settings. Default: on.
- **Photo backup** (optional, default off): keeps the photo for 30 days so you can see it in your history on a new phone.
- **Photo contribution** (optional, default off): lets us use the photo to improve disease recognition. Stored until reviewed or until you delete your data.
- **Your district, upazila and main crop**, which you choose. Used for local alerts, weather notices and push notifications. We do not read your GPS location.
- **Technical data:** crash reports and anonymous usage counts (for example "a diagnosis finished in 4 seconds"). No photos, no names, no free text.
- **Identifiers:** an anonymous user id created by the app, and a notification token. No name, phone number or e-mail is asked for.

**Who receives data:** Google Firebase (storage, database, notifications, crash and usage reports) and the AI service provider named above (photos for diagnosis). We do not sell data and we show no advertising.

**Your choices:** every optional item above is a switch in Settings. "ইতিহাস মুছুন" deletes your history, regional reports and cloud photos from our servers and your phone. Aggregated area counts that no longer identify you may remain. <Add a contact route for deletion requests, 🔧.>

**Children:** the app is for adults; it is not directed at children.

**Changes:** we will update this page and the app's Data safety information when this changes.

## বাংলা সারসংক্ষেপ (খসড়া, অনুবাদ যাচাই দরকার)

- আপনার তোলা ছবি রোগ শনাক্তের জন্য নিরাপদ সংযোগে সার্ভার ও এআই সেবায় যায়; ছবি থেকে অবস্থানের তথ্য সরিয়ে ফেলা হয়।
- ছবি ব্যাকআপ ও ছবি দান — দুটোই ঐচ্ছিক এবং শুরুতে বন্ধ।
- আপনার জেলা ও উপজেলা আপনি নিজে বেছে নেন; আমরা জিপিএস অবস্থান পড়ি না।
- নাম, ফোন নম্বর বা ই-মেইল চাওয়া হয় না। কোনো বিজ্ঞাপন নেই।
- সেটিংস থেকে "ইতিহাস মুছুন" চাপলে আপনার ইতিহাস, রিপোর্ট ও ক্লাউডের ছবি মুছে যায়।
