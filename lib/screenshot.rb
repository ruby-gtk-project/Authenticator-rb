# frozen_string_literal: true

require "gio2"

require_relative "logger"

module Authenticator
  # Screenshot asks GNOME Shell to let the user drag out a rectangle and
  # saves what is under it, which is how the QR-code scanner gets an image of
  # the code on screen.
  #
  # Ported from Authenticator/models/screenshot.py, whose GNOMEScreenshot
  # class calls two methods of GNOME Shell's org.gnome.Shell.Screenshot
  # interface in turn: `SelectArea`, which returns the rectangle the user
  # dragged as `(iiii)`, and `ScreenshotArea`, which saves that rectangle to a
  # filename and returns `(bs)`.
  #
  # Upstream reaches the interface through a Gio::DBusProxy.
  # Gio::DBusProxy.new_for_bus hands back nil in the Ruby bindings, so the
  # calls go straight down the session Gio::DBusConnection instead — the same
  # two method calls over the same bus, one object fewer in between.
  #
  # Two binding quirks shape the rest. The Ruby bindings cannot build a tuple
  # GVariant from a Ruby array (`GLib::Variant.new([...], "(iiiibs)")` raises
  # NotImplementedError) and every D-Bus call's arguments are a tuple, so the
  # `(iiiibs)` argument list is written in GVariant's own text format and run
  # through GLib::Variant.parse, which does handle tuples — that is why `quote`
  # below exists. In the other direction, `call_sync` hands back the reply
  # already unpacked into a Ruby Array rather than a GVariant, so there is
  # nothing to call `.value` on. And the bindings' error classes share no
  # single ancestor — Gio::IOError::TimedOut descends from Gio::Error,
  # GLib::Error from RuntimeError and GLib::SpawnError from IOError — but every
  # one of them includes the GLib::ErrorInfo module, so that is what the
  # rescues name first.
  class Screenshot
    # Upstream's `interface` and `path`, which are also the bus name.
    INTERFACE = "org.gnome.Shell.Screenshot"
    OBJECT_PATH = "/org/gnome/Shell/Screenshot"

    # Gio's "no timeout preference", which is what upstream's -1 means.
    DEFAULT_TIMEOUT = -1

    class << self
      # Upstream's area(): drag out a rectangle, save it, and return the file
      # it was saved to — or nil when the user cancelled the drag, when the
      # save failed, or when there is no GNOME Shell on the bus to ask.
      def area(filename = nil)
        (filename || default_filename).then do |target|
          select_area.then do |rectangle|
            if rectangle
              screenshot_area(rectangle, target)
            end
          end
        end
      end

      # Upstream names the file after a NamedTemporaryFile inside the user's
      # cache directory, so the image lands somewhere writable and is
      # recognisably throwaway. The QR reader deletes it once it has read it.
      def default_filename
        File.join(
          GLib.user_cache_dir,
          "authenticator-#{Process.pid}-#{Time.now.to_i}-#{rand(1 << 24)}.png",
        )
      end

      # The user's drag, as [x, y, width, height]. nil when they pressed
      # Escape, which GNOME Shell reports as a D-Bus error rather than an
      # empty rectangle.
      def select_area
        call("SelectArea", nil, "(iiii)").then do |reply|
          if reply
            reply.first(4).map(&:to_i)
          end
        end
      end

      # Saves a rectangle to `filename`, returning the filename GNOME Shell
      # says it wrote. Upstream passes `false` for the flash, so this does
      # too.
      def screenshot_area(rectangle, filename)
        call(
          "ScreenshotArea",
          GLib::Variant.parse(
            "(#{rectangle.map(&:to_i).join(", ")}, false, #{quote(filename)})",
          ),
          "(bs)",
        ).then do |reply|
          reply.to_a.then do |success, written|
            if success
              written
            end
          end
        end
      end

      # Whether there is a GNOME Shell screenshot interface on the session bus
      # at all. The add-account window asks before it offers to scan, so the
      # button is absent outside GNOME rather than present and broken. Asking
      # the bus who owns the name answers it without touching the screen,
      # which a real SelectArea would.
      def available?
        bus.then do |connection|
          if connection
            !owner(connection).nil?
          else
            false
          end
        end
      end

      def bus
        @bus ||= Gio.bus_get_sync(Gio::BusType::SESSION)
      rescue GLib::ErrorInfo, Gio::Error, GLib::Error => e
        Logger.error("[Screenshot] No session bus: #{e.message}")
        nil
      end

      private

        # One method call on the interface, returning the reply variant or nil
        # when the call failed — which is what a cancelled drag looks like.
        def call(method, parameters, reply_type)
          bus.then do |connection|
            if connection
              connection.call_sync(
                INTERFACE,
                OBJECT_PATH,
                INTERFACE,
                method,
                parameters,
                GLib::VariantType.new(reply_type),
                Gio::DBusCallFlags::NONE,
                DEFAULT_TIMEOUT,
              )
            end
          end
        rescue GLib::ErrorInfo, Gio::Error, GLib::Error => e
          Logger.error("[Screenshot] #{method} failed: #{e.message}")
          nil
        end

        # Who owns the screenshot name on the bus, or nil when nobody does.
        def owner(connection)
          connection.call_sync(
            "org.freedesktop.DBus",
            "/org/freedesktop/DBus",
            "org.freedesktop.DBus",
            "GetNameOwner",
            GLib::Variant.parse("('#{INTERFACE}',)"),
            GLib::VariantType.new("(s)"),
            Gio::DBusCallFlags::NONE,
            DEFAULT_TIMEOUT,
          )
        rescue GLib::ErrorInfo, Gio::Error, GLib::Error
          nil
        end

        # A string as a GVariant text-format literal. GVariant quotes with
        # single quotes and escapes a backslash and a single quote with a
        # backslash, so a path with either in it still parses.
        def quote(string)
          "'#{string.to_s.gsub("\\", "\\\\\\\\").gsub("'", "\\\\'")}'"
        end
    end
  end
end
