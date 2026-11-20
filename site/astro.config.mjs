import { defineConfig } from 'astro/config';

const fromEnvironment = process.env.DOKUNYA_BASE || '/DOKUNYA-generative-art/';
const base = '/' + fromEnvironment.replace(/^\/+|\/+$/g, '') + '/';

export default defineConfig({
  site: 'https://imandustnihan.github.io',
  base,
  output: 'static',
  security: { csp: { directives: ["default-src 'self'", "object-src 'none'", "base-uri 'self'", "frame-src 'self'", "form-action 'none'"] } },
  trailingSlash: 'always',
  build: { format: 'directory' },
});
