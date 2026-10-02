// Flat config (ESLint >= 9). Needs: npm i -D eslint @eslint/js typescript-eslint
// Move any old .eslintignore patterns into `ignores` below, then delete that file.
import js from "@eslint/js";
import tseslint from "typescript-eslint";

export default tseslint.config(
  {
    ignores: [
      "**/node_modules/**",
      "**/dist/**",
      "**/build/**",
      "**/coverage/**",
      "**/.next/**",
      "**/.nuxt/**",
    ],
  },
  js.configs.recommended,
  tseslint.configs.recommended,
);
