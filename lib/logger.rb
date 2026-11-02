# frozen_string_literal: true

module Authenticator
  # Logger is the application's logging handler.
  #
  # Ported from Authenticator/models/logger.py, which wraps Python's `logging`
  # module in a class of static methods over one
  # `logging.getLogger('authenticator')` and formats every line as
  #
  #   FORMAT = "[%(levelname)-s] %(asctime)s %(message)s"
  #   DATE   = "%Y-%m-%d %H:%M:%S"
  #
  # Ruby's stdlib Logger would cover this, but this file is lib/logger.rb and
  # lib/ is on the gem's load path, so `require "logger"` from anywhere inside
  # the port resolves to this file rather than to the standard library. Writing
  # the four lines of formatting out is cheaper than fighting that, and it
  # keeps upstream's format exactly.
  class Logger
    DATE_FORMAT = "%Y-%m-%d %H:%M:%S"

    # Upstream's levels, in upstream's order, so `level =` reads the same.
    LEVELS = {
      debug:   0,
      info:    1,
      warning: 2,
      error:   3,
    }.freeze

    class << self
      def default = @default ||= new

      # Lets a spec capture the output instead of writing to the test
      # runner's stderr.
      attr_writer :default

      def level=(level)
        default.level = level
      end

      def debug(message) = default.debug(message)
      def info(message) = default.info(message)
      def warning(message) = default.warning(message)
      def error(message) = default.error(message)
    end

    attr_accessor :level

    def initialize(io: $stderr, level: :debug)
      @io = io
      @level = level
    end

    def debug(message) = log(:debug, message)
    def info(message) = log(:info, message)
    def warning(message) = log(:warning, message)
    def error(message) = log(:error, message)

    def log(level, message)
      (LEVELS.fetch(level) >= LEVELS.fetch(@level, 0)).then do |loud_enough|
        if loud_enough
          @io.puts("[#{level.to_s.upcase}] #{Time.now.strftime(DATE_FORMAT)} #{message}")
        end
      end
    end
  end
end
