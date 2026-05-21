import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";

const isPages = process.env.GITHUB_PAGES === "true";

export default defineConfig({
  base: isPages ? "/woojoo-magic/" : "/",
  plugins: [react(), tailwindcss()],
  build: {
    outDir: "dist",
    sourcemap: false,
  },
});
