import type { Metadata } from "next";
import { DocPage, issues } from "../doc";

export const metadata: Metadata = {
  title: "Privacy · Cyte",
  description: "Cyte has no accounts and no servers. Your library is a folder you choose, and Cyte reads it on your Mac.",
};

export default function Privacy() {
  return (
    <DocPage
      title="Privacy"
      updated="16 October 2026"
      lede="Cyte has no accounts, no analytics and no servers of its own. Your library is a folder you choose, and Cyte does its work on your Mac."
    >
      <h2>Where your saves live</h2>
      <p>
        Every save is a folder of plain files inside the library folder you pick: iCloud Drive, Google Drive or a folder
        on your Mac. Cyte keeps a small index of that folder in your Mac&apos;s Application Support so it opens fast. You
        can read, move or delete any of these files yourself.
      </p>
      <p>
        If your library sits in iCloud Drive or Google Drive, Apple or Google stores and syncs it under their own terms.
        Cyte never sends it anywhere else.
      </p>

      <h2>What Cyte works out on your Mac</h2>
      <ul>
        <li>Text inside images, colours, and which saves look alike, using Apple&apos;s Vision framework.</li>
        <li>Titles, summaries and tags, using Apple Intelligence on your Mac when it is turned on.</li>
        <li>
          Voice notes and voice search. Your Mac turns speech into text by itself when it can. On a Mac without on-device
          speech, Apple&apos;s speech service does it, under Apple&apos;s privacy policy.
        </li>
      </ul>

      <h2>When Cyte goes online</h2>
      <ul>
        <li>
          <b>Saving a link.</b> Cyte opens that page to fetch its title, description and preview image, the same way a
          browser would. The site sees a request from your Mac.
        </li>
        <li>
          <b>Importing X bookmarks.</b> Cyte reads the X login already in your browser, with your permission, and uses it
          only to open your bookmarks on x.com from your Mac. It then downloads those posts&apos; images and videos from
          X. Your login never goes anywhere except x.com.
        </li>
        <li>
          <b>Checking for updates.</b> Once a day, if you leave it on, Cyte asks this website whether a new version
          exists. That request carries your Cyte and macOS version and nothing from your library.
        </li>
      </ul>

      <h2>Problem reports</h2>
      <p>
        When Cyte crashes or stalls, macOS hands it a technical report. Cyte keeps these reports on your Mac for 90 days.
        They contain no saves, file names or text from your library. A report leaves your Mac only if you choose Send in
        Settings or the Help menu, which opens an email you can read before you send it.
      </p>

      <h2>This website</h2>
      <p>
        The site is hosted on Vercel, which keeps standard server logs such as IP addresses for a short time. The site
        sets no cookies and runs no analytics.
      </p>

      <h2>Questions</h2>
      <p>
        Open an issue on <a href={issues}>GitHub</a> and you will get an answer there.
      </p>
    </DocPage>
  );
}
