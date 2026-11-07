# frozen_string_literal: true

# A headless hook for driving Authenticator::FileChoosers (and anything
# that opens a Gtk::FileDialog) under Xvfb, where there is no
# xdg-desktop-portal to answer open/save/select_folder.
#
# It stands in only for the native round trip: FileChoosers' own code still
# runs for real — building the Gtk::FileFilter with its name and mime type,
# wiring the dialog up, and running its `finish` block, which pulls `.path`
# off whatever `*_finish` hands back and calls the caller's block with it.
# `install!` captures the filter name set on every dialog it touches and
# feeds `next_path` back through the matching `*_finish` call, so a drive
# script can assert on both without a real file picker ever appearing.
module FakeFileDialog
  FakeFile = Struct.new(:path)

  class << self
    attr_accessor :next_path, :last_filter_name

    def install!
      Gtk::FileDialog.class_eval do
        alias_method(:real_default_filter=, :default_filter=) unless method_defined?(:real_default_filter=)

        define_method(:default_filter=) do |filter|
          FakeFileDialog.last_filter_name = filter.name
          send(:real_default_filter=, filter)
        end

        define_method(:open) { |*_args, &block| block.call(self, :fake_result) }
        define_method(:save) { |*_args, &block| block.call(self, :fake_result) }
        define_method(:select_folder) { |*_args, &block| block.call(self, :fake_result) }

        define_method(:open_finish) { |_result| FakeFileDialog.chosen_file }
        define_method(:save_finish) { |_result| FakeFileDialog.chosen_file }
        define_method(:select_folder_finish) { |_result| FakeFileDialog.chosen_file }
      end
    end

    def chosen_file
      next_path.nil? ? nil : FakeFile.new(next_path)
    end
  end
end
