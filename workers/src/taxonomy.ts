/**
 * The dish taxonomy the plan builder's quiz is built on — the server's copy.
 *
 * This exists twice: here and in `lib/core/nutrition/dish_taxonomy.dart`.
 * The client sends dish ids and pole names, never labels, and everything is
 * resolved against this file, so a value the app knows and this file does not
 * is a tap that silently changes nothing. Keep the ids identical; the Dart
 * test diffs them.
 *
 * Nothing here is a nutrition target. The targets come from the profile.
 */

export type Cuisine =
  | "South Asian"
  | "Mediterranean"
  | "East Asian"
  | "Western"
  | "Mexican & Latin"
  | "Middle Eastern";

export type DishTag =
  | "spicy"
  | "mild"
  | "rice"
  | "bread"
  | "meat"
  | "fish"
  | "egg"
  | "plants"
  | "breakfast"
  | "cooked"
  | "assembled"
  | "quick";

export interface Dish {
  readonly name: string;
  readonly cuisine: Cuisine;
  readonly tags: readonly DishTag[];
  /** Honest cook time, so a fifteen-minute person who liked biryani is told. */
  readonly minutes: number;
}

export const DISHES: Readonly<Record<string, Dish>> = {
  "chicken-karahi": { name: "Chicken karahi", cuisine: "South Asian", tags: ["spicy", "meat", "cooked"], minutes: 40 },
  "dal-tadka": { name: "Dal tadka", cuisine: "South Asian", tags: ["plants", "cooked", "mild"], minutes: 30 },
  biryani: { name: "Chicken biryani", cuisine: "South Asian", tags: ["spicy", "rice", "meat", "cooked"], minutes: 60 },
  "aloo-paratha": { name: "Aloo paratha", cuisine: "South Asian", tags: ["bread", "plants", "breakfast", "cooked"], minutes: 25 },
  "greek-salad": { name: "Greek salad", cuisine: "Mediterranean", tags: ["plants", "assembled", "mild", "quick"], minutes: 10 },
  "grilled-salmon": { name: "Grilled salmon", cuisine: "Mediterranean", tags: ["fish", "cooked", "mild"], minutes: 20 },
  "hummus-plate": { name: "Hummus & pita", cuisine: "Mediterranean", tags: ["plants", "assembled", "bread", "quick"], minutes: 10 },
  shakshuka: { name: "Shakshuka", cuisine: "Mediterranean", tags: ["egg", "breakfast", "cooked", "spicy"], minutes: 25 },
  "chicken-stir-fry": { name: "Chicken stir-fry", cuisine: "East Asian", tags: ["meat", "rice", "cooked"], minutes: 20 },
  sushi: { name: "Salmon sushi", cuisine: "East Asian", tags: ["fish", "rice", "assembled"], minutes: 15 },
  ramen: { name: "Ramen", cuisine: "East Asian", tags: ["meat", "cooked"], minutes: 30 },
  "tofu-bowl": { name: "Tofu rice bowl", cuisine: "East Asian", tags: ["plants", "rice", "mild", "quick"], minutes: 15 },
  "grilled-chicken-veg": { name: "Grilled chicken & veg", cuisine: "Western", tags: ["meat", "cooked", "mild"], minutes: 25 },
  "avocado-toast": { name: "Avocado toast", cuisine: "Western", tags: ["plants", "bread", "breakfast", "assembled", "quick"], minutes: 10 },
  "oats-berries": { name: "Oats & berries", cuisine: "Western", tags: ["plants", "breakfast", "assembled", "quick", "mild"], minutes: 5 },
  "burger-fries": { name: "Burger & fries", cuisine: "Western", tags: ["meat", "bread", "cooked"], minutes: 30 },
  "chicken-burrito": { name: "Chicken burrito", cuisine: "Mexican & Latin", tags: ["meat", "bread", "spicy", "assembled"], minutes: 15 },
  "taco-bowl": { name: "Chicken taco bowl", cuisine: "Mexican & Latin", tags: ["meat", "rice", "spicy", "assembled"], minutes: 20 },
  "chicken-shawarma": { name: "Chicken shawarma", cuisine: "Middle Eastern", tags: ["meat", "bread", "spicy", "cooked"], minutes: 30 },
  "falafel-wrap": { name: "Falafel wrap", cuisine: "Middle Eastern", tags: ["plants", "bread", "assembled"], minutes: 15 },
};

/** One end of a this-or-that question, and the line the prompt gets for it. */
export type TastePole =
  | "hot"
  | "mild"
  | "rice"
  | "bread"
  | "meat"
  | "plants"
  | "bigBreakfast"
  | "lightBreakfast"
  | "skipBreakfast"
  | "cooked"
  | "assembled";

export const POLE_INSTRUCTION: Readonly<Record<TastePole, string>> = {
  hot: "They like heat. Season generously; chillies, pepper and warm spice are welcome in most meals.",
  mild: "They keep it mild. No hot chillies; season with herbs, garlic, lemon and gentle spice.",
  rice: "Given the choice they pick rice over bread. Prefer rice, grains and bowls as the starch.",
  bread: "Given the choice they pick bread over rice. Prefer roti, wraps, toast and flatbreads as the starch.",
  meat: "Meat-forward: chicken, fish or meat should anchor most main meals.",
  plants: "Plant-forward: pulses, tofu, eggs and vegetables should anchor most main meals, with meat occasional at most.",
  bigBreakfast: "They like a substantial breakfast. Give breakfast a real share of the day's energy, 25% or more.",
  lightBreakfast: "They prefer a light breakfast. Keep breakfast small, under 20% of the day, and move the energy to later meals.",
  skipBreakfast:
    "They skip breakfast. Do not schedule one: put the day's energy into the remaining meals and, if the meal count requires it, make the first meal a late-morning one.",
  cooked: "They are happy to cook: hot, cooked meals are fine.",
  assembled: "They rarely cook. Favour meals that are assembled rather than cooked — bowls, wraps, salads, things from a tin or a packet.",
};

/** Each axis and the poles it may answer with. `fromRequest` validates against this. */
export const AXES: Readonly<Record<string, readonly TastePole[]>> = {
  spice: ["hot", "mild"],
  starch: ["rice", "bread"],
  protein: ["meat", "plants"],
  breakfast: ["bigBreakfast", "lightBreakfast", "skipBreakfast"],
  prep: ["cooked", "assembled"],
};

/**
 * Hard constraints, and the words a returned plan is scanned for.
 *
 * The prompt says MUST NOT and the model mostly listens, but "mostly" is not a
 * standard for an allergen. The scan is the guarantee: a plan naming any of
 * these after the person excluded it never reaches them.
 *
 * `words` match at a **word start** — `cream` catches "creamy", `butter`
 * catches "buttered" and "buttermilk" — after every `except` phrase has been
 * removed from the text, so "oat milk" is not dairy and "corn tortilla" is
 * not gluten. An `except` entry that ends in `free` or starts with `non-` is
 * a qualifier and removes the word it qualifies too — "gluten-free bread",
 * "non-dairy milk". Both a false refusal (which burns a quota unit) and a
 * false pass (which reaches an allergic person) are a list entry away.
 *
 * Mirrored exactly in `lib/core/models/taste_profile.dart` (`Avoidance`);
 * the Dart test diffs both lists, and `avoidance_check_test.dart` holds the
 * cases the two matchers must agree on.
 */
export const AVOIDANCES: Readonly<
  Record<string, { label: string; words: readonly string[]; except: readonly string[] }>
> = {
  beef: {
    label: "beef",
    words: ["beef", "steak", "mince", "burger", "hamburger", "cheeseburger", "brisket", "nihari", "sirloin", "ribeye", "veal", "oxtail", "pastrami"],
    except: ["tuna steak", "swordfish steak", "salmon steak", "cauliflower steak", "lamb steak", "pork steak", "chicken burger", "turkey burger", "veggie burger", "vegan burger", "bean burger", "chickpea burger", "salmon burger", "fish burger", "lamb burger", "pork burger", "lamb mince", "turkey mince", "chicken mince", "pork mince", "soy mince", "plant mince", "minced garlic", "minced ginger", "minced onion", "minced herbs", "minced chilli", "minced coriander", "minced parsley"],
  },
  pork: {
    label: "pork",
    words: ["pork", "bacon", "ham", "sausage", "salami", "prosciutto", "chorizo", "pancetta", "pepperoni", "gammon", "lardon", "lard"],
    except: ["chicken sausage", "turkey sausage", "beef sausage", "lamb sausage", "veggie sausage", "vegan sausage", "plant sausage", "hamburger", "hammered"],
  },
  dairy: {
    label: "dairy",
    words: ["milk", "cheese", "cheesy", "yoghurt", "yogurt", "butter", "cream", "paneer", "ghee", "lassi", "raita", "curd", "whey", "mozzarella", "feta", "parmesan", "cheddar", "ricotta", "mascarpone", "labneh", "kefir", "custard"],
    except: ["oat milk", "almond milk", "soy milk", "soya milk", "coconut milk", "rice milk", "cashew milk", "hazelnut milk", "peanut butter", "almond butter", "cashew butter", "nut butter", "cocoa butter", "butternut", "coconut cream", "coconut yoghurt", "coconut yogurt", "soy yoghurt", "soy yogurt", "bean curd", "dairy-free", "dairy free", "non-dairy", "cream of tartar"],
  },
  gluten: {
    label: "gluten",
    words: ["bread", "toast", "roti", "naan", "chapati", "paratha", "pasta", "noodle", "wheat", "wrap", "tortilla", "pita", "couscous", "bulgur", "flatbread", "seitan", "barley", "rye", "semolina", "spaghetti", "penne", "macaroni", "lasagne", "lasagna", "croissant", "bagel", "biscuit", "cracker", "crouton", "pizza", "dumpling", "puri", "bhatura", "pretzel"],
    except: ["gluten-free", "gluten free", "corn tortilla", "rice noodle", "lettuce wrap", "glass noodle", "buckwheat", "toasted", "wrapped"],
  },
  nuts: {
    label: "nuts",
    words: ["nut", "almond", "peanut", "cashew", "walnut", "pistachio", "hazelnut", "pecan", "macadamia", "praline", "marzipan"],
    except: ["nutmeg", "nutrition", "nutritional", "nutrient", "nutrients", "nutty seed"],
  },
  eggs: {
    label: "eggs",
    words: ["egg", "omelette", "omelet", "frittata", "shakshuka", "meringue", "mayonnaise", "mayo", "quiche", "custard"],
    except: ["eggplant", "egg-free", "egg free", "eggless", "vegan mayo", "vegan mayonnaise"],
  },
  seafood: {
    label: "seafood",
    words: ["seafood", "fish", "salmon", "tuna", "prawn", "shrimp", "cod", "sardine", "mackerel", "crab", "squid", "anchovy", "anchovies", "shellfish", "swordfish", "oyster", "mussel", "clam", "lobster", "scallop", "calamari", "octopus", "haddock", "tilapia", "trout", "halibut", "seabass", "sea bass", "kipper", "eel", "caviar", "roe"],
    except: ["crabapple"],
  },
};

/** Cook-time ceiling per meal. Zero means no cooking at all. */
export const COOK_TIMES: Readonly<Record<string, { label: string; maxMinutes: number }>> = {
  under15: { label: "under 15 minutes", maxMinutes: 15 },
  upTo30: { label: "15 to 30 minutes", maxMinutes: 30 },
  likesCooking: { label: "no time limit — they like cooking", maxMinutes: 60 },
  eatingOut: { label: "mostly eating out", maxMinutes: 0 },
};
