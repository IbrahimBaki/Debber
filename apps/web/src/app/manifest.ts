import type { MetadataRoute } from "next";

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "دبّر — ميزانية البيت المشتركة",
    short_name: "دبّر",
    description: "مساحة هادئة لتنظيم ميزانية المنزل المشتركة.",
    start_url: "/app",
    scope: "/",
    display: "standalone",
    background_color: "#FAF5EF",
    theme_color: "#FAF5EF",
    lang: "ar",
    dir: "rtl",
    icons: [
      { src: "/brand/icon-192.png", sizes: "192x192", type: "image/png" },
      { src: "/brand/icon-512.png", sizes: "512x512", type: "image/png" },
    ],
  };
}
