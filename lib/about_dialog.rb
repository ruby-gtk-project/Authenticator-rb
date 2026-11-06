# frozen_string_literal: true

require "adwaita"
require "gettext"

require_relative "provider_image"
require_relative "authenticator/rb/version"

module Authenticator
  # AboutDialog is the About window.
  #
  # Ported from Authenticator/widgets/about.py.in. Upstream builds a
  # Gtk::AboutDialog and runs it modally; GTK 4 removed Gtk::Dialog#run, and
  # Adwaita::AboutWindow is the shape GNOME expects now, so the port fills
  # that with upstream's credits, licence and wording. Upstream's version is
  # substituted into about.py.in at build time; here it is the gem's version.
  class AboutDialog
    include GetText

    def build(parent)
      @build ||= about_window.tap do |win|
        win.transient_for = parent
        win.modal = true
      end
    end

    def present(parent)
      build(parent).present
    end

    def about_window
      @about_window ||= Adwaita::AboutWindow.new.tap do |win|
        win.application_name = _("Authenticator")
        win.application_icon = ProviderImage::APP_ICON
        win.developer_name = "Bilal Elmoussaoui"
        win.developers = ["Bilal Elmoussaoui"]
        win.artists = ["Alexandros Felekidis"]
        win.translator_credits = _("translator-credits")
        win.version = Rb::VERSION
        win.comments = _("Two-factor authentication code generator.")
        win.website = "https://github.com/bilelmoussaoui/Authenticator"
        win.license_type = Gtk::License::GPL_3_0
      end
    end
  end
end
