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
  metadataBase: new URL("https://debber-web.vercel.app"),
  title: {
    default: "دبّر | ميزانية البيت ببساطة",
    template: "%s | دبّر",
  },
  description:
    "خطّط ميزانية الشهر، تابع المصروف، وشارك فقط ما يناسبك مع أفراد البيت.",
  openGraph: {
    title: "دبّر | ميزانية البيت ببساطة",
    description:
      "خطّط ميزانية الشهر، تابع المصروف، وشارك فقط ما يناسبك مع أفراد البيت.",
    type: "website",
    url: "/",
    siteName: "دبّر",
    locale: "ar_EG",
    images: [
      {
        url: "/brand/dabber-social-preview.png",
        width: 1200,
        height: 630,
        alt: "دبّر — ميزانية البيت ببساطة",
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title: "دبّر | ميزانية البيت ببساطة",
    description:
      "خطّط ميزانية الشهر، تابع المصروف، وشارك فقط ما يناسبك مع أفراد البيت.",
    images: [
      {
        url: "/brand/dabber-social-preview.png",
        alt: "دبّر — ميزانية البيت ببساطة",
      },
    ],
  },
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
