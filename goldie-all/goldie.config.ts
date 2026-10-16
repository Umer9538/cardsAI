import type { GoldieConfig } from "goldie";

/**
 * VIEW ONLY. One studio showing all three strips: iPhone, Android, iPad.
 *
 *   cd goldie-all && ./refresh.sh && npx -y goldie@0.5.0 studio --port 4321
 *
 * DO NOT RUN `goldie capture` FROM HERE. It is wired to fail if you try:
 * `flowsDir` points at ./no-flows, which is empty, so every scene's flow
 * resolves to a file that does not exist and the run stops on the first one.
 * That guard is deliberate. A scene in goldie carries ONE `flow` string with
 * no per-device variant, so a config listing all three devices would replay
 * the iPhone coordinates against an iPad - where the tab bar alone is at
 * y 0.9365 rather than 0.909 - and a coordinate tap always reports success.
 * The result would be ten files, all different from each other, all wrong.
 *
 * DO NOT RE-RENDER FROM HERE EITHER (the studio's design controls write
 * through to out/). `theme` is one object for every device, but the two real
 * configs need different values: ../goldie runs a hero/tilt/offset template
 * at deviceWidthRatio 0.84, and ../goldie-ipad needs "classic" everywhere at
 * 1.40, because compose() measures that ratio against a tile squatted to the
 * reference phone aspect and because a 4:3 iPad at a phone's width ratio is
 * taller than the tile. One theme cannot be right for both.
 *
 * So: capture and design in ../goldie and ../goldie-ipad, then run
 * ./refresh.sh to copy the finished assets here for viewing and export.
 * The copies are what protect the real deliverables from a stray re-render.
 */

const APP_ROOT = "/Users/muhammadumer/StudioProjects/Carbsai";

/** Resolves under ./no-flows, which holds only a README. */
const NO_FLOW = "VIEW-ONLY-CONFIG-capture-from-goldie-or-goldie-ipad";

const config: GoldieConfig = {
  appRoot: APP_ROOT,
  flowsDir: "./no-flows",
  appPath: `${APP_ROOT}/build/ios/iphonesimulator/Runner.app`,
  bundleId: "com.carbsai.app",

  android: {
    appPath: `${APP_ROOT}/build/app/outputs/flutter-apk/app-release.apk`,
    applicationId: "com.carbsai.app",
  },

  devices: ["iphone-6.9", "pixel-10-pro", "ipad-13"],
  locales: ["en-US"],
  appearance: "dark",

  frame: {
    variant: {
      "iphone-6.9": "17-pro-silver",
      "ipad-13": "ipad-pro-13-silver",
    },
  },

  theme: {
    background: "linear-gradient(165deg, #1A1512 0%, #121212 55%, #0E0E0E 100%)",
    headlineColor: "#FFFFFF",
    subheadColor: "#C3C3C3",
    fontFamily: '"DM Sans", -apple-system, system-ui, sans-serif',
    copyHeightRatio: 0.24,
    deviceWidthRatio: 0.84,
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

  // Scene ids match both real configs, so every device's captures line up
  // under the same ten tiles. The copy is ../goldie's; the iPad strip words
  // scene 6 differently (see ../goldie-ipad/goldie.config.ts) because the
  // 13" viewport already shows the macro cards in scene 5.
  scenes: [
    { kind: "screenshot", id: "scan", flow: NO_FLOW,
      headline: { "en-US": "Point. Shoot. Counted." },
      subhead: { "en-US": "Your camera reads the plate so you don't have to." } },
    { kind: "screenshot", id: "result", flow: NO_FLOW,
      headline: { "en-US": "Every macro, in seconds" },
      subhead: { "en-US": "Calories, protein, carbs and fat, per item." } },
    { kind: "screenshot", id: "home", flow: NO_FLOW,
      headline: { "en-US": "Your day, adding up" },
      subhead: { "en-US": "The ring tells you what is left, not what you spent." } },
    { kind: "screenshot", id: "diary", flow: NO_FLOW,
      headline: { "en-US": "Every meal, where you left it" },
      subhead: { "en-US": "Today's log and the plan you are following, in one place." } },
    { kind: "screenshot", id: "analysis", flow: NO_FLOW,
      headline: { "en-US": "See the pattern, not just the meal" },
      subhead: { "en-US": "Calorie trends across the week, and the days you missed." } },
    { kind: "screenshot", id: "macros", flow: NO_FLOW,
      headline: { "en-US": "Know your split" },
      subhead: { "en-US": "Fats, carbs and protein against the plan you picked." } },
    { kind: "screenshot", id: "diets", flow: NO_FLOW,
      headline: { "en-US": "A plan that fits the goal" },
      subhead: { "en-US": "Mediterranean, keto, or something shaped around you." } },
    { kind: "screenshot", id: "dietdetail", flow: NO_FLOW,
      headline: { "en-US": "Know what you are signing up for" },
      subhead: { "en-US": "Targets spelled out before you commit to a plan." } },
    { kind: "screenshot", id: "search", flow: NO_FLOW,
      headline: { "en-US": "Can't photograph it? Search it." },
      subhead: { "en-US": "A full food database, and the meals you log often." } },
    { kind: "screenshot", id: "describe", flow: NO_FLOW,
      headline: { "en-US": "Just describe the meal" },
      subhead: { "en-US": "Type what you ate and Carbsai works out the rest." } },

    { kind: "preview", id: "preview",
      segments: [
        { id: "open", flow: NO_FLOW },
        { id: "scan", flow: NO_FLOW },
        { id: "result", flow: NO_FLOW },
        { id: "log", flow: NO_FLOW },
      ] },
  ],
};

export default config;
