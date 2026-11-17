# Coven of Guilt — covenofguilt.com

The official website for **Coven of Guilt**. Built with [Astro](https://astro.build) and Tailwind CSS, and deployed as static assets on Cloudflare Workers.

## Pages

| Route      | File                       | What it is                                   |
| ---------- | -------------------------- | -------------------------------------------- |
| `/`        | `src/pages/index.astro`    | Home page                                    |
| `/latest`  | `src/pages/latest.astro`   | Latest music (Spotify embeds, audio player)  |
| `/music`   | `src/pages/music.astro`    | Links to Bandcamp, Spotify and Apple Music   |
| `/photos`  | `src/pages/photos.astro`   | Photo gallery                                |
| `/riders`  | `src/pages/riders.astro`   | Tech riders (PDFs in `public/rider/`)        |
| `/systems` | `src/pages/systems.astro`  | Showcase of the `cog` components             |
| `/blog`    | `src/pages/blog/`          | Posts from `src/content/blog/`               |

## Getting started

Requires Node `>=22.23.4`.

```sh
npm install
npx astro dev --background   # start the dev server in the background
npx astro dev status         # check if it's running
npx astro dev logs           # view server output
npx astro dev stop           # stop it
```

## Commands

| Command           | Action                                          |
| ----------------- | ----------------------------------------------- |
| `npm run dev`     | Start the dev server (foreground)               |
| `npm run build`   | Build the site to `./dist/`                     |
| `npm run preview` | Preview the production build locally            |
| `npm run deploy`  | Deploy `./dist/` to Cloudflare with Wrangler    |

Run `npm run build` before `npm run deploy`. The Wrangler config is in `wrangler.json`.

## Project structure

```
public/
  audio/        audio files used by the Player
  photos/       images served as-is
  rider/        tech rider PDFs
src/
  assets/
    fonts/      EB Garamond, Jacquard 24, Coral Pixels
    photos/     images optimized by astro:assets
  components/
    cog/        band-styled UI components (see below)
  content/blog/ Markdown/MDX blog posts
  layouts/
  pages/        each file is a route
  styles/
    global.css
    cog.css     theme styles for the cog components
  consts.ts     site title, description, band name and members
```

## `cog` components

These are in `src/components/cog/`.

- **`Player`**: an audio player with an analog gauge whose needle moves with the music. Props: `tracks: { title, src, note? }[]`, `label?`.
- **`DitherImage`**: renders an image or a looping video (`.mp4`/`.webm`/`.mov`) with a dither effect. To use a GIF, convert it to `.mp4` first with `swift scripts/gif-to-mp4.swift public/photos/clip.gif`. The script only uses tools built into macOS, so ffmpeg isn't needed. Props: `src`, `alt`, `mode?: 'bayer' | 'floyd'`, `dot?`, `dark?`, `light?`, `contrast?`, `reveal?`.
- **`SpotifyEmbed`**: takes a normal Spotify share link and embeds it. Props: `url`, `frame?: 'plate' | 'dither' | 'bone' | 'panel'`, `compact?`, `title?`.
- **`Frame`**: a decorative border. Props: `variant?: 'dither' | 'plate' | 'bone' | 'panel' | 'image'`, `size?`, `rivets?`, `image?`, `slice?`.
- **`Divider`**: a horizontal rule. Props: `variant?: 'dither' | 'fade' | 'blood' | 'pipe' | 'rivets'`, `color?`.

All of them also accept `class`.

## Editing site info

The site title, description, band name and members are set in `src/consts.ts`. The site URL (used for the sitemap and RSS) is set in `astro.config.mjs`.
