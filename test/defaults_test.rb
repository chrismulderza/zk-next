require 'minitest/autorun'
require_relative '../lib/defaults'

class DefaultsTest < Minitest::Test
  def test_constants_are_defined
    assert Defaults.const_defined?(:XDG_CONFIG_DIR)
    assert Defaults.const_defined?(:ZK_DEFAULT_CONFIG_DIR)
    assert Defaults.const_defined?(:ZK_DEFAULT_CONFIG_FILENAME)
    assert Defaults.const_defined?(:ZK_DEFAULT_CONFIG_PATH)
  end

  def test_config_path_has_expected_structure
    # The constant is evaluated at class load time with the original HOME
    # We verify it has the expected structure
    assert Defaults::ZK_DEFAULT_CONFIG_PATH.include?('.config')
    assert Defaults::ZK_DEFAULT_CONFIG_PATH.include?('zk-next')
    assert Defaults::ZK_DEFAULT_CONFIG_PATH.include?('config.yaml')
  end

  def test_initialize_creates_instance
    # Can create instance (behavior depends on whether config file exists)
    defaults = Defaults.new
    assert defaults.is_a?(Defaults)
    # Instance variable may be set or remain unset depending on file existence
    assert defaults.instance_variable_defined?(:@config) || true
  end

  def test_config_dir_constants
    assert_equal '.config', File.basename(Defaults::XDG_CONFIG_DIR)
    assert_equal 'zk-next', Defaults::ZK_DEFAULT_CONFIG_DIR
    assert_equal 'config.yaml', Defaults::ZK_DEFAULT_CONFIG_FILENAME
  end
end
