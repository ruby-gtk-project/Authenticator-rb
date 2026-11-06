# frozen_string_literal: true

require "adwaita"
require "gettext"

module Authenticator
  # EmptyAccountsList is what the window shows before the first account is
  # added.
  #
  # Ported from the EmptyAccountsList class of
  # Authenticator/widgets/accounts/list.py. Upstream hand-builds a centred box
  # with a dialog-sized icon and the label "There are no accounts yet…";
  # Adwaita::StatusPage is that layout, done properly, so the port uses it and
  # keeps upstream's icon and wording.
  class EmptyAccountsList
    include GetText

    def build = status_page

    def status_page
      @status_page ||= Adwaita::StatusPage.new.tap do |page|
        page.icon_name = "dialog-information-symbolic"
        page.title = _("There are no accounts yet…")
      end
    end
  end
end
