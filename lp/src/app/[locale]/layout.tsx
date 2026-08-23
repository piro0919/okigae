import { Analytics } from "@vercel/analytics/next";
import type { Metadata } from "next";
import { M_PLUS_Rounded_1c } from "next/font/google";
import { notFound } from "next/navigation";
import { hasLocale, NextIntlClientProvider } from "next-intl";
import { getTranslations, setRequestLocale } from "next-intl/server";
import type { ReactNode } from "react";
import { routing } from "@/i18n/routing";
import "./globals.css";

// 丸ゴシック。角の取れた字面が、キャラの太い輪郭と揃う
const rounded = M_PLUS_Rounded_1c({
  display: "swap",
  subsets: ["latin"],
  variable: "--font-rounded",
  weight: ["400", "500", "700", "800", "900"],
});

type LayoutProps = {
  children: ReactNode;
  params: Promise<{ locale: string }>;
};

export function generateStaticParams() {
  return routing.locales.map((locale) => ({ locale }));
}

export async function generateMetadata({
  params,
}: Omit<LayoutProps, "children">): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "meta" });

  return {
    description: t("description"),
    icons: { icon: "/icon.png" },
    alternates: {
      canonical: locale === routing.defaultLocale ? "/" : `/${locale}`,
      languages: Object.fromEntries(
        routing.locales.map((one) => [one, one === routing.defaultLocale ? "/" : `/${one}`]),
      ),
    },
    metadataBase: new URL("https://okigae.kkweb.io"),
    openGraph: {
      description: t("description"),
      title: t("title"),
      type: "website",
      url: locale === routing.defaultLocale ? "/" : `/${locale}`,
    },
    title: t("title"),
    twitter: {
      card: "summary_large_image",
      description: t("description"),
      title: t("title"),
    },
  };
}

export default async function Layout({ children, params }: LayoutProps) {
  const { locale } = await params;

  if (!hasLocale(routing.locales, locale)) {
    notFound();
  }
  setRequestLocale(locale);

  return (
    <html className={rounded.variable} lang={locale}>
      <body className="font-[family-name:var(--font-rounded)] antialiased">
        <NextIntlClientProvider>{children}</NextIntlClientProvider>
        <Analytics />
      </body>
    </html>
  );
}
