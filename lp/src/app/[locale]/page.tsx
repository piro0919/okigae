import Image from "next/image";
import { getTranslations, setRequestLocale } from "next-intl/server";
import type { ReactNode } from "react";
import { Link } from "@/i18n/navigation";
import { LanguageSwitch } from "./language-switch";

const REPO = "https://github.com/piro0919/okigae";
const DOWNLOAD = `${REPO}/releases/latest`;

const CHARACTERS = [
  "momoka",
  "ruri",
  "konoha",
  "hinata",
  "akane",
  "sumire",
  "kuroha",
  "yuki",
  "himari",
  "mio",
] as const;

const FEATURES = ["alive", "blend", "assign", "own"] as const;

function DownloadButton({
  children,
  tone = "dark",
}: {
  children: ReactNode;
  tone?: "dark" | "light";
}) {
  const skin =
    tone === "dark"
      ? "bg-[var(--color-ink)] text-[var(--color-cream)] hover:bg-[var(--color-bar)]"
      : "bg-[var(--color-yellow)] text-[var(--color-ink)] hover:bg-[var(--color-yellow-soft)]";

  return (
    <a
      className={`inline-flex items-center rounded-full px-8 py-4 font-bold text-lg transition ${skin}`}
      href={DOWNLOAD}
    >
      {children}
    </a>
  );
}

/// 撮ったメニューバーを、壁紙ごと切り取ってきたように見せる枠。
function BarShot({ alt, src }: { alt: string; src: string }) {
  return (
    <div className="overflow-hidden rounded-xl bg-[var(--color-wall)] pt-0 shadow-lg">
      <Image alt={alt} className="w-full" height={84} priority src={src} width={760} />
    </div>
  );
}

type PageProps = {
  params: Promise<{ locale: string }>;
};

export default async function Page({ params }: PageProps) {
  const { locale } = await params;
  setRequestLocale(locale);

  const t = await getTranslations();

  return (
    <>
      {/* 見出し。ページの上端そのものをメニューバーに見立てる */}
      <header className="bg-[var(--color-bar)] px-6 pt-3 pb-16 text-[var(--color-cream)]">
        <div className="mx-auto max-w-4xl">
          <div className="flex items-center justify-between gap-4 pb-14">
            <span className="font-bold text-sm tracking-wide opacity-70">Okigae</span>
            <LanguageSwitch />
          </div>
          <div className="flex flex-col gap-7">
            <h1 className="text-balance font-black text-5xl leading-[1.2] tracking-tight sm:text-6xl">
              {t("hero.tagline")}
            </h1>
            <p className="max-w-xl text-lg leading-relaxed opacity-75">{t("hero.lead")}</p>
            <div className="flex flex-col items-start gap-3">
              <DownloadButton tone="light">{t("hero.download")}</DownloadButton>
              <p className="text-sm opacity-50">{t("hero.requirement")}</p>
            </div>
          </div>
        </div>
      </header>

      {/* 前と後。説明より先に、同じバーの違いを見せる */}
      <section className="-mt-8 px-6 pb-24">
        <div className="mx-auto flex max-w-4xl flex-col gap-8 rounded-3xl bg-white p-6 shadow-xl sm:p-10">
          {(
            [
              ["before", "/bar-before.png"],
              ["after", "/bar-after.png"],
            ] as const
          ).map(([key, src]) => (
            <div className="flex flex-col gap-3" key={key}>
              <span className="font-bold text-sm opacity-50">{t(`compare.${key}`)}</span>
              <BarShot alt={t(`compare.${key}`)} src={src} />
            </div>
          ))}
          <p className="text-sm leading-relaxed opacity-70">{t("compare.note")}</p>
        </div>
      </section>

      {/* 同梱のキャラクター */}
      <section className="bg-[var(--color-cream-deep)] px-6 py-24">
        <div className="mx-auto flex max-w-4xl flex-col gap-12">
          <div className="flex flex-col gap-3">
            <h2 className="font-black text-4xl tracking-tight">{t("characters.title")}</h2>
            <p className="max-w-2xl leading-relaxed opacity-70">{t("characters.lead")}</p>
          </div>
          <ul className="grid grid-cols-4 gap-3 sm:grid-cols-8">
            {CHARACTERS.map((name) => (
              <li className="flex flex-col items-center gap-2" key={name}>
                <Image
                  alt=""
                  className="w-full max-w-20"
                  height={256}
                  src={`/${name}.png`}
                  width={256}
                />
                <span className="text-xs opacity-50">{t(`characters.${name}`)}</span>
              </li>
            ))}
          </ul>
        </div>
      </section>

      {/* どう動くのか */}
      <section className="px-6 py-24">
        <div className="mx-auto flex max-w-4xl flex-col gap-12">
          <h2 className="font-black text-4xl tracking-tight">{t("features.title")}</h2>
          <div className="grid gap-x-12 gap-y-10 sm:grid-cols-2">
            {FEATURES.map((key) => (
              <div
                className="flex flex-col gap-3 border-[var(--color-yellow)] border-t-4 pt-5"
                key={key}
              >
                <h3 className="font-bold text-xl">{t(`features.${key}.title`)}</h3>
                <p className="leading-relaxed opacity-70">{t(`features.${key}.body`)}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* 入れ方 */}
      <section className="bg-[var(--color-yellow-soft)] px-6 py-24">
        <div className="mx-auto flex max-w-4xl flex-col gap-6">
          <h2 className="font-black text-3xl tracking-tight">{t("install.title")}</h2>
          <p className="max-w-2xl leading-relaxed opacity-80">{t("install.body")}</p>
          <div>
            <DownloadButton>{t("install.cta")}</DownloadButton>
          </div>
        </div>
      </section>

      <footer className="bg-[var(--color-bar-deep)] px-6 py-12 text-[var(--color-cream)]">
        <div className="mx-auto flex max-w-4xl gap-6 text-sm">
          <a className="opacity-60 transition hover:opacity-100" href={REPO}>
            {t("footer.source")}
          </a>
          <a className="opacity-60 transition hover:opacity-100" href={`${REPO}/releases`}>
            {t("footer.releases")}
          </a>
          <Link className="opacity-60 transition hover:opacity-100" href="/privacy">
            {t("footer.privacy")}
          </Link>
        </div>
      </footer>
    </>
  );
}
