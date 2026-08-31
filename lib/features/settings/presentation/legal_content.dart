// GENERATED from the Figma artboards — do not hand-edit.
//
// Long-form copy for Figma frames `43_Terms and Conditions` (2002:804),
// `44_Privacy Policy` (2002:781) and `45_Help` (2002:757). Extracted straight
// from the design file so the wording matches exactly; re-extract rather than
// retyping if the copy changes.

/// One block of a legal page. [isHeading] blocks are the 17pt section titles;
/// the rest is 15pt body copy.
class LegalBlock {
  const LegalBlock(this.text, {this.isHeading = false});

  final String text;
  final bool isHeading;
}

/// Terms and Conditions — Figma frame content.
const List<LegalBlock> termsAndConditions = [
  LegalBlock('Last Updated: 12 June,2024'),
  LegalBlock('Welcome to Carbsai, your AI-powered nutrition assistant. Please read these Terms and Conditions carefully before using the Carbsai mobile application operated by us.'),
  LegalBlock('By using Carbsai, you agree to be bound by these Terms. If you do not agree with any part of the Terms, please do not access or use the App.'),
  LegalBlock('1. Eligibility', isHeading: true),
  LegalBlock('You must be at least 13 years old to use Carbsai. If you are under 18, you may use the App only with parental or guardian consent.'),
  LegalBlock('2. Health Disclaimer', isHeading: true),
  LegalBlock('Carbsai provides calorie tracking, dietary insights, and AI-generated meal recommendations. However:'),
  LegalBlock('Carbsai is not a medical or healthcare provider.'),
  LegalBlock('The App does not offer medical advice or substitute professional consultation.'),
  LegalBlock('Always consult your doctor or a qualified health provider before starting any diet or fitness program, especially if you have any medical conditions.'),
  LegalBlock('3. User Accounts', isHeading: true),
  LegalBlock('When you create an account with us:'),
  LegalBlock('You agree to provide accurate, complete, and updated information.'),
  LegalBlock('You are responsible for maintaining the confidentiality of your login credentials.'),
  LegalBlock('You may not share your account or impersonate another person.'),
];

/// Privacy Policy — Figma frame content.
const List<LegalBlock> privacyPolicy = [
  LegalBlock('Last Updated: 12 June,2024'),
  LegalBlock('Thank you for trusting Carbsai. Your privacy is important to us. This Privacy Policy explains how us. collects, uses, and protects your personal information when you use the Carbsai mobile application.'),
  LegalBlock('By using Carbsai, you agree to be bound by these Terms. If you do not agree with any part of the Terms, please do not access or use the App.'),
  LegalBlock('1. How We Use Your Data', isHeading: true),
  LegalBlock('We use the collected information to:'),
  LegalBlock('Personalize your diet and calorie tracking experience'),
  LegalBlock('Offer AI-powered meal suggestions and insights'),
  LegalBlock('Track your progress and health goals'),
  LegalBlock('Improve app functionality and user experience'),
  LegalBlock('Communicate with you (e.g., notifications, updates)'),
  LegalBlock('2. How We Share Your Information', isHeading: true),
  LegalBlock('We do not sell your personal data.'),
  LegalBlock('We may share limited data with:'),
  LegalBlock('Service providers (for hosting, analytics, or messaging)'),
  LegalBlock('Third-party integrations (e.g., Google Fit, Apple Health, if you authorize them)'),
  LegalBlock('Legal authorities if required by law or to protect our rights'),
];

/// Help — Figma frame content.
const List<LegalBlock> help = [
  LegalBlock('We\'re here to guide you every step of the way.'),
  LegalBlock('Quick Help Topics', isHeading: true),
  LegalBlock('How to log a meal'),
  LegalBlock('      Step-by-step guide to track your food'),
  LegalBlock('Setting your calorie goal'),
  LegalBlock('      Learn how Carbsai calculates your targets'),
  LegalBlock('Choosing a diet plan'),
  LegalBlock('      Understand what works best for your goals'),
  LegalBlock('Contact Support', isHeading: true),
  LegalBlock('Can’t find what you\'re looking for?'),
  LegalBlock('[ Send Us a Message ]'),
  LegalBlock('We usually respond within 24 hours.'),
  LegalBlock('Helpful Links', isHeading: true),
  LegalBlock('Privacy Policy'),
  LegalBlock('Terms & Conditions'),
];

