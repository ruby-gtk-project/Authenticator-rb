# frozen_string_literal: true

require "adwaita"

require_relative "provider_image"

module Authenticator
  # ProviderWidget is one provider's heading — its icon and name — with that
  # provider's accounts listed underneath.
  #
  # Ported from the ProviderWidget class of
  # Authenticator/widgets/accounts/list.py.
  class ProviderWidget
    attr_reader :provider

    def initialize(accounts_list, provider)
      @accounts_list = accounts_list
      @provider = provider
    end

    def build
      @build ||= container.tap do |box|
        box.append(provider_container)
        box.append(@accounts_list.build)

        provider_container.tap do |header|
          header.append(provider_image)
          header.append(provider_label)
        end
      end
    end

    def container
      @container ||= Gtk::Box.new(:vertical, 3).tap do |box|
        box.margin_top = 3
        box.margin_bottom = 3
      end
    end

    def provider_container
      @provider_container ||= Gtk::Box.new(:horizontal, 3).tap do |box|
        box.margin_top = 3
        box.margin_bottom = 3
      end
    end

    def provider_image = @provider_image ||= ProviderImage.image(@provider, 48)

    def provider_label
      @provider_label ||= Gtk::Label.new(@provider).tap do |lbl|
        lbl.halign = :start
        lbl.add_css_class("provider-lbl")
      end
    end
  end
end
