# frozen_string_literal: true

# Raised when a stable move task refuses to run, with a message for whoever runs it.
class StableMove::Error < StandardError; end
