# frozen_string_literal: true

require "adwaita"

require_relative "accounts_list"
require_relative "accounts_manager"
require_relative "provider_widget"

module Authenticator
  # AccountsWidget is the accounts page: the countdown bar above a scrolled
  # column of per-provider groups.
  #
  # Ported from the AccountsWidget class of
  # Authenticator/widgets/accounts/list.py. Upstream's two signals —
  # `changed` and `selected-rows-changed(int)` — are the two callbacks the
  # constructor takes.
  #
  # Upstream reorders the provider groups with Gtk::Box#reorder_child, which
  # GTK 4 removed in favour of reorder_child_after; the port re-appends the
  # groups in order instead, which says the same thing in one pass and does
  # not depend on where each group currently sits.
  class AccountsWidget
    def initialize(on_changed: nil, on_selected_rows_changed: nil, on_edit: nil)
      @on_changed = on_changed
      @on_selected_rows_changed = on_selected_rows_changed
      @on_edit = on_edit
      @providers = {}
      @provider_widgets = {}
      @to_delete = []
    end

    def build
      @build ||= container.tap do |box|
        box.append(otp_progress_bar)
        box.append(accounts_scrolled)

        accounts_scrolled.tap do |scrolled|
          scrolled.child = accounts_container
        end

        AccountsManager.default.on_counter_updated { |counter| on_counter_updated(counter) }
        fill_data
      end
    end

    # Adds an account, creating its provider's group if this is the first
    # account that provider has.
    def append(account)
      @providers[account.provider].then do |existing|
        if existing.nil?
          add_provider(account.provider)
        end
      end
      @providers[account.provider].add_row(account)
      reorder
      @on_changed&.call
    end

    def accounts_lists = @providers.values

    # provider name => its ProviderWidget, in the order the groups were
    # created rather than the order they are shown in.
    def provider_widgets = @provider_widgets

    def clear
      @provider_widgets.each_value { |widget| accounts_container.remove(widget.build) }
      @providers = {}
      @provider_widgets = {}
      @to_delete = []
      @on_changed&.call
    end

    def state=(state)
      @providers.each_value { |list| list.state = state }
    end

    # Upstream's delete_selected: delete across every provider's list, then
    # drop the groups left empty.
    def delete_selected
      @providers.each_value(&:delete_selected)
      clean_unneeded_provider_widgets
      @on_changed&.call
    end

    # The search query, applied to every provider's list.
    def query=(query)
      @providers.each_value { |list| list.query = query }
    end

    # Upstream's update_provider: move an account's row out of its old
    # provider group and into the new one.
    def update_provider(account, new_provider)
      @providers.each_value.find { |list| list.row_for(account) }.then do |current_list|
        if current_list
          current_list.remove_row(current_list.row_for(account))
          account.provider = new_provider
          append(account)
          on_account_deleted(current_list)
          clean_unneeded_provider_widgets
        end
      end
    end

    # Upstream's _on_counter_updated: the bar empties over the code's lifetime
    # and says how long is left.
    def on_counter_updated(counter)
      otp_progress_bar.fraction = counter.to_f / AccountsManager.default.counter_max
      otp_progress_bar.tooltip_text =
        "The One-Time Passwords expires in #{counter} seconds"
    end

    def container
      @container ||= Gtk::Box.new(:vertical, 0).tap do |box|
        box.add_css_class("accounts-widget")
      end
    end

    def otp_progress_bar = @otp_progress_bar ||= Gtk::ProgressBar.new

    def accounts_scrolled
      @accounts_scrolled ||= Gtk::ScrolledWindow.new.tap do |scrolled|
        scrolled.vexpand = true
        scrolled.hscrollbar_policy = :never
      end
    end

    def accounts_container
      @accounts_container ||= Gtk::Box.new(:vertical, 0).tap do |box|
        box.add_css_class("accounts-container")
        box.margin_start = 32
        box.margin_end = 32
      end
    end

    private

      def add_provider(provider)
        AccountsList.new(
          on_selected_count_changed: ->(_count) { on_selected_count_changed },
          on_account_deleted:        ->(list) { on_account_deleted(list) },
          on_edit:                   @on_edit,
        ).tap do |list|
          @providers[provider] = list
          ProviderWidget.new(list, provider).tap do |widget|
            @provider_widgets[provider] = widget
            accounts_container.append(widget.build)
          end
        end
      end

      def fill_data
        AccountsManager.default.accounts.each { |account| append(account) }
      end

      def on_selected_count_changed
        @on_selected_rows_changed&.call(@providers.values.sum(&:selected_rows_count))
      end

      def on_account_deleted(accounts_list)
        accounts_list.empty?.then do |empty|
          if empty
            @to_delete << accounts_list
          end
        end
      end

      def clean_unneeded_provider_widgets
        @to_delete.each do |list|
          @providers.key(list).then do |provider|
            if provider
              accounts_container.remove(@provider_widgets[provider].build)
              @provider_widgets.delete(provider)
              @providers.delete(provider)
            end
          end
        end
        @to_delete = []
      end

      # Upstream's _reorder: the provider groups sit in case-insensitive
      # alphabetical order.
      def reorder
        @provider_widgets.keys.sort_by(&:downcase).each do |provider|
          accounts_container.remove(@provider_widgets[provider].build)
          accounts_container.append(@provider_widgets[provider].build)
        end
      end
  end
end
