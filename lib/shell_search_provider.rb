# frozen_string_literal: true

require "gio2"

require_relative "database"
require_relative "logger"

module Authenticator
  # ShellSearchProvider answers GNOME Shell's overview search with the
  # accounts whose name matches what was typed, and launches the app when one
  # is picked.
  #
  # Ported from search-provider/authenticator-search-provider.py.in. Upstream
  # is a standalone D-Bus service: it owns
  # com.github.bilelmoussaoui.Authenticator.SearchProvider, also takes
  # org.gnome.Shell.SearchProvider2 on the same connection, and exports the
  # five SearchProvider2 methods at
  # /com/github/bilelmoussaoui/Authenticator/SearchProvider. The .ini file
  # beside it is what tells the Shell to look there.
  #
  # Upstream's Server base class walks the introspection XML to build a
  # signature table, then dispatches each incoming call by reflection and
  # wraps whatever the method returned in a one-element tuple. That machinery
  # exists to paper over Python's lack of a typed return; the port dispatches
  # by name in `on_method_call` and names each reply's signature where the
  # reply is built, which is both shorter and the only thing that works here —
  # the Ruby bindings expose a D-Bus interface's `methods` array as garbage
  # (one-character strings), so a signature table cannot be walked out of the
  # XML at all. `lookup_interface` does work, which is what this uses.
  #
  # Two more binding facts shape this. `call_sync` and the method-call closure
  # hand parameters over already unpacked into Ruby objects, so there is
  # nothing to call `.unpack` on; and `GLib::Variant.new(array, "(as)")` raises
  # NotImplementedError, so every reply is written in GVariant's text format
  # and run through GLib::Variant.parse, which does build tuples.
  #
  # This file deliberately requires only the Database, never the Account
  # model. Account pulls in the Clipboard, which pulls in gtk4, whose load
  # raises Gtk::InitError when there is no display — and the bus starts this
  # service with no display of its own. Upstream gets away with importing Gtk
  # because the Shell only ever starts it inside a running session; a service
  # that dies when launched headlessly is worse than one that never needed a
  # toolkit, and the two fields the Shell asks for are both columns of the
  # database row anyway.
  class ShellSearchProvider
    # Upstream's three bus constants.
    BUS_NAME = "com.github.bilelmoussaoui.Authenticator.SearchProvider"
    SEARCH_INTERFACE = "org.gnome.Shell.SearchProvider2"
    OBJECT_PATH = "/com/github/bilelmoussaoui/Authenticator/SearchProvider"

    # The command LaunchSearch spawns, which upstream spawns through
    # GLib.spawn_async_with_pipes with SEARCH_PATH.
    LAUNCHER = "authenticator"

    # Upstream's docstring, which is also its introspection data: the five
    # methods org.gnome.Shell.SearchProvider2 requires, with the signatures
    # the Shell calls them with.
    INTERFACE_XML = <<~XML
      <!DOCTYPE node PUBLIC
       '-//freedesktop//DTD D-BUS Object Introspection 1.0//EN'
       'http://www.freedesktop.org/standards/dbus/1.0/introspect.dtd'>
      <node>
        <interface name="org.gnome.Shell.SearchProvider2">
          <method name="GetInitialResultSet">
            <arg type="as" name="terms" direction="in" />
            <arg type="as" name="results" direction="out" />
          </method>
          <method name="GetSubsearchResultSet">
            <arg type="as" name="previous_results" direction="in" />
            <arg type="as" name="terms" direction="in" />
            <arg type="as" name="results" direction="out" />
          </method>
          <method name="GetResultMetas">
            <arg type="as" name="identifiers" direction="in" />
            <arg type="aa{sv}" name="metas" direction="out" />
          </method>
          <method name="ActivateResult">
            <arg type="s" name="identifier" direction="in" />
            <arg type="as" name="terms" direction="in" />
            <arg type="u" name="timestamp" direction="in" />
          </method>
          <method name="LaunchSearch">
            <arg type="as" name="terms" direction="in" />
            <arg type="u" name="timestamp" direction="in" />
          </method>
        </interface>
      </node>
    XML

    # Runs the service until the bus drops it, which is what upstream's
    # `service.hold(); service.run()` does.
    def run
      build
      main_loop.run
    end

    # Owns the names and exports the object. Separate from `run` so a drive
    # script can register the provider, talk to it, and keep its own main loop.
    def build
      @build ||= bus.tap do |connection|
        connection.register_object(OBJECT_PATH, interface_info) do |*closure_args|
          # The closure's arguments are the connection, the sender, the object
          # path, the interface name, the method name, its parameters and the
          # invocation to answer; only the last three say anything here.
          on_method_call(*closure_args.last(3))
        end
        Gio.bus_own_name_on_connection(connection, BUS_NAME, Gio::BusNameOwnerFlags::NONE)
        Gio.bus_own_name_on_connection(connection, SEARCH_INTERFACE, Gio::BusNameOwnerFlags::NONE)
      end
    end

    def bus = @bus ||= Gio.bus_get_sync(Gio::BusType::SESSION)
    def main_loop = @main_loop ||= GLib::MainLoop.new

    def interface_info
      @interface_info ||= Gio::DBusNodeInfo.new(INTERFACE_XML).lookup_interface(SEARCH_INTERFACE)
    end

    # Upstream's GetInitialResultSet and GetSubsearchResultSet, which both
    # come down to one database search. The ids come back as strings because
    # that is what SearchProvider2 passes around.
    def search(terms)
      Database.default.search(terms)
    rescue StandardError => e
      Logger.error("[SearchProvider] search failed: #{e.message}")
      []
    end

    # Upstream's GetResultMetas: the name and a "provider - username"
    # description for each id the Shell asks about.
    #
    # Upstream builds an Account per id, which decodes that account's token out
    # of the keyring and generates a code from it — work no search result ever
    # shows. The two fields it then reads are columns of the database row, so
    # the row is what this reads. Upstream also abandons the whole batch if one
    # id has gone from the database; the port skips the missing one and still
    # describes the rest, so a stale id in the Shell's cache does not blank the
    # results.
    def result_metas(identifiers)
      Array(identifiers).filter_map do |identifier|
        Database.default.get_by_id(identifier.to_i).then do |row|
          if row
            {
              "id"          => identifier.to_s,
              "name"        => row["username"].to_s,
              "description" => "#{row["provider"].to_s.strip} - #{row["username"]}",
            }
          end
        end
      end
    end

    # Upstream's LaunchSearch, which ActivateResult also calls: start the app.
    # Upstream spawns it with DO_NOT_REAP_CHILD and never reaps it, leaving a
    # zombie behind every time; Gio::Subprocess reaps its own child, so this
    # does not.
    def launch
      Gio::Subprocess.new([LAUNCHER], Gio::SubprocessFlags::NONE)
    rescue GLib::ErrorInfo, Gio::Error, GLib::Error => e
      # A missing binary arrives as GLib::SpawnError, which descends from
      # IOError rather than from either error base — the GLib::ErrorInfo module
      # above is the one thing every binding error includes.
      Logger.error("[SearchProvider] Could not launch #{LAUNCHER}: #{e.message}")
      nil
    end

    private

      # Upstream's on_method_call, by name rather than by reflection. A method
      # with no out arguments returns nothing, which is what SearchProvider2
      # expects of ActivateResult and LaunchSearch.
      def on_method_call(name, params, invocation)
        case name
        when "GetInitialResultSet"
          invocation.return_value(string_array(search(params.to_a.first)))
        when "GetSubsearchResultSet"
          invocation.return_value(string_array(search(params.to_a[1])))
        when "GetResultMetas"
          invocation.return_value(metas_variant(result_metas(params.to_a.first)))
        when "ActivateResult", "LaunchSearch"
          launch
          invocation.return_value(nil)
        else
          invocation.return_dbus_error(
            "org.freedesktop.DBus.Error.UnknownMethod",
            "#{SEARCH_INTERFACE} has no #{name}",
          )
        end
      rescue StandardError => e
        Logger.error("[SearchProvider] #{name} failed: #{e.message}")
        invocation.return_dbus_error("org.freedesktop.DBus.Error.Failed", e.message)
      end

      # An `(as)` reply.
      def string_array(strings)
        GLib::Variant.parse("([#{Array(strings).map { |string| quote(string) }.join(", ")}],)")
      end

      # An `(aa{sv})` reply: a list of dictionaries of string to variant,
      # which is the one signature the Shell demands of GetResultMetas.
      def metas_variant(metas)
        metas.map { |meta|
          meta.map { |key, value| "#{quote(key)}: <#{quote(value)}>" }.join(", ").then do |pairs|
            "{#{pairs}}"
          end
        }.join(", ").then do |dictionaries|
          GLib::Variant.parse("([#{dictionaries}],)")
        end
      end

      # A string as a GVariant text-format literal: single quotes, with a
      # backslash and a single quote escaped by a backslash. Every string here
      # is a provider or an account name the user typed, so this is what keeps
      # an apostrophe in one from breaking the reply.
      def quote(string)
        "'#{string.to_s.gsub("\\", "\\\\\\\\").gsub("'", "\\\\'")}'"
      end
  end
end
