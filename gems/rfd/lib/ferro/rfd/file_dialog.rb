# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT
#++

require_relative "ferro_rfd"
require_relative "handles"

module Ferro
  module Rfd
    #--
    # SPDX-SnippetBegin
    # SPDX-License-Identifier: MIT
    # SPDX-SnippetCopyrightText: 2022 Bartłomiej Maryńczak
    # SPDX-SnippetComment: FileDialog and its docs from rfd 0.17.2
    #   src/file_dialog.rs:15-175, and the crate docs in src/lib.rs:38-86
    #++

    # The system's dialog for opening and saving files.
    #
    # Asking the user for a file is easy to get wrong. A path typed at a
    # prompt has no folder browser, no preview, and none of the shortcuts
    # the user already knows. Each system has its own native dialog, with a
    # different API on each: NSOpenPanel on macOS, IFileDialog on Windows,
    # the XDG desktop portal on Linux.
    #
    # This builder shows whichever one you run on. Set its options, then
    # call a terminal method: #pick_file, #pick_files, #pick_folder,
    # #pick_folders, or #save_file (and on macOS, #pick_file_or_folder and
    # #pick_files_or_folders). Each waits for the user and returns the
    # chosen path as a String, or an Array of them, or +nil+ if the user
    # cancels.
    #
    # Use it to let the user open a document, choose where to save an
    # export, or point your tool at a folder.
    #
    # === Behavior
    #
    # Each setter returns the dialog, so calls chain. rfd's builder is used
    # up by its terminal call; this one keeps its options, and you may show
    # it again. +dup+ gives an independent copy, as rfd's +Clone+ does, and
    # a frozen dialog refuses its setters. #inspect shows rfd's own view of
    # the options, its +Debug+ text.
    #
    # The dialog waits for a person, so it releases Ruby's global VM lock
    # while it is open: other Ruby threads run meanwhile. rfd cannot cancel
    # a dialog, so Ctrl-C and <tt>Thread#kill</tt> take effect when it
    # closes, and the process does not exit until it does.
    #
    # On macOS, a dialog runs on the main thread. From another thread rfd
    # hands it to the main thread, which works only while an application
    # runs its event loop there (a windowed app); otherwise this raises
    # Error instead of letting rfd panic. AsyncFileDialog shows how to
    # start a dialog on the main thread and wait for it elsewhere.
    #
    # On Linux, rfd asks the XDG desktop portal over D-Bus, which shows the
    # desktop's own dialog (GTK, GNOME, or KDE). That needs the
    # <tt>libdbus-1</tt> library and a portal backend at run time; the
    # wlroots portal does not implement the file chooser. When the portal
    # is unreachable, rfd runs +zenity+ instead, and without +zenity+
    # either, the dialog returns +nil+ at once. If you package an app, ship
    # a portal backend and +zenity+ with it.
    #
    # Mirrors rfd's +FileDialog+ (<tt>src/file_dialog.rs:15-175</tt>).
    #
    # === Examples
    #
    #   path = Ferro::Rfd::FileDialog.new
    #     .add_filter("text", ["txt", "rs"])
    #     .add_filter("rust", ["rs", "toml"])
    #     .set_directory("/")
    #     .pick_file
    #   puts "The user chose: #{path.inspect}"
    #
    #   path = Ferro::Rfd::FileDialog.new
    #     .set_file_name("foo.txt")
    #     .set_directory(Dir.pwd)
    #     .save_file
    #
    #   folders = Ferro::Rfd::FileDialog.new.set_title("Import folders").pick_folders
    class FileDialog
      # Creates a dialog with rfd's defaults: no filters, no starting
      # directory or file name, the system's title, and no parent.
      #
      # Mirrors rfd's <tt>FileDialog::new</tt>
      # (<tt>src/file_dialog.rs:36-40</tt>), which is its +Default+.
      #
      # === Example
      #
      #   dialog = Ferro::Rfd::FileDialog.new
      def initialize
        @filters = [] #: Array[native_filter]
        @filters.freeze
        @directory = nil
        @file_name = nil
        @title = nil
        @parent = nil
        @can_create_directories = nil
      end

      # Adds a file type filter named +name+, matching the file extensions
      # in +extensions+ (without the dot, such as <tt>"txt"</tt>). Returns
      # the dialog.
      #
      # Windows and Linux show the filter's name. Platforms without filter
      # names (macOS) merge every filter into one. Each element of
      # +extensions+ becomes a String with +to_s+, as Rust's +ToString+
      # formats any value. A NUL byte in the name or an extension raises
      # +ArgumentError+: rfd's portal backend would panic on it.
      #
      # Mirrors rfd's <tt>FileDialog::add_filter</tt>
      # (<tt>src/file_dialog.rs:42-57</tt>).
      #
      # === Example
      #
      #   Ferro::Rfd::FileDialog.new.add_filter("Images", ["png", "jpg"]).pick_file
      def add_filter(name, extensions)
        @filters = [*@filters, Rfd.__send__(:filter, name, extensions)].freeze
        self
      end

      # Starts the dialog in +path+, a String or an object with +to_path+.
      # An empty path clears it, as rfd does. Returns the dialog.
      #
      # Supported on Linux, Windows, and macOS.
      #
      # Mirrors rfd's <tt>FileDialog::set_directory</tt>
      # (<tt>src/file_dialog.rs:59-71</tt>).
      #
      # === Example
      #
      #   Ferro::Rfd::FileDialog.new.set_directory(Dir.home).pick_file
      def set_directory(path)
        @directory = -File.path(path)
        self
      end

      # Fills in +file_name+ as the starting file name. Returns the dialog.
      #
      # Supported on Windows, Linux, and macOS.
      #
      # Mirrors rfd's <tt>FileDialog::set_file_name</tt>
      # (<tt>src/file_dialog.rs:73-80</tt>).
      #
      # === Example
      #
      #   Ferro::Rfd::FileDialog.new.set_file_name("report.csv").save_file
      def set_file_name(file_name)
        @file_name = Rfd.__send__(:string, file_name)
        self
      end

      # Titles the dialog +title+. Returns the dialog.
      #
      # Supported on Windows, Linux, and macOS (where it shows as the
      # panel's message).
      #
      # Mirrors rfd's <tt>FileDialog::set_title</tt>
      # (<tt>src/file_dialog.rs:82-89</tt>).
      #
      # === Example
      #
      #   Ferro::Rfd::FileDialog.new.set_title("Choose a backup").pick_file
      def set_title(title)
        @title = Rfd.__send__(:string, title)
        self
      end

      # Keeps the dialog in front of +parent+'s window. Returns the dialog.
      #
      # rfd takes any value that can name its window and display. In Ruby
      # that is any object that answers +window_handle+ and
      # +display_handle+, each returning a handle value or +nil+ for one
      # it cannot give (rfd then has none). The handle values are
      # Win32WindowHandle, XlibWindowHandle, XcbWindowHandle, and
      # AppKitWindowHandle for the window, and WindowsDisplayHandle,
      # XlibDisplayHandle, XcbDisplayHandle, and AppKitDisplayHandle for
      # the display. A value from another gem works too when its class is
      # named for the same raw-window-handle struct and answers that
      # struct's fields, so a window library's own handles cross as they
      # are. Both are read now, as rfd reads them.
      #
      # ferro-rfd binds only handles that cannot crash your process when
      # wrong. On Windows, Win32WindowHandle: an +HWND+, which Windows
      # checks. On Linux, XlibWindowHandle and XcbWindowHandle: an X11
      # window ID, which the portal receives as text. On macOS,
      # AppKitWindowHandle: a window number, which AppKit looks up when the
      # dialog runs. Wayland handles are pointers rfd follows, so they are
      # not bound and raise +TypeError+. A handle rfd cannot use here
      # raises +ArgumentError+ with rfd's message: on Windows, any but
      # Win32WindowHandle; on macOS, any but AppKitWindowHandle. On Linux,
      # rfd ignores a handle it cannot use. Without a parent, rfd's macOS
      # async dialogs attach to the app's main window anyway.
      #
      # On macOS the window is looked up on the main thread, each time the
      # dialog runs or #inspect describes it. On the main thread that
      # happens at once. From another thread, the lookup and the dialog
      # run on the main thread through your running app, as rfd runs any
      # dialog from another thread, and wait for its run loop; with no
      # running app, the call raises Error. The main thread has to be in
      # its run loop for that wait to end: if it is blocked in Ruby
      # instead, say joining this thread, the call never returns, and
      # neither Ctrl-C nor Thread#kill reaches it, as with rfd's own hop. A number that names none of
      # your app's windows, or a window without a content view, raises
      # Error, where rfd would crash.
      #
      # The parent counts only while its window exists. Keep it open until
      # the dialog closes.
      #
      # Mirrors rfd's <tt>FileDialog::set_parent</tt>
      # (<tt>src/file_dialog.rs:91-103</tt>).
      #
      # === Example
      #
      #   Parent = Data.define(:window_handle, :display_handle)
      #   window = Parent.new(Ferro::Rfd::Win32WindowHandle.new(hwnd: my_hwnd),
      #     Ferro::Rfd::WindowsDisplayHandle.new)
      #   Ferro::Rfd::FileDialog.new.set_parent(window).pick_file
      def set_parent(parent)
        @parent = Rfd.__send__(:parent_pair, parent)
        self
      end

      # Lets the user create folders from the dialog when +can+ is truthy,
      # or forbids it. Returns the dialog.
      #
      # Supported on macOS. Folder pickers there allow it unless you
      # forbid it.
      #
      # Mirrors rfd's <tt>FileDialog::set_can_create_directories</tt>
      # (<tt>src/file_dialog.rs:105-110</tt>).
      #
      # === Example
      #
      #   Ferro::Rfd::FileDialog.new.set_can_create_directories(false).pick_folder
      def set_can_create_directories(can)
        @can_create_directories = can ? true : false
        self
      end

      # Asks the user for one file. Returns its path, or +nil+ if the user
      # cancels.
      #
      # Mirrors rfd's <tt>FileDialog::pick_file</tt>
      # (<tt>src/file_dialog.rs:121-124</tt>).
      #
      # === Example
      #
      #   path = Ferro::Rfd::FileDialog.new.pick_file
      #   puts File.read(path) if path
      def pick_file
        Native.file_dialog(:pick_file, settings)
      end

      # Asks the user for one or more files. Returns their paths, or +nil+
      # if the user cancels.
      #
      # Mirrors rfd's <tt>FileDialog::pick_files</tt>
      # (<tt>src/file_dialog.rs:126-129</tt>).
      #
      # === Example
      #
      #   Ferro::Rfd::FileDialog.new.pick_files&.each { |path| puts path }
      def pick_files
        Native.file_dialog(:pick_files, settings)
      end

      # Asks the user for one folder. Returns its path, or +nil+ if the
      # user cancels.
      #
      # Mirrors rfd's <tt>FileDialog::pick_folder</tt>
      # (<tt>src/file_dialog.rs:131-134</tt>).
      #
      # === Example
      #
      #   folder = Ferro::Rfd::FileDialog.new.pick_folder
      def pick_folder
        Native.file_dialog(:pick_folder, settings)
      end

      # Asks the user for one or more folders. Returns their paths, or
      # +nil+ if the user cancels.
      #
      # Mirrors rfd's <tt>FileDialog::pick_folders</tt>
      # (<tt>src/file_dialog.rs:136-139</tt>).
      #
      # === Example
      #
      #   folders = Ferro::Rfd::FileDialog.new.pick_folders
      def pick_folders
        Native.file_dialog(:pick_folders, settings)
      end

      # Asks the user where to save a file. Returns the path, or +nil+ if
      # the user cancels. Nothing is written; the path is yours to use.
      #
      # Filters work differently here on each platform:
      #
      # - On macOS, with a filter set, every file is grayed out, whatever
      #   its extension. If the user types no extension, macOS appends the
      #   first one from the filters. If they type one the filters lack,
      #   macOS says so.
      # - On Linux, filters only choose which existing files show. No
      #   extension is appended, and the user may type any.
      # - On Windows, a name without an extension gets the selected
      #   filter's. A name with the selected extension stays as typed. A
      #   name with another extension gets the selected one appended, as in
      #   <tt>test.png.txt</tt>.
      #
      # Mirrors rfd's <tt>FileDialog::save_file</tt>
      # (<tt>src/file_dialog.rs:157-174</tt>).
      #
      # === Example
      #
      #   path = Ferro::Rfd::FileDialog.new.add_filter("CSV", ["csv"]).save_file
      #   File.write(path, csv) if path
      def save_file
        Native.file_dialog(:save_file, settings)
      end

      # rfd's +Debug+ text for this dialog, which shows every option as rfd
      # holds it.
      #
      # On macOS, with an AppKitWindowHandle parent, it looks the window up
      # as the dialog would, to show the content view rfd gets, and raises
      # the Error the dialog would. From another thread it waits for the
      # main thread's run loop, uninterruptibly, as #set_parent explains.
      #
      # === Example
      #
      #   Ferro::Rfd::FileDialog.new.set_title("Open").inspect
      #   # => "FileDialog { filters: [], starting_directory: None, file_name: None, title: Some(\"Open\"), ... }"
      def inspect
        Native.file_dialog_debug(settings)
      end

      # The options, in the order the native layer takes them.
      private def settings
        [@filters, @directory, @file_name, @title, @parent, @can_create_directories]
      end
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
