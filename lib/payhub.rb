# frozen_string_literal: true

require_relative "payhub/version"
require_relative "payhub/errors"
require_relative "payhub/next_action"
require_relative "payhub/types"
require_relative "payhub/webhook"
require_relative "payhub/client"

# Top-level shortcut so `Payhub.new("phk_…")` works.
module Payhub
  def self.new(*args, **kwargs)
    Client.new(*args, **kwargs)
  end
end
