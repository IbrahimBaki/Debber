import type { Metadata, Viewport } from "next";
import { DM_Sans, Noto_Sans_Arabic } from "next/font/google";
import "./globals.css";

const arabic = Noto_Sans_Arabic({
  variable: "--font-arabic",
  subsets: ["arabic"],
  weight: ["400", "500", "600", "700", "800"],
});

const latin = DM_Sans({
  variable: "--font-latin",
  subsets: ["latin"],
  weight: ["400", "500", "600", "700"],
});

export const metadata: Metadata = {
  title: {
    default: "دبّر | Dabber",
    template: "%s | دبّر",
  },
  description: "مساحة هادئة لتنظيم ميزانية المنزل المشتركة.",
  appleWebApp: {
    capable: true,
    statusBarStyle: "default",
    title: "دبّر",
  },
  icons: {
    icon: [
      { url: "/brand/favicon-16.png", sizes: "16x16", type: "image/png" },
      { url: "/brand/favicon-32.png", sizes: "32x32", type: "image/png" },
    ],
    apple: "/brand/apple-touch-icon.png",
  },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
  themeColor: "#FAF5EF",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html
      lang="ar"
      dir="rtl"
      className={`${arabic.variable} ${latin.variable} h-full antialiased`}
    >
      <body className="min-h-full flex flex-col">{children}</body>
    </html>
  );
}
