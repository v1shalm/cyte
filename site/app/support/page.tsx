import type { Metadata } from "next";
import { DocPage, issues } from "../doc";

export const metadata: Metadata = {
  title: "Support · Cyte",
  description: "Answers for installing Cyte, keeping your library in sync and reporting a problem.",
};

export default function Support() {
  return (
    <DocPage
      title="Support"
      updated="20 October 2026"
      lede="Answers to the questions people ask most. If yours is not here, open an issue on GitHub."
    >
      <h2>Installing</h2>
      <h3>macOS says it cannot check Cyte for malicious software</h3>
      <p>
        Open System Settings → Privacy &amp; Security, scroll to Security and choose Open Anyway next to Cyte. You only
        do this once.
      </p>
      <h3>What Cyte needs</h3>
      <p>A Mac with Apple silicon running macOS 26 or later.</p>

      <h2>Your library</h2>
      <h3>Where are my saves?</h3>
      <p>
        In the folder shown in Settings → Library. Choose Show in Finder to open it. Each save is a folder holding the
        original file, a preview and a <code>save.json</code> with its title, tags and note.
      </p>
      <h3>How do I get my saves on another Mac or my iPhone?</h3>
      <p>
        Keep the library in iCloud Drive. Every Mac signed in to the same Apple Account sees the same saves. On iPhone,
        files you add to the library&apos;s Inbox folder show up in Cyte the next time it runs on your Mac.
      </p>
      <h3>What happens when iCloud makes two copies of a save</h3>
      <p>
        When iCloud keeps two copies of a save, Cyte keeps the newer one and moves the other to the Trash folder inside
        your library, where it stays for 30 days. Open Trash in Finder to bring a copy back.
      </p>

      <h2>Titles and tags</h2>
      <h3>My saves have no titles or tags</h3>
      <p>
        Cyte writes them with Apple Intelligence. Turn it on in System Settings → Apple Intelligence &amp; Siri. On a Mac
        that cannot run Apple Intelligence, Cyte still reads text in your images, pulls colours and finds similar saves.
      </p>

      <h2>Reporting a problem</h2>
      <p>
        If Cyte crashed, Settings shows a Problem reports section. Choose Show in Finder and attach the reports to a{" "}
        <a href={issues}>GitHub issue</a> with what you were doing when it happened. The reports hold technical details
        and nothing from your library.
      </p>
      <p>When reports exist, the Help menu in Cyte also shows Send a problem report.</p>
    </DocPage>
  );
}
