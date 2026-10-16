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
        static let related = "Close in meaning"
    }

    enum Toast {
        static let saved = "Saved"
        static func savedMany(_ count: Int) -> String { "Saved \(count) items" }
        static let screenshot = "Screenshot saved"
        static let deleted = "Moved to trash"
        static let undo = "Undo"
        static let nothingToPaste = "Your clipboard has no image, link or text"
        static let copied = "Copied"
        static let duplicate = "You already saved this link"
        static let noSimilar = "Nothing in your library looks like this yet"
        static let duplicateImage = "You already saved this image"
        static func xVideos(_ count: Int) -> String { count == 1 ? "1 X bookmark now plays as video" : "\(count) X bookmarks now play as video" }
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
        static func deletedMany(_ n: Int) -> String { "\(n) saves moved to trash" }
        static func tagged(_ tag: String, _ n: Int) -> String { n == 1 ? "Tagged #\(tag)" : "Tagged \(n) saves #\(tag)" }
    }

    enum EmptyState {
        static let folderTitle = "This folder is empty"
        static let folderBody = "Drag saves onto it, or select tiles and choose Add to folder."
        static let smartBody = "Saves that match this smart folder show up here on their own."
        static let browse = "Browse everything"
        static let filterTitle = "No saves match these filters"
        static let filterBody = "Widen the date range or remove a tag to see more."
        static let bookmarksTitle = "No X bookmarks yet"
        static let bookmarksBody = "Import your X bookmarks and the posts with images or videos land here."
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
        static let login = "Open Cyte at login"
        static let loginBody = "Cyte starts in the menu bar so saving is always one shortcut away."
        static let sounds = "Sounds"
        static let soundsBody = "Soft cues when you save, delete or drop."
        static let screenshots = "Save screenshots"
        static let screenshotsBody = "New screenshots on your Mac land in Cyte as they are taken."
        static let x = "X bookmarks"
        static let xConnected = "Connected through your browser login"
        static let xOff = "Not connected"
        static let shortcuts = "Shortcuts"
        static let about = "About"
    }

    enum Detail {
        static let tags = "Tags"
        static let addTag = "Add tag"
        static let note = "Note"
        static let notePlaceholder = "Write a note"
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
        static let all = "Everything"
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
        static let emptyBody = "Drag saves onto the folder in the sidebar, or choose Add to folder on any save."
        static let showSidebar = "Show sidebar"
        static let hideSidebar = "Hide sidebar"
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
    }

    enum X {
        static let source = "X bookmarks"
        static let connect = "Connect"
        static let syncing = "Importing"
        static let importAction = "Import X bookmarks"
        static let disconnect = "Disconnect X"
        static let syncNow = "Import new bookmarks"
        static let introTitle = "Bring in your X bookmarks"
        static func introBody(_ browser: String?) -> String {
            "Cyte uses the X login you already have in \(browser ?? "your browser"). It brings in bookmarked posts that have images or videos and skips text-only posts."
        }
        static let introPrivacy = "macOS asks once to let Cyte read that login. Choose Always Allow so later imports run on their own."
        static let start = "Import bookmarks"
        static let cancel = "Cancel"
        static let loading = "Opening your bookmarks"
        static let importing = "Importing your bookmarks"
        static func progress(found: Int, added: Int) -> String {
            found == 0 ? "Waiting for X to send the first page" : "\(added) with images or videos out of \(found) checked"
        }
        static let keepOpen = "Keep this window open until Cyte finishes."
        static let stop = "Stop"
        static func doneTitle(_ n: Int) -> String {
            switch n {
            case 0: "Your bookmarks are up to date"
            case 1: "1 bookmark imported"
            default: "\(n) bookmarks imported"
            }
        }
        static let doneBody = "Cyte brought in posts with images or videos. Search from:x.com any time to see them."
        static let showThem = "Show them"
        static let done = "Done"
        static let failedTitle = "X didn't send your bookmarks"
        static let noLoginTitle = "Cyte can't find your X login"
        static let noLogin = "Sign in at x.com in Dia, Chrome or Arc, then try again. Cyte borrows that login, so you never sign in here."
        static let failedLimited = "X slows down accounts that load many bookmarks at once. Wait about 15 minutes, then try again."
        static let failedNoPage = "Your bookmarks page didn't load in time. Try again, and sign in once more if X asks."
        static let tryAgain = "Try again"
        static let close = "Close"
    }

    static let dropOverlay = "Drop to save"
}
