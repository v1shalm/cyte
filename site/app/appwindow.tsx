import Image from "next/image";
import { Icon } from "./icons";
import styles from "./appwindow.module.css";

type Tile = { h: number; kind: "art" | "link" | "type" | "dark"; tone?: string; title?: string; host?: string };

const columns: Tile[][] = [
  [
    { h: 176, kind: "art", tone: "a" },
    { h: 120, kind: "link", tone: "b", title: "Type specimen", host: "foundry.example" },
    { h: 96, kind: "type" },
  ],
  [
    { h: 112, kind: "dark" },
    { h: 188, kind: "art", tone: "c" },
    { h: 118, kind: "link", tone: "d", title: "Poster study", host: "studio.example" },
  ],
  [
    { h: 134, kind: "link", tone: "e", title: "Motion notes", host: "journal.example" },
    { h: 150, kind: "art", tone: "f" },
    { h: 120, kind: "art", tone: "g" },
  ],
  [
    { h: 168, kind: "art", tone: "h" },
    { h: 100, kind: "type" },
    { h: 132, kind: "link", tone: "a", title: "Colour systems", host: "palette.example" },
  ],
];

export function AppWindow() {
  return (
    <div className={styles.window} role="img" aria-label="The Cyte window showing a grid of saved images and links">
      <div className={styles.chrome}>
        <span className={styles.light} data-c="r" />
        <span className={styles.light} data-c="y" />
        <span className={styles.light} data-c="g" />
      </div>
      <div className={styles.rail}>
        <Image src="/pool-icon.png" alt="" width={34} height={34} className={styles.mark} />
        <span className={`${styles.railIcon} ${styles.railOn}`}>
          <Icon name="grid" size={20} />
        </span>
        <span className={styles.railIcon}>
          <Icon name="bookmark" size={20} />
        </span>
        <span className={styles.railIcon}>
          <Icon name="folder" size={20} />
        </span>
        <span className={`${styles.railIcon} ${styles.railGear}`}>
          <Icon name="gear" size={20} />
        </span>
      </div>
      <div className={styles.main}>
        <div className={styles.search}>
          <Icon name="search" size={14} />
          <span>Search Cyte</span>
          <span className={styles.searchEnd}>
            <Icon name="filter" size={14} />
            <kbd>⌘K</kbd>
          </span>
        </div>
        <div className={styles.row}>
          <div className={styles.tabs}>
            <span className={styles.tabOn}>
              Everything <i>412</i>
            </span>
            <span>
              Images <i>268</i>
            </span>
            <span>
              Links <i>131</i>
            </span>
            <span>Notes</span>
          </div>
          <span className={styles.sort}>
            <Icon name="sort" size={12} /> Newest <Icon name="chevronDown" size={10} />
          </span>
        </div>
        <div className={styles.grid}>
          {columns.map((column, c) => (
            <div className={styles.column} key={c} data-c={c}>
              {column.map((tile, t) => (
                <div
                  key={t}
                  className={`${styles.tile} ${styles[tile.kind]}`}
                  data-tone={tile.tone}
                  style={{ height: tile.h }}
                >
                  {tile.kind === "type" && <span>Aa</span>}
                  {tile.kind === "link" && (
                    <>
                      <span className={styles.linkArt} />
                      <span className={styles.linkText}>
                        <b>{tile.title}</b>
                        <em>{tile.host}</em>
                      </span>
                    </>
                  )}
                </div>
              ))}
            </div>
          ))}
        </div>
        <div className={styles.add}>
          <Icon name="plus" size={16} /> Add
        </div>
      </div>
    </div>
  );
}
