require 'minitest/autorun'
require 'tempfile'
require_relative '../../lib/models/note'

class NoteTest < Minitest::Test
  def test_parse_front_matter
    content = <<~EOF
      ---
      id: 123
      type: general
      ---
      # Title
      Content
    EOF
    file = Tempfile.new(['note', '.md'])
    file.write(content)
    file.close
    note = Note.new(path: file.path)
    assert_equal '123', note.id
    assert_equal({'id' => 123, 'type' => 'general'}, note.metadata)
    assert_equal "\n# Title\nContent\n", note.content
  end

  def test_no_front_matter
    content = "# Title\nContent"
    file = Tempfile.new(['note', '.md'])
    file.write(content)
    file.close
    note = Note.new(path: file.path)
    assert note.id
    assert_equal({}, note.metadata)
    assert_equal content, note.content
  end
end