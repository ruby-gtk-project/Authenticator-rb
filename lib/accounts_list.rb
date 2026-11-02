# frozen_string_literal: true

require "adwaita"

require_relative "account"
require_relative "account_row"

module Authenticator
  # AccountsList is one provider's accounts, as a list box.
  #
  # Ported from the AccountsList class of
  # Authenticator/widgets/accounts/list.py. Upstream's two signals —
  # `selected-count-rows-changed(int)` and `account-deleted` — are the two
  # callbacks the constructor takes.
  #
  # Upstream reaches a row's Account through `row.account`, which it can do
  # because its rows subclass Gtk::ListBoxRow. The port builds rows as plain
  # objects that own a Gtk::ListBoxRow, so the mapping back from the widget to
  # the row object is the `@rows` hash — the pattern the house style's
  # list_box_complex example uses.
  class AccountsList
    NORMAL = :normal
    SELECT = :select

    attr_reader :state

    def initialize(on_selected_count_changed: nil, on_account_deleted: nil, on_edit: nil)
      @on_selected_count_changed = on_selected_count_changed
      @on_account_deleted = on_account_deleted
      @on_edit = on_edit
      @rows = {}
      @query = ""
      @state = NORMAL
    end

    def build
      @build ||= list_box.tap do |box|
        box.set_filter_func { |gtk_row| matches?(@rows[gtk_row]) }
      end
    end

    def add_row(account)
      AccountRow.new(
        account,
        on_selected: -> { on_row_checked },
        on_edit:     @on_edit,
      ).tap do |row|
        @rows[row.build] = row
        list_box.append(row.build)
      end
    end

    def rows = @rows.values

    def empty? = @rows.empty?

    def accounts = rows.map(&:account)

    # Finds the row showing an account, which is how the widget above locates
    # a row when a provider changes.
    def row_for(account) = rows.find { |row| row.account == account }

    def remove_row(row)
      @rows.delete(row.build)
      list_box.remove(row.build)
    end

    def selected_rows_count = rows.count(&:checked?)

    # Upstream's set_state: show or hide every row's check button.
    def state=(state)
      @state = state
      rows.each { |row| row.selectable = (state == SELECT) }
      on_row_checked
    end

    # Upstream's delete_selected: remove the ticked accounts from the store
    # and the list, then leave selection mode.
    def delete_selected
      rows.select(&:checked?).each do |row|
        row.account.remove
        remove_row(row)
      end
      @on_account_deleted&.call(self)
      self.state = NORMAL
    end

    # The search query the SearchBar applies. Upstream passes a filter
    # function and the query to Gtk::ListBox#set_filter_func on every keypress;
    # GTK 4's filter function takes the row alone, so the query is held here
    # and the filter invalidated instead.
    def query=(query)
      @query = query.to_s.strip.downcase
      list_box.invalidate_filter
    end

    def list_box
      @list_box ||= Gtk::ListBox.new.tap do |box|
        box.selection_mode = :none
        box.add_css_class("accounts-list")
      end
    end

    private

      # Upstream's filter_func: an empty query shows everything, otherwise the
      # query has to appear in the username or the provider.
      def matches?(row)
        row.then do |account_row|
          if account_row.nil? || @query.empty?
            true
          else
            account_row.account.username.to_s.downcase.include?(@query) ||
              account_row.account.provider.to_s.downcase.include?(@query)
          end
        end
      end

      def on_row_checked
        @on_selected_count_changed&.call(selected_rows_count)
      end
  end
end
