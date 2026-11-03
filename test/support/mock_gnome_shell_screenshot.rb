# frozen_string_literal: true

# A stand-in for GNOME Shell's org.gnome.Shell.Screenshot, so
# test/drive_backup_and_search.rb can drive Authenticator::Screenshot against
# a real session bus without a real GNOME session.
#
# It answers the two methods the model calls: SelectArea reports a fixed
# rectangle, and ScreenshotArea writes a QR code to the filename it was given
# — the same QR code the drive script then expects the scanner to read, which
# is what makes the screenshot-to-token path end to end.
#
# It runs as its own process rather than a fork of the driver: GDBus keeps a
# worker thread per connection, and a forked child inherits the connection but
# not the thread, so a forked mock never acquires its name.
#
#   ruby test/support/mock_gnome_shell_screenshot.rb <uri-to-encode>

require "gio2"

$LOAD_PATH.unshift(File.expand_path("../../lib", __dir__))
require "screenshot"

INTERFACE_XML = <<~XML
  <node>
    <interface name="org.gnome.Shell.Screenshot">
      <method name="SelectArea">
        <arg type="i" name="x" direction="out"/>
        <arg type="i" name="y" direction="out"/>
        <arg type="i" name="width" direction="out"/>
        <arg type="i" name="height" direction="out"/>
      </method>
      <method name="ScreenshotArea">
        <arg type="i" name="x" direction="in"/>
        <arg type="i" name="y" direction="in"/>
        <arg type="i" name="width" direction="in"/>
        <arg type="i" name="height" direction="in"/>
        <arg type="b" name="flash" direction="in"/>
        <arg type="s" name="filename" direction="in"/>
        <arg type="b" name="success" direction="out"/>
        <arg type="s" name="filename_used" direction="out"/>
      </method>
    </interface>
  </node>
XML

# The rectangle SelectArea reports, which the driver asserts verbatim.
AREA = [10, 20, 300, 300].freeze

# What ScreenshotArea draws into the file it is handed.
PAYLOAD = ARGV.fetch(0, "otpauth://totp/Slack:slacker?secret=MFRGGZDFMZTWQ2LK")

# How long the mock stays up if nobody shuts it down, so a driver that dies
# does not leave it behind.
LIFETIME = 60_000

BUS = Gio.bus_get_sync(Gio::BusType::SESSION)

BUS.register_object(
  Authenticator::Screenshot::OBJECT_PATH,
  Gio::DBusNodeInfo.new(INTERFACE_XML).lookup_interface(Authenticator::Screenshot::INTERFACE),
) do |_connection, _sender, _path, _interface, name, parameters, invocation|
  case name
  when "SelectArea"
    invocation.return_value(GLib::Variant.parse("(#{AREA.join(", ")})"))
  when "ScreenshotArea"
    parameters[5].then do |filename|
      system("qrencode", "-s", "8", "-o", filename, PAYLOAD, out: File::NULL, err: File::NULL)
      invocation.return_value(
        GLib::Variant.parse("(true, #{Authenticator::Screenshot.send(:quote, filename)})"),
      )
    end
  else
    invocation.return_dbus_error("org.freedesktop.DBus.Error.UnknownMethod", name)
  end
end

Gio.bus_own_name_on_connection(
  BUS,
  Authenticator::Screenshot::INTERFACE,
  Gio::BusNameOwnerFlags::NONE,
)

GLib::Timeout.add(LIFETIME) { exit(0) }
GLib::MainLoop.new.run
