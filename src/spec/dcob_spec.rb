# frozen_string_literal: true
require "spec_helper"

describe Dcob do
  it "has a version number" do
    expect(Dcob::VERSION).not_to be nil
  end
end

describe "DCO Bot webhook server" do
  include Rack::Test::Methods

  def app
    Dcob::Server
  end

  context "random connections" do
    it "get a 500" do
      get "/"
      expect(last_response).to_not be_ok
    end
  end

  context "processing pings" do
    let(:headers) do
      { "CONTENT_TYPE" => "application/json",
        "HTTP_X_GITHUB_EVENT" => "ping",
        "HTTP_X_HUB_SIGNATURE" => "nope" }
    end

    it "sends happiness back to GitHub" do
      payload_body = File.read("spec/support/fixtures/webhook_ping.json")
      request_signature = "sha1=" + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha1"), "this_is_not_a_real_secret_token", payload_body)
      headers["HTTP_X_HUB_SIGNATURE"] = request_signature

      post "/payload", payload_body, headers
      expect(last_response).to match("PONG")
    end
  end

  context "processing repository events" do
    let(:headers) do
      { "CONTENT_TYPE" => "application/json",
        "HTTP_X_GITHUB_EVENT" => "repository",
        "HTTP_X_HUB_SIGNATURE" => "nope" }
    end

    it "does nothing with an empty post to repo webhook" do
      post "/payload", "", headers
      expect(last_response.status).to eq(500)
    end

    it "adds the push payload webhook to a new public repository" do
      payload_body = File.read("spec/support/fixtures/new_public_repo_created_payload.json")
      request_signature = "sha1=" + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha1"), "this_is_not_a_real_secret_token", payload_body)
      headers["HTTP_X_HUB_SIGNATURE"] = request_signature

      expect_any_instance_of(Dcob::Octoclient).to receive(:hookit)
        .with("baxterandthehackers/new-repository", "http://example.org/payload")
        .and_return("Hooked the thing")
      post "/payload", payload_body, headers
      expect(last_response).to be_ok
      expect(last_response).to match("Hooked")
    end

    it "ignores a new private repository" do
      payload_body = File.read("spec/support/fixtures/new_private_repo_created_payload.json")
      request_signature = "sha1=" + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha1"), "this_is_not_a_real_secret_token", payload_body)
      headers["HTTP_X_HUB_SIGNATURE"] = request_signature

      expect_any_instance_of(Dcob::Octoclient).to_not receive(:hookit)
      post "/payload", payload_body, headers
      expect(last_response).to be_ok
      expect(last_response).to match("Nothing to do here.")
    end
  end

  context "processing pull request events" do
    let(:headers) do
      { "CONTENT_TYPE" => "application/json",
        "HTTP_X_GITHUB_EVENT" => "pull_request",
        "HTTP_X_HUB_SIGNATURE" => "nope" }
    end

    it "does nothing with an empty post to pull_request webhook" do
      post "/payload", "", headers
      expect(last_response.status).to eq(500)
    end

    it "confirms OK a PR with signed-off commits" do
      payload_body = File.read("spec/support/fixtures/pull_request_event_payload.json")
      request_signature = "sha1=" + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha1"), "this_is_not_a_real_secret_token", payload_body)
      headers["HTTP_X_HUB_SIGNATURE"] = request_signature

      parsed_payload = JSON.parse(payload_body)
      repo_id = parsed_payload["repository"]["id"]
      pr_number = parsed_payload["number"]

      expect_any_instance_of(Dcob::Octoclient).to receive(:apply_commit_statuses)
        .with(repo_id, pr_number, repo_name: "baxterthehacker/public-repo")
        .and_return("Commit statuses created.")
      post "/payload", payload_body, headers
      expect(last_response).to be_ok
      expect(last_response).to match("Please Drive Through!")
    end
  end
end
