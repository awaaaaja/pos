import js from "@eslint/js";
import tseslint from "typescript-eslint";
import pluginVue from "eslint-plugin-vue";
import prettier from "eslint-config-prettier";

// Get the Vue recommended configs and patch the parser for TS support
const vueRecommended = pluginVue.configs["flat/recommended"].map((config) => {
  if (config.files?.includes("*.vue") && config.languageOptions) {
    return {
      ...config,
      languageOptions: {
        ...config.languageOptions,
        parserOptions: {
          ...config.languageOptions.parserOptions,
          parser: tseslint.parser,
        },
      },
    };
  }
  return config;
});

export default [
  // Ignores (must be first)
  {
    ignores: ["dist/**", "node_modules/**"],
  },

  // Base configs
  js.configs.recommended,
  ...tseslint.configs.recommended,

  // Vue recommended
  ...vueRecommended,

  // Override TS rules for .ts files
  {
    files: ["**/*.ts", "**/*.tsx", "**/*.mts", "**/*.cts"],
    rules: {
      "@typescript-eslint/no-unused-vars": [
        "warn",
        {
          argsIgnorePattern: "^_",
          varsIgnorePattern: "^_",
          caughtErrorsIgnorePattern: "^_",
        },
      ],
    },
  },

  // Override rules for .vue files (browser env)
  {
    files: ["**/*.vue"],
    languageOptions: {
      globals: {
        // Browser globals
        window: "readonly",
        document: "readonly",
        navigator: "readonly",
        confirm: "readonly",
        alert: "readonly",
        HTMLVideoElement: "readonly",
        HTMLInputElement: "readonly",
        MediaStream: "readonly",
        KeyboardEvent: "readonly",
        File: "readonly",
        Event: "readonly",
        CanvasRenderingContext2D: "readonly",
      },
    },
    rules: {
      "vue/multi-word-component-names": "off",
      "vue/singleline-html-element-content-newline": "off",
    },
  },

  // Prettier (must be last)
  prettier,
];
