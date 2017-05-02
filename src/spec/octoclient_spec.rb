# frozen_string_literal: true
require "spec_helper"

describe Dcob::Octoclient do
  let(:hook_config) do
    { url: "https://test.example.com/payload",
      content_type: "json",
      secret: "this_is_not_a_real_secret_token",
    }
  end
  let(:prometheus) { instance_double(Prometheus::Client::Registry) }

  let(:new_repo_added) { instance_double(Prometheus::Client::Counter) }
  let(:no_dco_signoff) { instance_double(Prometheus::Client::Counter) }
  let(:dco_signoff) { instance_double(Prometheus::Client::Counter) }
  let(:obvious_fix) { instance_double(Prometheus::Client::Counter) }

  let(:subject_repo) { "fake/repo" }

  subject do
    described_class.new(prometheus)
  end

  before do
    allow(prometheus).to receive(:counter).with(:new_repo_added, anything).and_return(new_repo_added)
    allow(prometheus).to receive(:counter).with(:no_dco_signoff, anything).and_return(no_dco_signoff)
    allow(prometheus).to receive(:counter).with(:dco_signoff, anything).and_return(dco_signoff)
    allow(prometheus).to receive(:counter).with(:obvious_fix, anything).and_return(obvious_fix)

    allow(no_dco_signoff).to receive(:increment)
    allow(dco_signoff).to receive(:increment)
    allow(obvious_fix).to receive(:increment)
  end

  describe "#hookit" do
    before do
      allow(new_repo_added).to receive(:increment)
    end

    it "calls Octokit's create_hook API for a repository" do
      expect(subject.client).to receive(:create_hook).with("fake/repo", "web", hook_config, anything).and_return("happiness")
      subject.hookit("fake/repo", "https://test.example.com/payload")
    end

    it "raises an exception with GitHub repo already has the webhook" do
      allow(subject.client).to receive(:create_hook).with("fake_repo", "web", hook_config, anything).and_raise(Octokit::UnprocessableEntity)
      expect(subject.hookit("fake_repo", "https://test.example.com/payload")).to match("Skipping fake_repo due to existing hook")
    end

    it "updates the count of repositories monitored" do
      allow(subject.client).to receive(:create_hook).with("fake/repo", "web", hook_config, anything).and_return("happiness")
      expect(new_repo_added).to receive(:increment)
      subject.hookit("fake/repo", "https://test.example.com/payload")
    end

    context "retries" do
      it "retries from one timeout and succeeds" do
        stub_request(:post, "https://api.github.com/repos/fake/repo/hooks")
          .to_timeout
          .to_return(status: 200)

        expect { subject.hookit("fake/repo", "https://test.example.com/payload") }.not_to raise_error
      end

      it "retries from one not-yet-fully-created repo and succeeds" do
        stub_request(:post, "https://api.github.com/repos/fake/repo/hooks")
          .to_return(status: 404)
          .to_return(status: 200)

        expect { subject.hookit("fake/repo", "https://test.example.com/payload") }.not_to raise_error
      end

      it "retries from two not-yet-fully-created repo and succeeds" do
        stub_request(:post, "https://api.github.com/repos/fake/repo/hooks")
          .to_return(status: 404)
          .to_return(status: 404)
          .to_return(status: 200)

        expect { subject.hookit("fake/repo", "https://test.example.com/payload") }.not_to raise_error
      end

      it "retries from three not-yet-fully-created repo and fails" do
        stub_request(:post, "https://api.github.com/repos/fake/repo/hooks")
          .to_return(status: 404)

        expect { subject.hookit("fake/repo", "https://test.example.com/payload") }
          .to raise_error(Octokit::NotFound)
      end
    end
  end

  describe "#apply_commit_statuses" do
    def commit_factory(messages)
      messages.map.with_index(1) do |message, index|
        { sha: index, commit: { message: message } }
      end
    end

    context "on commits with signed-offs" do
      it "sets OK when there are dashes" do
        all_commits_signed_off = commit_factory [
          "Fix all the bugs.\n\nSigned-off-by: Fix-It Felix Jr. <felixjr@fixit.example.com>",
          "Missed some.\n\nSigned-off-by: Fix-It Felix Jr. <felixjr@fixit.example.com>",
        ]
        allow(subject.client).to receive(:pull_request_commits).and_return(all_commits_signed_off)
        expect(subject).to receive(:dco_check_success).twice
        expect(subject).not_to receive(:dco_check_failure)
        expect(dco_signoff).to receive(:increment).with(repository: subject_repo).twice
        subject.apply_commit_statuses(123, 456, repo_name: subject_repo)
      end

      it "sets OK when there are spaces" do
        all_commits_signed_off = commit_factory [
          "Fix all the bugs.\n\nSigned off by: Fix-It Felix Jr. <felixjr@fixit.example.com>",
          "Missed some.\n\nSigned off by: Fix-It Felix Jr. <felixjr@fixit.example.com>",
        ]
        allow(subject.client).to receive(:pull_request_commits).and_return(all_commits_signed_off)
        expect(subject).to receive(:dco_check_success).twice
        expect(dco_signoff).to receive(:increment).with(repository: subject_repo).twice
        expect(subject).not_to receive(:dco_check_failure)
        subject.apply_commit_statuses(123, 456, repo_name: subject_repo)
      end

      it "set OK regardless of capitalization" do
        all_commits_signed_off = commit_factory [
          "Fix all the bugs.\n\nsigned-off-by: Fix-It Felix Jr. <felixjr@fixit.example.com>",
          "Missed some.\n\nSIGNED-OFF-BY: Fix-It Felix Jr. <felixjr@fixit.example.com>",
        ]
        allow(subject.client).to receive(:pull_request_commits).and_return(all_commits_signed_off)
        expect(subject).to receive(:dco_check_success).twice
        expect(dco_signoff).to receive(:increment).with(repository: subject_repo).twice
        expect(subject).not_to receive(:dco_check_failure)
        subject.apply_commit_statuses(123, 456, repo_name: subject_repo)
      end
    end

    it "sets failed status on commits without signed-offs" do
      no_commits_signed_off = commit_factory [
        "I'm gonna wreck it.\n\nRalph",
        "What's going on in this candy-coated heart of darkness?",
      ]
      allow(subject.client).to receive(:pull_request_commits).and_return(no_commits_signed_off)
      expect(subject).to receive(:dco_check_failure).twice
      expect(no_dco_signoff).to receive(:increment).with(repository: subject_repo).twice
      subject.apply_commit_statuses(123, 456, repo_name: subject_repo)
    end

    it "sets OK and failed as appropriate with multiple commits" do
      only_some_commits_signed_off = commit_factory [
          "But right now, you have to fix this go-kart for me.\n\nRalph",
          "I don't have to do boo! Forgive my potty-mouth.\n\nSigned-off-by: Fix-It Felix Jr. <felixjr@fixit.example.com>",
        ]
      allow(subject.client).to receive(:pull_request_commits).and_return(only_some_commits_signed_off)
      expect(subject).to receive(:dco_check_failure).once
      expect(no_dco_signoff).to receive(:increment).with(repository: subject_repo)
      expect(subject).to receive(:dco_check_success).once
      expect(dco_signoff).to receive(:increment).with(repository: subject_repo)
      subject.apply_commit_statuses(123, 456, repo_name: subject_repo)
    end

    it "sets OK status on commits invoking the obvious fix rule" do
      obvious_fixes = commit_factory [
        "This is an obvious fix.",
        "This is an Obvious fix, too.",
      ]
      allow(subject.client).to receive(:pull_request_commits).and_return(obvious_fixes)
      expect(subject).to receive(:dco_check_success).with(repository_id: 123, commit_sha: 1, message: "This commit declared that it is an obvious fix").once
      expect(subject).to receive(:dco_check_success).with(repository_id: 123, commit_sha: 2, message: "This commit declared that it is an obvious fix").once
      expect(obvious_fix).to receive(:increment).with(repository: subject_repo).twice
      subject.apply_commit_statuses(123, 456, repo_name: subject_repo)
    end

    it "sets failed on commits with contact information from our contributing doc" do
      a_commit_from_julia = commit_factory [
        "Signed-off-by: Julia Child <juliachild@chef.io>",
      ]
      allow(subject.client).to receive(:pull_request_commits).and_return(a_commit_from_julia)
      expect(subject).to receive(:dco_check_failure).with(repository_id: 123, commit_sha: 1, message: "Invalid sign-off: Julia Child was not the author of this commit.").once
      expect(no_dco_signoff).to receive(:increment).with(repository: subject_repo)
      expect(subject).not_to receive(:dco_check_success)
      subject.apply_commit_statuses(123, 456, repo_name: subject_repo)
    end
  end

  describe "#dco_check_success" do
    it "calls the Octokit client to create a successful commit DCO status" do
      expect(subject.client).to receive(:create_status)
      .with(:repo_id, :commit_sha, "success",
            context: "DCO",
            target_url: DCO_INFO_URL,
            description: "This commit has a DCO Signed-off-by")

      subject.dco_check_success(repository_id: :repo_id, commit_sha: :commit_sha)
    end

    it "accepts a message to include in the success result" do
      expect(subject.client).to receive(:create_status)
      .with(:repo_id, :commit_sha, "success",
            context: "DCO",
            target_url: DCO_INFO_URL,
            description: "Customized!")

      subject.dco_check_success(repository_id: :repo_id, commit_sha: :commit_sha,
                                message: "Customized!")
    end
  end

  describe "#dco_check_failure" do
    it "calls the Octokit client to create a failure commit DCO status" do
      expect(subject.client).to receive(:create_status)
      .with(:repo_id, :commit_sha, "failure",
            context: "DCO",
            target_url: DCO_INFO_URL,
            description: "This commit does not have a DCO Signed-off-by")

      subject.dco_check_failure repository_id: :repo_id, commit_sha: :commit_sha
    end

    it "accepts a message to include in the failure result" do
      expect(subject.client).to receive(:create_status)
      .with(:repo_id, :commit_sha, "failure",
            context: "DCO",
            target_url: DCO_INFO_URL,
            description: "Customized!")

      subject.dco_check_failure(repository_id: :repo_id, commit_sha: :commit_sha,
                                message: "Customized!")
    end
  end
end
