require 'minitest/autorun'
require 'tempfile'
require 'fileutils'
require_relative '../lib/utils'

class UtilsTest < Minitest::Test
  def setup
    @temp_home = Dir.mktmpdir
    @original_home = ENV['HOME']
    ENV['HOME'] = @temp_home
  end

  def teardown
    ENV['HOME'] = @original_home
    FileUtils.rm_rf(@temp_home) if File.exist?(@temp_home)
  end

  # parse_front_matter tests
  def test_parse_front_matter_with_valid_front_matter
    content = <<~EOF
      ---
      id: 123
      type: general
      ---
      # Title
      Content
    EOF
    metadata, body = Utils.parse_front_matter(content)
    assert_equal({ 'id' => 123, 'type' => 'general' }, metadata)
    assert_includes body, '# Title'
    assert_includes body, 'Content'
  end

  def test_parse_front_matter_without_front_matter
    content = "# Title\nContent"
    metadata, body = Utils.parse_front_matter(content)
    assert_equal({}, metadata)
    assert_equal content, body
  end

  def test_parse_front_matter_with_empty_front_matter
    content = <<~EOF
      ---
      ---
      # Title
      Content
    EOF
    metadata, body = Utils.parse_front_matter(content)
    assert_equal({}, metadata)
    assert_includes body, '# Title'
  end

  def test_parse_front_matter_with_only_opening_delimiter
    content = <<~EOF
      ---
      # Title
      Content
    EOF
    metadata, body = Utils.parse_front_matter(content)
    # Should handle gracefully - no front matter parsed
    assert_equal({}, metadata)
    assert_includes body, '# Title'
  end

  def test_parse_front_matter_with_special_characters
    content = <<~EOF
      ---
      title: "Special: Characters & Symbols"
      tags: ["tag1", "tag2"]
      ---
      # Content
    EOF
    metadata, body = Utils.parse_front_matter(content)
    assert_equal 'Special: Characters & Symbols', metadata['title']
    assert_equal ['tag1', 'tag2'], metadata['tags']
  end

  def test_parse_front_matter_with_nested_structures
    content = <<~EOF
      ---
      metadata:
        author:
          name: John
          email: john@example.com
        tags: [tag1, tag2]
      ---
      # Content
    EOF
    metadata, body = Utils.parse_front_matter(content)
    assert_equal 'John', metadata['metadata']['author']['name']
    assert_equal ['tag1', 'tag2'], metadata['metadata']['tags']
  end

  def test_parse_front_matter_with_date_object
    content = <<~EOF
      ---
      date: 2025-01-23
      ---
      # Content
    EOF
    metadata, body = Utils.parse_front_matter(content)
    assert metadata['date'].is_a?(Date)
    assert_equal Date.new(2025, 1, 23), metadata['date']
  end

  def test_parse_front_matter_with_invalid_yaml_raises_error
    content = <<~EOF
      ---
      invalid: yaml: content: [unclosed
      ---
      # Content
    EOF
    # Invalid YAML should raise an error
    assert_raises(Psych::SyntaxError) do
      Utils.parse_front_matter(content)
    end
  end

  def test_parse_front_matter_with_multiple_delimiters_in_content
    content = <<~EOF
      ---
      id: 123
      ---
      # Title
      Content with --- delimiters
      More --- content
    EOF
    metadata, body = Utils.parse_front_matter(content)
    assert_equal({ 'id' => 123 }, metadata)
    assert_includes body, 'Content with --- delimiters'
  end

  def test_parse_front_matter_with_unicode
    content = <<~EOF
      ---
      title: "日本語タイトル"
      ---
      # コンテンツ
    EOF
    metadata, body = Utils.parse_front_matter(content)
    assert_equal '日本語タイトル', metadata['title']
    assert_includes body, 'コンテンツ'
  end

  def test_parse_front_matter_with_empty_content
    content = ''
    metadata, body = Utils.parse_front_matter(content)
    assert_equal({}, metadata)
    assert_equal '', body
  end

  def test_parse_front_matter_with_only_front_matter_no_body
    content = <<~EOF
      ---
      id: 123
      type: general
      ---
    EOF
    metadata, body = Utils.parse_front_matter(content)
    assert_equal({ 'id' => 123, 'type' => 'general' }, metadata)
    assert body # May have whitespace
  end

  def test_parse_front_matter_with_inline_array_tags
    # Test parsing front matter with tags in inline array format (as rendered by format_tags_for_yaml)
    content = <<~EOF
      ---
      id: "123"
      type: "note"
      title: "Test Note"
      tags: ["tag1", "tag2"]
      ---
      # Content
    EOF
    metadata, body = Utils.parse_front_matter(content)
    assert metadata['tags'].is_a?(Array), "Tags should be an Array, got #{metadata['tags'].class}"
    assert_equal ['tag1', 'tag2'], metadata['tags']
    
    # Test with empty array
    content_empty = <<~EOF
      ---
      tags: []
      ---
      Content
    EOF
    metadata_empty, = Utils.parse_front_matter(content_empty)
    assert metadata_empty['tags'].is_a?(Array)
    assert_equal [], metadata_empty['tags']
    
    # Test with single tag
    content_single = <<~EOF
      ---
      tags: ["tag1"]
      ---
      Content
    EOF
    metadata_single, = Utils.parse_front_matter(content_single)
    assert metadata_single['tags'].is_a?(Array)
    assert_equal ['tag1'], metadata_single['tags']
  end

  def test_parse_front_matter_with_quoted_config_path
    # Test parsing front matter with config.path containing special characters (quoted)
    content_with_colon = <<~EOF
      ---
      id: "123"
      type: "note"
      title: "Meeting: Q1 Review"
      config:
        path: "123-Meeting: Q1 Review.md"
      ---
      Content
    EOF
    metadata, body = Utils.parse_front_matter(content_with_colon)
    assert_equal 'Meeting: Q1 Review', metadata['title']
    assert_equal '123-Meeting: Q1 Review.md', metadata['config']['path']
    
    # Test with hash symbol
    content_with_hash = <<~EOF
      ---
      id: "456"
      type: "note"
      title: "Note #1"
      config:
        path: "456-Note #1.md"
      ---
      Content
    EOF
    metadata_hash, = Utils.parse_front_matter(content_with_hash)
    assert_equal 'Note #1', metadata_hash['title']
    assert_equal '456-Note #1.md', metadata_hash['config']['path']
    
    # Test with ampersand
    content_with_amp = <<~EOF
      ---
      id: "789"
      type: "note"
      title: "Test & Review"
      config:
        path: "789-Test & Review.md"
      ---
      Content
    EOF
    metadata_amp, = Utils.parse_front_matter(content_with_amp)
    assert_equal 'Test & Review', metadata_amp['title']
    assert_equal '789-Test & Review.md', metadata_amp['config']['path']
  end

  # current_time_vars tests
  def test_current_time_vars_returns_hash
    vars = Utils.current_time_vars
    assert vars.is_a?(Hash)
  end

  def test_current_time_vars_contains_required_keys
    vars = Utils.current_time_vars
    assert vars.key?('date')
    assert vars.key?('year')
    assert vars.key?('month')
    assert vars.key?('id')
  end

  def test_current_time_vars_date_format
    vars = Utils.current_time_vars
    assert_match(/^\d{4}-\d{2}-\d{2}$/, vars['date'])
  end

  def test_current_time_vars_year_format
    vars = Utils.current_time_vars
    assert_match(/^\d{4}$/, vars['year'])
    assert_equal Time.now.strftime('%Y'), vars['year']
  end

  def test_current_time_vars_month_format
    vars = Utils.current_time_vars
    assert_match(/^\d{2}$/, vars['month'])
    assert_equal Time.now.strftime('%m'), vars['month']
  end

  def test_current_time_vars_id_is_string
    vars = Utils.current_time_vars
    assert vars['id'].is_a?(String)
    assert_match(/^[0-9a-f]{8}$/, vars['id'])  # 8-character hex ID
  end

  # interpolate_pattern tests
  def test_interpolate_pattern_basic
    pattern = '{type}-{date}.md'
    variables = { 'type' => 'note', 'date' => '2025-01-23' }
    result = Utils.interpolate_pattern(pattern, variables)
    assert_equal 'note-2025-01-23.md', result
  end

  def test_interpolate_pattern_with_missing_variables
    pattern = '{type}-{date}-{missing}.md'
    variables = { 'type' => 'note', 'date' => '2025-01-23' }
    result = Utils.interpolate_pattern(pattern, variables)
    assert_equal 'note-2025-01-23-{missing}.md', result
  end

  def test_interpolate_pattern_with_special_characters
    pattern = '{type}-{title}.md'
    variables = { 'type' => 'note', 'title' => 'Special: Characters & Symbols' }
    result = Utils.interpolate_pattern(pattern, variables)
    assert_equal 'note-Special: Characters & Symbols.md', result
  end

  def test_interpolate_pattern_with_nested_braces
    pattern = '{type}-{{nested}}.md'
    variables = { 'type' => 'note' }
    result = Utils.interpolate_pattern(pattern, variables)
    # Should only replace {type}, leave {{nested}} as-is
    assert_equal 'note-{{nested}}.md', result
  end

  def test_interpolate_pattern_with_empty_pattern
    pattern = ''
    variables = { 'type' => 'note' }
    result = Utils.interpolate_pattern(pattern, variables)
    assert_equal '', result
  end

  def test_interpolate_pattern_with_nil_values
    pattern = '{type}-{date}.md'
    variables = { 'type' => 'note', 'date' => nil }
    result = Utils.interpolate_pattern(pattern, variables)
    assert_equal 'note-.md', result
  end

  def test_interpolate_pattern_with_numeric_values
    pattern = '{id}-{type}.md'
    variables = { 'id' => 123, 'type' => 'note' }
    result = Utils.interpolate_pattern(pattern, variables)
    assert_equal '123-note.md', result
  end

  def test_interpolate_pattern_with_multiple_same_variable
    pattern = '{type}/{type}-{date}.md'
    variables = { 'type' => 'note', 'date' => '2025-01-23' }
    result = Utils.interpolate_pattern(pattern, variables)
    assert_equal 'note/note-2025-01-23.md', result
  end

  def test_interpolate_pattern_preserves_original
    pattern = '{type}-{date}.md'
    variables = { 'type' => 'note', 'date' => '2025-01-23' }
    result = Utils.interpolate_pattern(pattern, variables)
    # Original pattern should be unchanged
    assert_equal '{type}-{date}.md', pattern
  end

  # find_template_file tests
  def test_find_template_file_finds_local_file
    notebook_path = Dir.mktmpdir
    template_dir = File.join(notebook_path, '.zk', 'templates')
    FileUtils.mkdir_p(template_dir)
    template_file = File.join(template_dir, 'test.erb')
    File.write(template_file, 'template content')

    result = Utils.find_template_file(notebook_path, 'test.erb')
    assert_equal template_file, result

    FileUtils.rm_rf(notebook_path)
  end

  def test_find_template_file_finds_global_file_when_local_missing
    notebook_path = Dir.mktmpdir
    global_template_dir = File.join(@temp_home, '.config', 'zk-next', 'templates')
    FileUtils.mkdir_p(global_template_dir)
    global_template_file = File.join(global_template_dir, 'global.erb')
    File.write(global_template_file, 'global template')

    result = Utils.find_template_file(notebook_path, 'global.erb')
    assert_equal global_template_file, result

    FileUtils.rm_rf(notebook_path)
  end

  def test_find_template_file_prefers_local_over_global
    notebook_path = Dir.mktmpdir
    local_template_dir = File.join(notebook_path, '.zk', 'templates')
    global_template_dir = File.join(@temp_home, '.config', 'zk-next', 'templates')
    FileUtils.mkdir_p(local_template_dir)
    FileUtils.mkdir_p(global_template_dir)

    local_file = File.join(local_template_dir, 'prefer.erb')
    global_file = File.join(global_template_dir, 'prefer.erb')
    File.write(local_file, 'local')
    File.write(global_file, 'global')

    result = Utils.find_template_file(notebook_path, 'prefer.erb')
    assert_equal local_file, result

    FileUtils.rm_rf(notebook_path)
  end

  def test_find_template_file_returns_nil_when_not_found
    notebook_path = Dir.mktmpdir
    result = Utils.find_template_file(notebook_path, 'nonexistent.erb')
    assert_nil result
    FileUtils.rm_rf(notebook_path)
  end

  def test_find_template_file_with_special_characters_in_filename
    notebook_path = Dir.mktmpdir
    template_dir = File.join(notebook_path, '.zk', 'templates')
    FileUtils.mkdir_p(template_dir)
    template_file = File.join(template_dir, 'test-template.erb')
    File.write(template_file, 'content')

    result = Utils.find_template_file(notebook_path, 'test-template.erb')
    assert_equal template_file, result

    FileUtils.rm_rf(notebook_path)
  end

  def test_find_template_file_with_subdirectories
    notebook_path = Dir.mktmpdir
    template_dir = File.join(notebook_path, '.zk', 'templates', 'subdir')
    FileUtils.mkdir_p(template_dir)
    template_file = File.join(template_dir, 'nested.erb')
    File.write(template_file, 'content')

    # find_template_file only looks in .zk/templates/, not subdirectories
    result = Utils.find_template_file(notebook_path, 'nested.erb')
    assert_nil result # Should not find nested files

    FileUtils.rm_rf(notebook_path)
  end

  # slugify tests (default replacement is hyphen)
  def test_slugify_basic_lowercase
    assert_equal 'hello', Utils.slugify('Hello')
    assert_equal 'world', Utils.slugify('WORLD')
    assert_equal 'mixedcase', Utils.slugify('MiXeDcAsE')
  end

  def test_slugify_spaces_to_hyphens_default
    assert_equal 'hello-world', Utils.slugify('hello world')
    assert_equal 'meeting-q1-review', Utils.slugify('Meeting Q1 Review')
    assert_equal 'multiple-spaces', Utils.slugify('multiple   spaces')
  end

  def test_slugify_special_characters_default
    assert_equal 'meeting-q1-review', Utils.slugify('Meeting: Q1 Review')
    assert_equal 'note-1', Utils.slugify('Note #1')
    assert_equal 'test-review', Utils.slugify('Test & Review')
    assert_equal 'title-important', Utils.slugify('Title [Important]')
    assert_equal 'path-to-note', Utils.slugify('Path/To/Note')
  end

  def test_slugify_collapses_multiple_hyphens
    assert_equal 'hello-world', Utils.slugify('hello---world')
    assert_equal 'test', Utils.slugify('test---')
    assert_equal 'test', Utils.slugify('---test')
  end

  def test_slugify_removes_leading_trailing_hyphens
    assert_equal 'hello', Utils.slugify('-hello-')
    assert_equal 'world', Utils.slugify('--world--')
    assert_equal 'test', Utils.slugify('---test---')
  end

  def test_slugify_preserves_hyphens
    assert_equal 'hello-world', Utils.slugify('hello-world')
    assert_equal 'test-note-1', Utils.slugify('Test-Note-1')
    assert_equal 'mixed-hyphens-and-underscores', Utils.slugify('Mixed-Hyphens And Underscores')
  end

  def test_slugify_preserves_underscores
    assert_equal 'hello_world', Utils.slugify('hello_world')
    assert_equal 'test_note_1', Utils.slugify('test_note_1')
  end

  def test_slugify_with_empty_string
    assert_equal '', Utils.slugify('')
    assert_equal '', Utils.slugify('   ')
  end

  def test_slugify_with_nil
    assert_equal '', Utils.slugify(nil)
  end

  def test_slugify_with_only_special_characters
    assert_equal '', Utils.slugify('::##&&')
    assert_equal '', Utils.slugify('!!!')
  end

  def test_slugify_with_numbers
    assert_equal 'note-123', Utils.slugify('Note 123')
    assert_equal '2024-01-15', Utils.slugify('2024-01-15') # Hyphens are preserved
    assert_equal 'id-1769504274', Utils.slugify('ID: 1769504274')
  end

  def test_slugify_with_unicode
    # Unicode characters should be replaced with hyphens (default)
    assert_equal 'hello-world', Utils.slugify('Hello 世界 World')
    assert_equal 'test', Utils.slugify('Test🎉')
  end

  def test_slugify_complex_examples
    assert_equal 'meeting-q1-review-2024', Utils.slugify('Meeting: Q1 Review (2024)')
    assert_equal 'note-1-important', Utils.slugify('Note #1 [Important]')
    assert_equal 'test-review-final', Utils.slugify('Test & Review - Final') # Multiple hyphens collapsed
  end

  def test_slugify_with_custom_replacement_underscore
    assert_equal 'hello_world', Utils.slugify('hello world', replacement_char: '_')
    assert_equal 'meeting_q1_review', Utils.slugify('Meeting: Q1 Review', replacement_char: '_')
    assert_equal 'note_1', Utils.slugify('Note #1', replacement_char: '_')
  end

  def test_slugify_with_custom_replacement_empty
    assert_equal 'helloworld', Utils.slugify('hello world', replacement_char: '')
    assert_equal 'meetingq1review', Utils.slugify('Meeting: Q1 Review', replacement_char: '')
  end

  def test_slugify_with_custom_replacement_other_char
    assert_equal 'hello.world', Utils.slugify('hello world', replacement_char: '.')
    assert_equal 'meeting.q1.review', Utils.slugify('Meeting: Q1 Review', replacement_char: '.')
  end

  def test_current_time_vars_with_custom_date_format
    vars = Utils.current_time_vars(date_format: '%m/%d/%Y')
    assert_match(/^\d{2}\/\d{2}\/\d{4}$/, vars['date'])
    
    vars2 = Utils.current_time_vars(date_format: '%d-%m-%Y')
    assert_match(/^\d{2}-\d{2}-\d{4}$/, vars2['date'])
  end

  def test_current_time_vars_with_default_date_format
    vars = Utils.current_time_vars
    assert_match(/^\d{4}-\d{2}-\d{2}$/, vars['date'])
  end
end
