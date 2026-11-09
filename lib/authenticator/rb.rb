# frozen_string_literal: true

# The gem's conventional entry point, matching the "authenticator-rb" gem name.
#
# `require "authenticator"` (lib/authenticator.rb) loads the actual
# application; this file exists so that requiring the gem by its own name
# resolves, and so spec/spec_helper.rb — which, by the house convention this
# fork's pilot port established, requires the gem under its own name — has
# something to load.
#
# It deliberately does not require_relative '../authenticator' here: pulling
# in the application means pulling in every widget file, and every widget
# file requires 'adwaita', which needs a real or virtual display to
# initialise GTK. A spec that genuinely needs the application asks for
# 'application' (or any other lib/*.rb file) itself; this file only has to
# expose the gem's version.
require_relative "rb/version"

module Authenticator
  module Rb
  end
end
