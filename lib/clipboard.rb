# frozen_string_literal: true

require "gtk4"

module Authenticator
  # Clipboard copies an OTP code to the system clipboard, and clears it again
  # when the application quits.
  #
  # Ported from Authenticator/models/clipboard.py. Upstream uses GTK 3's
  # `Gtk::Clipboard.get(Gdk::SELECTION_CLIPBOARD)`; GTK 4 moved the clipboard
  # onto the display as `Gdk::Display#clipboard`, and `clear` became "set the
  # contents to nothing" rather than a method of its own.
  class Clipboard
    class << self
      def set(string)
        clipboard&.set(string.to_s)
      end

      # Upstream clears the clipboard on quit so a code does not outlive the
      # application; the GTK 4 way to say that is to store an empty string.
      def clear
        clipboard&.set("")
      end

      private

        # nil before a display is open, which is the case in a spec that has
        # not built a window yet.
        def clipboard = Gdk::Display.default&.clipboard
    end
  end
end
