# frozen_string_literal: true

require "gtk4"

module Authenticator
  # ProviderImage resolves a provider name to an icon.
  #
  # Ported from Authenticator/utils.py. Upstream slugs the provider name
  # ("1Password" to "1password"), looks the slug up in the default icon theme
  # at a requested size, falls back to the application icon when the lookup
  # finds nothing, and scales the resulting pixbuf if the theme handed back a
  # different size.
  #
  # The GTK 4 port keeps the slugging and the fallback and drops the scaling:
  # a Gtk::Image is told its `pixel_size` and GTK renders the icon at that
  # size itself, so there is no pixbuf to rescale. Upstream reads the icons out
  # of a GResource bundle; this port ships them as a plain icon theme
  # directory under data/icons, registered with the display's theme on
  # startup.
  class ProviderImage
    # Upstream's fallback, and the name the theme directory files are under.
    APP_ICON = "com.github.bilelmoussaoui.Authenticator"

    # Where the vendored hicolor theme lives, relative to this file.
    ICONS_PATH = File.expand_path("../data/icons", __dir__)

    class << self
      # Adds the vendored theme directory to the display's icon theme, so
      # `github` and friends resolve. Idempotent: calling it twice does not
      # add the path twice.
      def register_search_path(display = Gdk::Display.default)
        display.then do |disp|
          if disp && !@registered
            Gtk::IconTheme.get_for_display(disp).add_search_path(ICONS_PATH)
            @registered = true
          end
        end
      end

      # Upstream's load_pixbuf_from_provider, as an icon name: the provider
      # slug when the theme has it, the application icon otherwise.
      def icon_name(provider, display: Gdk::Display.default)
        register_search_path(display)
        slug(provider).then do |name|
          if name.empty? || !theme_has?(name, display)
            APP_ICON
          else
            name
          end
        end
      end

      # A Gtk::Image showing the provider's icon at `size` logical pixels.
      def image(provider, size = 48, display: Gdk::Display.default)
        Gtk::Image.new.tap do |img|
          img.icon_name = icon_name(provider, display: display)
          img.pixel_size = size
        end
      end

      # Points an existing image at another provider, which is what the add
      # and edit forms do as the user types a provider name.
      def apply(image, provider, display: Gdk::Display.default)
        image.icon_name = icon_name(provider, display: display)
      end

      # "1Password" to "1password", "Google Drive" to "google-drive" —
      # upstream's `lower().strip().replace(" ", "-")`.
      def slug(provider) = provider.to_s.strip.downcase.tr(" ", "-")

      private

        def theme_has?(name, display)
          display.then do |disp|
            if disp
              Gtk::IconTheme.get_for_display(disp).has_icon?(name)
            else
              false
            end
          end
        end
    end
  end
end
