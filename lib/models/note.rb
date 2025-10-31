# frozen_string_literal: true

require 'yaml'
require 'date'

# Base class for notes in zk-next
class Note
  attr_reader :path, :id, :metadata, :content

  def initialize(path)
    @path = path
    @content = File.read(path)
    parse_front_matter
  end

  private

  def parse_front_matter
    if @content.start_with?('---')
      parts = @content.split('---', 3)
      if parts.size >= 3
        @metadata = YAML.safe_load(parts[1], permitted_classes: [Date])
        @content = parts[2]
      end
    end
    @metadata ||= {}
    @id = @metadata['id']&.to_s || generate_id
  end

  def generate_id
    # Generate a unique ID, e.g., timestamp-based
    Time.now.to_i.to_s
  end
end
