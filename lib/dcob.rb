require "dcob/version"
require "sinatra"
require "octokit"
require "json"
require "pp"
require "openssl"
require "toml"


module Dcob
  class Server < Sinatra::Base
    post '/payload' do
      payload_body = request.body.read
      verify_signature(payload_body)
      pr = JSON.parse(payload_body)
      if pr["action"] == "opened" || pr["action"] == "synchronize" || pr["action"] == "reopened"
        puts "Processing #{pr["pull_request"]["head"]["repo"]["name"]} ##{pr["number"]}"
        commits = Octokit.pull_request_commits(pr["pull_request"]["head"]["repo"]["id"], pr["number"])
        commits.each do |commit|
          if commit[:commit][:message] !~ /Signed-off-by: .+ <.+>/
            puts "Flagging SHA #{commit["sha"]} as failed; no DCO"
            Octokit.create_status(pr["pull_request"]["head"]["repo"]["id"],
                                  commit["sha"],
                                  "failure",
                                  :context => "DCO",
                                  :description => "This commit does not have a DCO Signed-off-by")
          else
            puts "Flagging SHA #{commit["sha"]} as succeeded; has DCO"
            Octokit.create_status(pr["pull_request"]["head"]["repo"]["id"],
                                  commit["sha"],
                                  "success",
                                  :context => "DCO",
                                  :description => "This commit has a DCO Signed-off-by")
          end
        end
      end
      "Please Drive Through!"
    end

    def verify_signature(payload_body)
      signature = 'sha1=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), SECRET_TOKEN, payload_body)
      return halt 500, "Signatures didn't match!" unless Rack::Utils.secure_compare(signature, request.env['HTTP_X_HUB_SIGNATURE'])
    end
  end
end


if !File.exists?("config.toml")
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

Dcob::Server.run!
