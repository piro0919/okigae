import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { ImageResponse } from "next/og";
import { routing } from "@/i18n/routing";

export const alt = "Okigae";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

/* ビルド時に焼く。動的なままだと public/ が関数側に含まれず、
   本番で icon.png を読めずに 500 になる */
export function generateStaticParams(): { locale: string }[] {
  return routing.locales.map((locale) => ({ locale }));
}

/* 実在のアプリ（Linear / Setapp）と同じく、アイコンと名前を横に並べる。
   前は説明2行とメニューバーの帯と URL を詰め込んでいて、
   一覧に出る 176px では読めなかった。色はアイコンから取る */
const CREAM = "#faf4e4";
const INK = "#3d2a19";
const YELLOW = "#c9971a";

export default async function OgImage({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<ImageResponse> {
  const { locale } = await params;
  const isJa = locale === "ja";
  const [icon, font] = await Promise.all([
    readFile(join(process.cwd(), "public/icon.png")),
    readFile(join(process.cwd(), "assets/ZenMaruGothic-Bold-subset.ttf")),
  ]);
  const iconSrc = `data:image/png;base64,${icon.toString("base64")}`;

  return new ImageResponse(
    <div
      style={{
        alignItems: "center",
        background: CREAM,
        display: "flex",
        gap: 56,
        height: "100%",
        justifyContent: "center",
        width: "100%",
      }}
    >
      {/* biome-ignore lint/performance/noImgElement: next/image is not available in ImageResponse */}
      <img alt="" height={230} src={iconSrc} width={230} />
      <div style={{ display: "flex", flexDirection: "column" }}>
        <div style={{ color: INK, display: "flex", fontSize: 112, letterSpacing: -2 }}>
          Okigae
        </div>
        <div style={{ color: YELLOW, display: "flex", fontSize: 34, marginTop: 14 }}>
          {isJa ? "メニューバーに顔を出す" : "Put a face on your menu bar"}
        </div>
      </div>
    </div>,
    {
      ...size,
      fonts: [
        { data: font, name: "Zen Maru Gothic", style: "normal", weight: 700 },
      ],
    },
  );
}
