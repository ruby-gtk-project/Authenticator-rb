# frozen_string_literal: true

# Drives exe/authenticator itself, as a subprocess, the way a real caller
# invokes it rather than the way the other two drive scripts do — against
# the port's Ruby classes in-process. Nothing else in the suite shells out to
# the entry point, so a regression in its flag parsing or exit behaviour has
# no check that would catch it:
#
#   nix develop --command xvfb-run -a ruby test/drive_cli.rb
#
# Every run gets its own throwaway XDG_CONFIG_HOME/XDG_DATA_HOME, removed on
# the way out, so none of this touches the real store.

require "fileutils"
require "open3"
require "tmpdir"

ROOT = Dir.mktmpdir("authenticator-drive-cli")
ENV["XDG_CONFIG_HOME"] = File.join(ROOT, "config")
ENV["XDG_DATA_HOME"] = File.join(ROOT, "data")

EXE = File.expand_path("../exe/authenticator", __dir__)

CHECKS = []

def check(description, expected, actual)
  CHECKS << [description, expected, actual]
  puts(format("%-54s %-30s %s", description, expected.inspect, actual.inspect))
end

# --- --version: exits 1, the version line on stderr, nothing on stdout -----
#
# Upstream's authenticator.py.in does `sys.exit("Version : " + str(VERSION))`,
# and in Python `sys.exit(<str>)` writes the string to stderr and exits with
# status 1 — not the 0-on-stdout a `--version` flag usually means. exe/
# authenticator's `abort` reproduces exactly that, and this is the only check
# in the suite that would notice it regressing to `puts` and `exit(0)`.
Open3.capture3(RbConfig.ruby, EXE, "--version").then do |stdout, stderr, status|
  check("--version exits 1", 1, status.exitstatus)
  check("--version writes the version line to stderr", true, stderr.include?("Version : "))
  check("--version writes nothing to stdout", "", stdout)
end

# --- --help: exits 0, the usage banner on stdout, nothing on stderr -------
#
# Both requires run before OptionParser ever looks at argv, so GTK's own
# EGL probing writes its "DRI3 device" warning to stderr under Xvfb
# regardless of which flag was given; that is the display driver, not the
# port, so it is filtered out before asserting the port wrote nothing of
# its own to stderr.
Open3.capture3(RbConfig.ruby, EXE, "--help").then do |stdout, stderr, status|
  check("--help exits 0", 0, status.exitstatus)
  check("--help prints a usage banner to stdout", true, stdout.include?("Usage: Authenticator"))
  check("--help lists both flags", true, stdout.include?("--debug") && stdout.include?("--version"))
  check(
    "--help writes nothing of its own to stderr",
    "",
    stderr.lines.reject { |line| line.include?("libEGL") }.join,
  )
end

# --- --debug: runs the app rather than exiting early -----------------------
#
# Upstream raises its log level and otherwise falls through to
# `Authenticator.Application().run(sys.argv)`; the only way to tell that
# apart from `--version`'s early exit is to watch it actually start the
# application and stay up, rather than exit immediately the way a bad flag
# or a parse error would. It is killed once that much is confirmed, since an
# interactive window has nothing further to check here.
DEBUG_OUT = File.join(ROOT, "debug.out")
DEBUG_ERR = File.join(ROOT, "debug.err")
debug_pid = Process.spawn(RbConfig.ruby, EXE, "--debug", out: DEBUG_OUT, err: DEBUG_ERR)
sleep(2)

def still_running?(pid)
  Process.kill(0, pid)
  true
rescue Errno::ESRCH
  false
end

check("--debug is still running after two seconds, not exited early", true, still_running?(debug_pid))
Process.kill("TERM", debug_pid)
Process.wait(debug_pid)
check("--debug responded to SIGTERM rather than hanging", true, $?.signaled? || $?.exitstatus != 0)

FileUtils.remove_entry(ROOT)

CHECKS.reject { |_description, expected, actual| expected == actual }.then do |failures|
  puts
  if failures.empty?
    puts "#{CHECKS.size} checks passed"
    puts "DRIVE OK"
  else
    failures.each do |description, expected, actual|
      warn "FAILED #{description}: expected #{expected.inspect}, got #{actual.inspect}"
    end
    exit(1)
  end
end
