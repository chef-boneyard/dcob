# frozen_string_literal: true
require "dcob/version"
require "sinatra"
require "octokit"
require "dcob/octoclient"
require "json"
require "pp"
require "openssl"
require "toml"
require "rack"
require "prometheus/client"
require "prometheus/client/rack/collector"
require "prometheus/client/rack/exporter"

module Dcob
  class Server < Sinatra::Base
    use Rack::Deflater, if: ->(env, status, headers, body) { body.any? && body[0].length > 512 }
    use Prometheus::Client::Rack::Collector
    use Prometheus::Client::Rack::Exporter

    attr_reader :octoclient

    def initialize(app = nil)
      super
      prometheus = Prometheus::Client.registry
      @octoclient = Dcob::Octoclient.new(prometheus)
      @failed_signatures = prometheus.counter(:failed_github_signature, "The count of failed GitHub signatures")
    end

    before do
      @payload_body = request.body.read
      request_signature = request.env.fetch("HTTP_X_HUB_SIGNATURE", "")
      check_signature = "sha1=" + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha1"), SECRET_TOKEN, @payload_body)
      unless Rack::Utils.secure_compare(check_signature, request_signature)
        @failed_signatures.increment unless request_signature.empty?
        return halt 500, "Signatures didn't match!"
      end
    end

    set(:event_type) do |type|
      condition { request.env["HTTP_X_GITHUB_EVENT"] == type }
    end

    post "/payload", event_type: "ping" do
      ping = JSON.parse(@payload_body)
      logger.info ping
      [200, {}, "PONG"]
    end

    post "/payload", event_type: "repository" do
      begin
        repo = JSON.parse(@payload_body)
        if !repo["repository"]["private"] && %w{created publicized}.include?(repo["action"])
          callback_url = request.url
          octoclient.hookit(repo["repository"]["full_name"], callback_url)
          [200, {}, "Hooked #{repo["repository"]["full_name"]}"]
        else
          [200, {}, "Nothing to do here."]
        end
      rescue Octokit::Error
        [500, {}, "nope"]
      end
    end

    post "/payload", event_type: "pull_request" do
      pr = JSON.parse(@payload_body)
      repo_id = pr["repository"]["id"]
      if %w{opened reopened synchronize}.include? pr["action"]
        puts "Processing #{pr['pull_request']['head']['repo']['name']} ##{pr['number']}"
        octoclient.apply_commit_statuses(repo_id, pr["number"], repo_name: pr["repository"]["full_name"])
      end
      "Please Drive Through!"
    end
  end
end

if ENV["GITHUB_LOGIN"] && ENV["GITHUB_ACCESS_TOKEN"] && ENV["GITHUB_SECRET_TOKEN"]
  Octokit.login = ENV["GITHUB_LOGIN"]
  Octokit.access_token = ENV["GITHUB_ACCESS_TOKEN"]
  SECRET_TOKEN = ENV["GITHUB_SECRET_TOKEN"]
  DCO_INFO_URL = ENV["DCO_INFO_URL"] || "http://developercertificate.org/"
else
  unless File.exist?("config.toml")
    puts "You need to provide a config.toml"
    exit 1
  end

  config = TOML.load_file("config.toml")
  if config["cfg"]["login"]
    Octokit.login = config["cfg"]["login"]
  else
    puts "You must specify cfg.login in config.toml"
    exit 1
  end

  if config["cfg"]["access_token"]
    Octokit.access_token = config["cfg"]["access_token"]
  else
    puts "You must specify cfg.access_token in config.toml"
    exit 1
  end

  if config["cfg"]["secret_token"]
    SECRET_TOKEN = config["cfg"]["secret_token"]
  else
    puts "You must specify cfg.secret_token in config.toml"
    exit 1
  end

  if config["cfg"]["dco_info_url"]
    DCO_INFO_URL = config["cfg"]["dco_info_url"]
  else
    puts "You must specify cfg.dco_info_url in config.toml"
    exit 1
  end
end
