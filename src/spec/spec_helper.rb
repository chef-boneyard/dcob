# frozen_string_literal: true
$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "dcob"
require "rspec"
require "rack/test"
require "webmock/rspec"
WebMock.disable_net_connect!(allow_localhost: true)
