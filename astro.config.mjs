// @ts-check
import { defineConfig, fontProviders } from 'astro/config';

import mdx from '@astrojs/mdx';
import sitemap from '@astrojs/sitemap';

import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
  // swap in your real address later
  site: 'https://www.covenofguilt.com',

  integrations: [mdx(), sitemap()],

  vite: {
    plugins: [tailwindcss()],
  },
// Custom Fonts
fonts: [
  {
    provider: fontProviders.local(),
    name: 'EB Garamond',
    cssVariable: '--font-EBG',
    fallbacks: ['serif'],
    options: {
      variants: [
        { src: ['src/assets/fonts/EBGaramond-VariableFont_wght.ttf'], weight: 400, style: 'normal' },
      ],
    },
  },
  {
    provider: fontProviders.local(),
    name: 'Jacquard24',
    cssVariable: '--font-Jacquard24',
    fallbacks: ['display'],
    options: {
      variants: [
        { src: ['src/assets/fonts/Jacquard24-Regular.ttf'], weight: 400, style: 'normal' },
      ],
    },
  },
]


});


