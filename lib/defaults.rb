# frozen_string_literal: true

require 'yaml'

# Class that holds the default config
class Defaults
  # Define our defaults
  XDG_CONFIG_DIR = File.join(ENV['HOME'], '.config')
  ZK_DEFAULT_CONFIG_DIR = 'zk-next'
  ZK_DEFAULT_CONFIG_FILENAME = 'config.yaml'
  ZK_DEFAULT_CONFIG_PATH = File.join(XDG_CONFIG_DIR, ZK_DEFAULT_CONFIG_DIR, ZK_DEFAULT_CONFIG_FILENAME)

  @config = {}

  def initialize
    @config = YAML.load_file(ZK_DEFAULT_CONFIG_PATH) if File.exist?(ZK_DEFAULT_CONFIG_PATH)
  end
end
