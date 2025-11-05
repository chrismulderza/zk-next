# frozen_string_literal: true

require_relative '../utils'

# Base class for notes in zk-next
class Note
  attr_reader :path, :id, :metadata, :content

  def initialize(path)
    @path = path
    @content = File.read(path)
    @metadata, @content = Utils.parse_front_matter(@content)
    @id = @metadata['id']&.to_s || Utils.generate_id
  end
end
