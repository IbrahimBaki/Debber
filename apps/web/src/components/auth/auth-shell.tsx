import Image from "next/image";
import Link from "next/link";
import type { ReactNode } from "react";

import styles from "./auth.module.css";

export function AuthShell({
  title,
  description,
  children,
}: {
  title: string;
  description: string;
  children: ReactNode;
}) {
  return (
    <main className={styles.page}>
      <section className={styles.shell}>
        <header className={styles.brand}>
          <Link href="/" aria-label="دبّر — الصفحة الرئيسية">
            <Image
              src="/brand/logo-primary.svg"
              alt="دبّر"
              width={142}
              height={52}
              priority
            />
          </Link>
        </header>
        <div className={styles.content}>
          <h1>{title}</h1>
          <p className={styles.description}>{description}</p>
          {children}
        </div>
      </section>
    </main>
  );
}
