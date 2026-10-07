import type { GoldieConfig } from "goldie";

/**
 * Store assets for Carbsai. Rendered by goldie:
 *   cd goldie && npx -y goldie@0 doctor | capture | frame | preview | studio
 *
 * Builds are made with --dart-define=BACKEND=local on purpose. The local
 * backend is deterministic and offline: LocalScanRepository returns the same
 * three foods every time, SeedData fills the diary, and fake auth means the
 * flows never touch Firebase. That is what makes a re-capture reproducible.
 *
 * The simulator has no camera, and ScanningScreen already handles that by
 * standing in the design's own photograph, so the AI camera screen captures
 * correctly rather than showing a dead viewfinder.
 */

const APP_ROOT = "/Users/muhammadumer/StudioProjects/Carbsai";

const config: GoldieConfig = {
  appRoot: APP_ROOT,
  // Flutter puts the simulator build here; --simulator implies debug mode.
  // Flutter debug builds are self-contained (no Metro equivalent) and
  // debugShowCheckedModeBanner is false in main.dart, so nothing dev-only
  // is painted into the captures.
  appPath: `${APP_ROOT}/build/ios/iphonesimulator/Runner.app`,
  bundleId: "com.carbsai.app",

  android: {
    appPath: `${APP_ROOT}/build/app/outputs/flutter-apk/app-release.apk`,
    applicationId: "com.carbsai.app",
  },

  devices: ["iphone-6.9", "pixel-10-pro"],
  locales: ["en-US"],
  // Carbsai is a dark app (AppColors.background #121212, ColorScheme
  // brightness dark), so the device chrome should match it.
  appearance: "dark",

  frame: { variant: "17-pro-silver" },

  theme: {
    // Dark ground with a warm lift toward the brand orange (#FF5A16), so the
    // tiles read as the app rather than as a generic light template.
    background: "linear-gradient(165deg, #1A1512 0%, #121212 55%, #0E0E0E 100%)",
    headlineColor: "#FFFFFF",
    subheadColor: "#C3C3C3",
    fontFamily: '"DM Sans", -apple-system, system-ui, sans-serif',
    copyHeightRatio: 0.24,
    deviceWidthRatio: 0.84,
    // A custom sequence instead of a built-in template: every layout here has
    // span 1, so 10 scenes render exactly 10 tiles. "editorial" opens with a
    // panorama, which spans 2 and would push the strip to 11 - one over the
    // App Store's limit of 10.
    template: [
      "hero", "classic", "tilt", "offset", "minimal",
      "copy-below", "tilt-right", "hero", "classic", "tilt",
    ],
    layout: "classic",
  },

  store: {
    name: "Carbsai",
    subtitle: { "en-US": "Calorie tracking from a photo" },
    developer: "Carbsai",
    category: "Health & Fitness",
    rating: 4.8,
    ratingCount: "1.2K Ratings",
    ageRating: "4+",
    price: "Free",
    description: {
      "en-US":
        "Point your camera at a meal and Carbsai reads it: calories, protein, carbs and fat, in seconds. No weighing, no searching a database, no guessing portion sizes.\n\nLog what you actually eat, follow a diet plan that adapts to your goal, and watch the day add up.",
    },
  },

  // Capture order = store order. Each flow continues where the previous one
  // left the app: a `launch:` step cannot work without native devtools.
  //
  // Favorites, Settings and Profile were considered and dropped: all three
  // are empty or unset on the fresh install every capture starts from, so
  // they photograph as blank states. Scrolled views of the screens that
  // SeedData fills are stronger tiles than a second empty list.
  scenes: [
    {
      kind: "screenshot",
      id: "scan",
      flow: "store-01-scan",
      headline: { "en-US": "Point. Shoot. Counted." },
      subhead: { "en-US": "Your camera reads the plate so you don't have to." },
    },
    {
      kind: "screenshot",
      id: "result",
      flow: "store-02-result",
      headline: { "en-US": "Every macro, in seconds" },
      subhead: { "en-US": "Calories, protein, carbs and fat, per item." },
    },
    {
      kind: "screenshot",
      id: "home",
      flow: "store-03-home",
      headline: { "en-US": "Your day, adding up" },
      subhead: { "en-US": "The ring tells you what is left, not what you spent." },
    },
    {
      kind: "screenshot",
      id: "diary",
      flow: "store-04-diary",
      headline: { "en-US": "Every meal, where you left it" },
      subhead: { "en-US": "Today's log and the plan you are following, in one place." },
    },
    {
      kind: "screenshot",
      id: "analysis",
      flow: "store-05-analysis",
      headline: { "en-US": "See the pattern, not just the meal" },
      subhead: { "en-US": "Calorie trends across the week, and the days you missed." },
    },
    {
      kind: "screenshot",
      id: "macros",
      flow: "store-06-macros",
      headline: { "en-US": "Know your split" },
      subhead: { "en-US": "Fats, carbs and protein against the plan you picked." },
    },
    {
      kind: "screenshot",
      id: "diets",
      flow: "store-07-diets",
      headline: { "en-US": "A plan that fits the goal" },
      subhead: { "en-US": "Mediterranean, keto, or something shaped around you." },
    },
    {
      kind: "screenshot",
      id: "dietdetail",
      flow: "store-08-dietdetail",
      headline: { "en-US": "Know what you are signing up for" },
      subhead: { "en-US": "Targets spelled out before you commit to a plan." },
    },
    {
      kind: "screenshot",
      id: "search",
      flow: "store-09-search",
      headline: { "en-US": "Can't photograph it? Search it." },
      subhead: { "en-US": "A full food database, and the meals you log often." },
    },
    {
      kind: "screenshot",
      id: "describe",
      flow: "store-10-describe",
      headline: { "en-US": "Just describe the meal" },
      subhead: { "en-US": "Type what you ate and Carbsai works out the rest." },
    },

    {
      kind: "preview",
      id: "preview",
      segments: [
        { id: "open", flow: "store-preview-01-open" },
        { id: "scan", flow: "store-preview-02-scan" },
        { id: "result", flow: "store-preview-03-result", holdSeconds: 1 },
        { id: "log", flow: "store-preview-04-log", holdSeconds: 1 },
      ],
    },
  ],
};

export default config;
