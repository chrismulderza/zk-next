# frozen_string_literal: true

require 'securerandom'
require_relative '../utils'

ZK_DEFAULT_ID_LENGTH = 8

# Base class from which everything inherits
class Document
  attr_reader :id,
              :title,
              :type,
              :path,
              :date,
              :content,
              :metadata,
              :body

  # Initialise a new Document object. Pass a hash of options to the object to
  # initialise with an existing ID, or leave empty to generate a new ID.
  def initialize(opts = {})
    @id = !opts.empty? && opts.key?(:id) ? opts[:id] : Document.generate_id
  end

  def self.generate_id
    SecureRandom.hex(ZK_DEFAULT_ID_LENGTH / 2)
  end
end
