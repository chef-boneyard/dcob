require "dcob/version"
require "sinatra"
require "octokit"
require "dcob/octoclient"
require "json"
require "pp"
require "openssl"
require "toml"

module Dcob
  class Server < Sinatra::Base
    before do
      @payload_body = request.body.read
      request_signature = request.env.fetch("HTTP_X_HUB_SIGNATURE", "")
      check_signature = "sha1=" + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha1"), SECRET_TOKEN, @payload_body)
      return halt 500, "Signatures didn't match!" unless Rack::Utils.secure_compare(check_signature, request_signature)
    end

    set(:event_type) do |type|
      condition { request.env["HTTP_X_GITHUB_EVENT"] == type }
    end

    post "/payload", event_type: "repository" do
      begin
        repo = JSON.parse(@payload_body)
        if !repo["repository"]["private"] && %w{created publicized}.include?(repo["action"])
          callback_url = request.url
          result = Dcob::Octoclient.hookit(repo["repository"]["full_name"], callback_url)
          [200, {}, result]
        else
          [200, {}, "Nothing to do here."]
        end
      rescue Octokit::Error => e
        [500, {}, "nope"]
      end
    end

    post "/payload", event_type: "pull_request" do
      pr = JSON.parse(@payload_body)
      repo_id = pr["repository"]["id"]
      if pr["action"] == "opened" || pr["action"] == "synchronize" || pr["action"] == "reopened"
        puts "Processing #{pr['pull_request']['head']['repo']['name']} ##{pr['number']}"
        commits = Octokit.pull_request_commits(repo_id, pr["number"])
        commits.each do |commit|
          if commit[:commit][:message] !~ /Signed-off-by: .+ <.+>/
            puts "Flagging SHA #{commit['sha']} as failed; no DCO"
            Octokit.create_status(repo_id,
                                  commit["sha"],
                                  "failure",
                                  context: "DCO",
                                  target_url: DCO_INFO_URL,
                                  description: "This commit does not have a DCO Signed-off-by")
          else
            puts "Flagging SHA #{commit['sha']} as succeeded; has DCO"
            Octokit.create_status(repo_id,
                                  commit["sha"],
                                  "success",
                                  context: "DCO",
                                  target_url: DCO_INFO_URL,
                                  description: "This commit has a DCO Signed-off-by")
          end
        end
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