import Foundation

enum L {
    enum Onboarding {
        static func welcomeTitle(_ name: String) -> String { name.isEmpty ? "Hello." : "Hello, \(name)." }
        static let welcomeBody = "Everything you save, in one place."
        static let welcomePrimary = "Show me my screenshots"
        static let welcomeSecondary = "Start empty"

        static let libraryTitle = "Where should it live?"
        static let libraryBody = "Cyte keeps your saves as plain files in one folder. In iCloud Drive, your iPhone sees them too."
        static let libraryPrimary = "Use iCloud Drive"
        static let libraryGoogleDrive = "Use Google Drive"
        static let libraryLocal = "Keep it on this Mac"
        static let librarySecondary = "Choose a folder"
        static let libraryNoICloud = "iCloud Drive is off on this Mac. Pick Google Drive or a folder on this Mac."

        static let doneTitle = "Cyte is ready."
        static let doneBody = "Drop anything on the window, paste with ⌘V, or press ⌥⌘P from any app."
        static let doneButton = "Open Cyte"

        static let sound = "Sound"
        static let skipHint = "esc to skip"
    }

    enum Empty {
        static let title = "Nothing saved yet"
        static let body = "Everything you save lands here as a tile."
        static let primary = "Paste from clipboard"
        static let secondary = "Choose files"
    }

    enum Search {
        static let placeholder = "Search Cyte"
        static func emptyTitle(_ query: String) -> String { "No saves match “\(query)”" }
        static let emptyBody = "Cyte looked through titles, tags, notes and the text inside images."
        static let emptyPrimary = "Clear search"
        static let clear = "Clear search"
        static let related = "Close in meaning"
    }

    enum Toast {
        static let saved = "Saved"
        static func savedMany(_ count: Int) -> String { "Saved \(count) items" }
        static let screenshot = "Screenshot saved"
        static let deleted = "Moved to Trash"
        static let undo = "Undo"
        static let nothingToPaste = "Your clipboard has no image, link or text"
        static let copied = "Copied"
        static let duplicate = "You already saved this link"
        static let noSimilar = "Nothing in your library looks like this yet"
        static let duplicateImage = "You already saved this image"
        static func librarySwitched(_ place: String) -> String { "Opened your library in \(place)" }
        static func libraryMoved(_ count: Int, to place: String) -> String { count == 1 ? "Moved 1 save to \(place)" : "Moved \(count) saves to \(place)" }
    }

    enum Video {
        static let play = "Play"
        static let pause = "Pause"
        static let mute = "Mute"
        static let unmute = "Unmute"
        static let position = "Playback position"
    }

    enum Select {
        static func count(_ n: Int) -> String { "\(n) selected" }
        static let folder = "Add to folder"
        static let tag = "Tag"
        static let delete = "Delete"
        static let clear = "Clear selection"
        static let newFolder = "New folder"
        static let tagPlaceholder = "Add a tag"
        static let noFolders = "No folders yet"
        static func deletedMany(_ n: Int) -> String { "\(n) saves moved to Trash" }
        static func tagged(_ tag: String, _ n: Int) -> String { n == 1 ? "Tagged #\(tag)" : "Tagged \(n) saves #\(tag)" }
    }

    enum EmptyState {
        static let folderTitle = "This folder is empty"
        static let folderBody = "Drag saves onto it, or select tiles and choose Add to folder."
        static let smartBody = "Saves that match this smart folder show up here on their own."
        static let browse = "Browse everything"
        static let filterTitle = "No saves match these filters"
        static let filterBody = "Widen the date range or remove a tag to see more."
    }

    enum Trash {
        static let title = "Trash"
        static let emptyTitle = "Trash is empty"
        static let emptyBody = "Saves you delete wait here for 30 days, then Cyte removes them for good."
        static let restore = "Restore"
        static let deleteNow = "Delete now"
        static let emptyTrash = "Empty trash"
        static func daysLeft(_ n: Int) -> String { n == 1 ? "1 day left" : "\(n) days left" }
        static func confirmOne(_ title: String) -> String {
            let short = title.count > 28 ? title.prefix(27) + "…" : Substring(title)
            return "Delete “\(short)” for good?"
        }
        static func confirmAll(_ n: Int) -> String { n == 1 ? "Delete 1 save for good?" : "Delete \(n) saves for good?" }
        static func confirmYes(_ n: Int) -> String { n == 1 ? "Delete save" : "Delete \(n) saves" }
        static let keep = "Keep in Trash"
        static let restored = "Restored to Everything"
        static let restoreFailed = "Cyte couldn't restore this save. Its files are still in Trash."
        static func erased(_ n: Int) -> String { n == 1 ? "Deleted 1 save for good" : "Deleted \(n) saves for good" }
    }

    enum Viewing {
        static let title = "View"
        static let sort = "Sort"
        static let size = "Tile size"
        static func saves(_ n: Int) -> String { n == 1 ? "1 save" : "\(n) saves" }
    }

    enum Settings {
        static let title = "Settings"
        static let library = "Library"
        static let libraryBody = "Everything you save lives in this folder. Pick a new place and Cyte moves your saves there."
        static func moveTitle(_ place: String) -> String { "Move your library to \(place)?" }
        static func moveBody(_ count: Int, from: String, to: String) -> String {
            let saves = count == 1 ? "1 save" : "\(count) saves"
            return "Cyte moves \(saves) from \(from) to \(to)."
        }
        static let moveLeavesICloud = "Your iPhone only sees saves in iCloud Drive."
        static func moveConfirm(_ count: Int) -> String { count == 1 ? "Move 1 save" : "Move \(count) saves" }
        static let cancel = "Cancel"
        static let iCloudDrive = "iCloud Drive"
        static let googleDrive = "Google Drive"
        static let localFolder = "This Mac"
        static let customFolder = "Other folder"
        static let change = "Choose folder…"
        static let show = "Show in Finder"
        static let general = "General"
        static let storage = "Storage"
        static let folder = "Folder"
        static func version(_ v: String) -> String { "Cyte \(v)" }
        static let reports = "Problem reports"
        static func reportsTitle(_ n: Int) -> String { n == 1 ? "Cyte saved 1 problem report" : "Cyte saved \(n) problem reports" }
        static let reportsBody = "Each one holds technical details about a crash or a slowdown on this Mac, and nothing from your library. Nothing leaves this Mac unless you send it."
        static let reportsSend = "Email reports"
        static let reportsShow = "Show in Finder"
        static let reportsDelete = "Delete reports"
        static func reportSubject(version: String) -> String { "Cyte \(version) problem report" }
        static let reportBody = "The attached reports came from Cyte on my Mac."
        static let updates = "Check for updates automatically"
        static let updatesBody = "Cyte looks for a new version once a day and asks before it installs anything."
        static let intelligence = "Titles and tags"
        static let aiOffTitle = "Apple Intelligence is off"
        static let aiOffBody = "Cyte writes titles, summaries and tags with Apple Intelligence on this Mac. Turn it on in System Settings → Apple Intelligence & Siri."
        static let aiOffAction = "Open Apple Intelligence settings"
        static let aiDownloadingTitle = "Apple Intelligence is still downloading"
        static let aiDownloadingBody = "Cyte starts writing titles and tags when the download finishes. Your saves keep working until then."
        static let aiUnsupportedTitle = "This Mac can't run Apple Intelligence"
        static let aiUnsupportedBody = "Cyte still reads text in your images, pulls colours and finds similar saves. Titles and tags come from the file and the page."
        static let login = "Open Cyte at login"
        static let loginBody = "Cyte starts in the menu bar so saving is always one shortcut away."
        static let sounds = "Sounds"
        static let soundsBody = "Soft cues when you save, delete or drop."
        static let askWhy = "Ask why you saved it"
        static let askWhyBody = "After each save, Cyte asks for a line about why. Your answer shows on the tile and in the save's details."
        static let screenshots = "Save screenshots"
        static let screenshotsBody = "New screenshots on your Mac land in Cyte as they are taken."
        static let shortcuts = "Shortcuts"
        static let about = "About"
    }

    enum Detail {
        static let tags = "Tags"
        static let addTag = "Add tag"
        static let note = "Why you saved it"
        static let notePlaceholder = "Add why you saved this"
        static let summary = "Summary"
        static let similar = "Similar saves"
        static let text = "Text in image"
        static let openLink = "Open link"
        static let copy = "Copy"
        static let reveal = "Show in Finder"
        static let delete = "Delete"
        static let reading = "Reading this save"
        static let folders = "Folders"
        static let showAll = "Show all"
        static let showLess = "Show less"
    }

    enum Filter {
        static let all = "All"
        static let images = "Images"
        static let links = "Links"
        static let notes = "Notes"
        static let title = "Filter"
        static let added = "Added"
        static let anyTime = "Any time"
        static let today = "Today"
        static let thisWeek = "This week"
        static let thisMonth = "This month"
        static let colour = "Colour"
        static let sites = "Sites"
        static let tags = "Tags"
        static let yourTags = "Your tags"
        static let autoTags = "Found in images"
        static let clear = "Clear filters"
        static let remove = "Removes this filter"
        static let empty = "No tags yet. Open a save and add one, or right-click it and choose Tag."
        static let tag = "Tag"
        static let newTag = "New tag"
        static let newTagPrompt = "Name the tag"
        static let create = "Add tag"
        static let cancel = "Cancel"
    }

    enum Similar {
        static func chip(_ title: String) -> String { "Similar to \(title.prefix(22))" }
        static let save = "Save as smart folder"
        static let find = "Find similar"
        static let select = "Select"
    }

    enum Menu {
        static let checkUpdates = "Check for updates…"
        static let sendReport = "Send a problem report…"
        static let saveClipboard = "Save clipboard"
        static let open = "Open Cyte"
        static let newNote = "New note"
        static let replayOnboarding = "Replay onboarding"
        static let copyBookmarklet = "Copy browser bookmarklet"
        static let sound = "Sound effects"
        static let quit = "Quit Cyte"
    }

    enum Note {
        static let placeholder = "Write something to keep"
        static let save = "Save note"
        static let cancel = "Discard"
        static let discardQuestion = "Discard this note?"
        static let discardYes = "Discard"
        static let discardNo = "Keep writing"
    }

    enum Palette {
        static let title = "Search"
        static let placeholder = "Search Cyte or type a command"
        static let recent = "Recent"
        static let saves = "Saves"
        static let actions = "Actions"
        static let saveLink = "Save this link"
        static func noteFrom(_ text: String) -> String { "Write a note: \(text)" }
        static let showInGrid = "Show results in the grid"
        static let open = "Open"
        static let move = "Move"
        static let close = "Close"
    }

    enum Voice {
        static let listening = "Listening…"
        static let denied = "Cyte needs microphone and speech access. Turn them on in System Settings → Privacy & Security."
        static let failed = "Speech recognition isn't available right now."
        static let save = "Save note"
        static let discard = "Discard"
        static let search = "Search by voice"
        static let stop = "Stop listening"
        static let speakNote = "Speak a note"
    }

    enum Sort {
        static let newest = "Newest"
        static let oldest = "Oldest"
        static let shuffle = "Shuffle"
        static let label = "Sort"
    }

    enum Actions {
        static let open = "Open link"
        static let addToFolder = "Add to folder"
        static let delete = "Delete"
    }

    enum Sidebar {
        static func count(_ n: Int) -> String { n == 1 ? "1 save" : "\(n) saves" }
        static let noFolders = "Make a folder to group saves for a project or a mood."
        static let iCloud = "iCloud Drive"
    }

    enum Folders {
        static let title = "Folders"
        static let new = "New folder"
        static let untitled = "Untitled folder"
        static let addTo = "Add to folder"
        static let removeFrom = "Remove from this folder"
        static let rename = "Rename"
        static let delete = "Delete folder"
        static let emptyTitle = "This folder is empty"
        static let emptyBody = "Drag a save onto Folders in the dock, or choose Add to folder on any save."
        static let addHint = "Saves you add here go into this folder."
        static let find = "Find a folder"
        static let seeAll = "All folders"
        static func noMatch(_ text: String) -> String { "No folder named “\(text)”" }
        static let everything = "Everything"
        static let allFolders = "Folders"
        static func added(_ name: String) -> String { "Added to \(name)" }
    }

    enum Add {
        static let button = "Add"
        static let close = "Close add menu"
        static let link = "Save a link"
        static let title = "Add to Cyte"
        static let linkPlaceholder = "Paste a link and press return"
        static let linkInvalid = "Links look like site.com or https://site.com"
        static func saveHost(_ host: String) -> String { "Save \(host)" }
        static let images = "Choose images or videos"
        static let note = "Write a note"
        static let paste = "Paste clipboard"
        static let hint = "You can also drag anything onto the window."
        static let here = "Add here"
        static func into(_ name: String) -> String { "Add to \(name)" }
        static let done = "Done"
        static let folder = "Folder"
        static let saving = "Saving…"
    }

    enum Why {
        static func question(_ count: Int) -> String { count > 1 ? "Why are you saving these \(count)?" : "Why are you saving this?" }
        static func savedFrom(_ message: String, _ host: String) -> String { "\(message) from \(host)" }
        static let listening = "Listening"
        static let speak = "Say why"
        static let stopListening = "Stop listening"
        static let keep = "Keep this reason"
        static let skip = "Skip"
        static let noted = "Noted"
    }

    static let dropOverlay = "Drop to save"
}
