// Fallback for projects without their own ESLint config: typescript-eslint's strictest presets.
// With a tsconfig.json (CODE_PLUGIN_TYPED=1) the type-aware variants run too.
import js from "@eslint/js";
import { defineConfig } from "eslint/config";
import tseslint from "typescript-eslint";

const typed = process.env.CODE_PLUGIN_TYPED === "1";

export default defineConfig(
  { files: ["**/*.{ts,tsx,mts,cts}"] },
  js.configs.recommended,
  typed ? tseslint.configs.strictTypeChecked : tseslint.configs.strict,
  typed ? tseslint.configs.stylisticTypeChecked : tseslint.configs.stylistic,
  typed
    ? { languageOptions: { parserOptions: { projectService: true, tsconfigRootDir: process.cwd() } } }
    : {},
);
