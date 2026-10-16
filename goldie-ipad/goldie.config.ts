import type { GoldieConfig } from "goldie";

/**
 * App Store assets for Carbsai on the 13" iPad. Rendered by goldie:
 *   cd goldie-ipad && npx -y goldie@0.5.0 doctor | capture | frame | preview
 *
 * SEPARATE FROM ../goldie FOR THREE REASONS, none of them cosmetic:
 *
 *  1. A scene's `flow` is one string, not one per device, so iPad coordinates
 *     cannot live in the iPhone config. The iPad flows are ipad-*.yaml in the
 *     same .argent/flows, and the header of ipad-01-scan.yaml explains which
 *     coordinates transform across from the iPhone and which had to be
 *     measured (the tab bar and the disclosure sheet are screen-anchored, so
 *     they do not).
 *  2. goldie reads its design sidecar as goldie.design.json *next to the
 *     config*, so sharing a directory would apply ../goldie's saved iPhone
 *     bezel to the iPad.
 *  3. outDir is <config dir>/out, so the verified iPhone and Android assets
 *     in ../goldie/out stay untouched by an iPad re-run.
 *
 * iPad support exists at all because of commit e642ab9: DesignFit.cover used
 * to crop the artboard to `428 / aspect` units of height, which is 571 units
 * on a 13" iPad, and onboarding's Next button lives at 788 — so the app
 * reached onboarding page 1 and stopped there, with no tappable node in the
 * accessibility tree. Requires TARGETED_DEVICE_FAMILY = "1,2".
 */

const APP_ROOT = "/Users/muhammadumer/StudioProjects/Carbsai";

const config: GoldieConfig = {
  appRoot: APP_ROOT,
  appPath: `${APP_ROOT}/build/ios/iphonesimulator/Runner.app`,
  bundleId: "com.carbsai.app",

  devices: ["ipad-13"],
  locales: ["en-US"],
  appearance: "dark",

  frame: { variant: { "ipad-13": "ipad-pro-13-silver" } },

  theme: {
    background: "linear-gradient(165deg, #1A1512 0%, #121212 55%, #0E0E0E 100%)",
    headlineColor: "#FFFFFF",
    subheadColor: "#C3C3C3",
    fontFamily: '"DM Sans", -apple-system, system-ui, sans-serif',
    // 0.24, not the 0.18 that fitted the one-line headlines: copyScale is
    // 1.3 on an iPad, so "Where the calories come from" and "Know what you
    // are signing up for" wrap to two lines, and at 0.18 the second line
    // pushed the subhead out of the copy box entirely - tile 6 rendered with
    // no subhead at all. The band has to fit the longest headline, not the
    // shortest.
    copyHeightRatio: 0.24,
    // Deliberately greater than 1, which looks wrong and is not.
    //
    // compose() does not measure deviceWidthRatio against the tile. It first
    // "squats" the tile to the reference phone aspect (1320/2868), so on a
    // 2064x2752 iPad tile the reference width is 2752 * 0.46025 = 1267px,
    // not 2064. A ratio of 0.80 therefore asked for a device 1013px wide -
    // under half the tile - which is why the first framed iPad strip had the
    // device marooned in the middle of a lot of empty background.
    //
    // Anything from about 1.30 up makes the width constraint non-binding and
    // hands the decision to fitBelowCopy's height constraint, which is what
    // should decide it: the device then fills whatever the headline leaves.
    deviceWidthRatio: 1.40,
    // NO TEMPLATE, AND "classic" ON EVERY TILE.
    //
    // The iPhone strip rotates through hero / tilt / offset / copy-below,
    // which all place the device at a fixed width ratio of 0.84-0.95 and let
    // it run off the bottom edge. That reads well for a 19.5:9 phone, whose
    // device is far taller than it is wide. An iPad is 4:3 and the tile is
    // 3:4, so a device at 0.95 of the tile width is already taller than the
    // tile: "hero" cropped it at the shoulders.
    //
    // "classic" is the only layout with fitBelowCopy, which sizes the device
    // to whatever is left under the headline instead of to a fixed fraction
    // of the width — so the whole iPad is on every tile. One composition for
    // all ten is also the right call here for a second reason: the app draws
    // its 428pt artboard as a centred column on an iPad, so the interesting
    // part of each screenshot is the middle of the display, and tilting or
    // offsetting the device only pushes that further from the eye.
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

  scenes: [
    {
      kind: "screenshot",
      id: "scan",
      flow: "ipad-01-scan",
      headline: { "en-US": "Point. Shoot. Counted." },
      subhead: { "en-US": "Your camera reads the plate so you don't have to." },
    },
    {
      kind: "screenshot",
      id: "result",
      flow: "ipad-02-result",
      headline: { "en-US": "Every macro, in seconds" },
      subhead: { "en-US": "Calories, protein, carbs and fat, per item." },
    },
    {
      kind: "screenshot",
      id: "home",
      flow: "ipad-03-home",
      headline: { "en-US": "Your day, adding up" },
      subhead: { "en-US": "The ring tells you what is left, not what you spent." },
    },
    {
      kind: "screenshot",
      id: "diary",
      flow: "ipad-04-diary",
      headline: { "en-US": "Every meal, where you left it" },
      subhead: { "en-US": "Today's log and the plan you are following, in one place." },
    },
    {
      kind: "screenshot",
      id: "analysis",
      flow: "ipad-05-analysis",
      headline: { "en-US": "See the pattern, not just the meal" },
      subhead: { "en-US": "Calorie trends across the week, and the days you missed." },
    },
    {
      // Not the iPhone's "Know your split": the 13" iPad already shows the
      // macro cards in the ipad-05 tile, so this one scrolls further on.
      kind: "screenshot",
      id: "macros",
      flow: "ipad-06-macros",
      headline: { "en-US": "Where the calories come from" },
      subhead: { "en-US": "Which meals carry the day, and how you logged them." },
    },
    {
      kind: "screenshot",
      id: "diets",
      flow: "ipad-07-diets",
      headline: { "en-US": "A plan that fits the goal" },
      subhead: { "en-US": "Mediterranean, keto, or something shaped around you." },
    },
    {
      kind: "screenshot",
      id: "dietdetail",
      flow: "ipad-08-dietdetail",
      headline: { "en-US": "Know what you are signing up for" },
      subhead: { "en-US": "Targets spelled out before you commit to a plan." },
    },
    {
      kind: "screenshot",
      id: "search",
      flow: "ipad-09-search",
      headline: { "en-US": "Can't photograph it? Search it." },
      subhead: { "en-US": "A full food database, and the meals you log often." },
    },
    {
      kind: "screenshot",
      id: "describe",
      flow: "ipad-10-describe",
      headline: { "en-US": "Just describe the meal" },
      subhead: { "en-US": "Type what you ate and Carbsai works out the rest." },
    },

    {
      kind: "preview",
      id: "preview",
      segments: [
        { id: "open", flow: "ipad-preview-01-open" },
        { id: "scan", flow: "ipad-preview-02-scan" },
        { id: "result", flow: "ipad-preview-03-result", holdSeconds: 1 },
        { id: "log", flow: "ipad-preview-04-log", holdSeconds: 1 },
      ],
    },
  ],
};

export default config;
