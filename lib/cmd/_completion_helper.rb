#!/usr/bin/env ruby
# frozen_string_literal: true

# Helper script for shell completion
# Provides shared completion data (common options, etc.)
# Note: Command-specific completions are handled by each command via --completion option

def get_common_options
  %w[--help --version]
end

# Main entry point
command = ARGV[0]

case command
when 'common_options'
  puts get_common_options.join(' ')
else
  puts ''
end
