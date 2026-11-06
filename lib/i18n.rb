# frozen_string_literal: true

require "gettext"

module Authenticator
  # The gettext text domain, matching upstream's po/meson.build
  # (`i18n.gettext('Authenticator', preset: 'glib')`), and the directory the
  # compiled .mo catalogues live in once `rake gettext:mo:update` has run.
  #
  # Bound on the Authenticator module itself rather than on each class:
  # gettext's TextDomainManager::ClassInfo.related_classes walks a class's
  # full namespace path, so every Authenticator::* class that `include
  # GetText` finds this binding without binding a copy of its own. Each class
  # with translatable strings still needs its own `include GetText` to pick
  # up the `_`/`n_` instance methods; only the domain binding is shared here.
  DOMAIN = "Authenticator"
  LOCALE_DIR = File.expand_path("../locale", __dir__)

  extend GetText
  bindtextdomain(DOMAIN, path: LOCALE_DIR)
end
