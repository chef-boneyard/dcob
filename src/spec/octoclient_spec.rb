require "spec_helper"

describe Dcob::Octoclient do
  let(:hook_config) do
    { url: "https://test.example.com/payload",
      content_type: "json",
      secret: "this_is_not_a_real_secret_token",
    }
  end
  describe "#hookit (class method)" do
    it "punts to a new instance" do
      expect_any_instance_of(Dcob::Octoclient).to receive(:hookit)
      Dcob::Octoclient.hookit("fake/repo", "https://test.example.com/payload")
    end
  end

  describe "#hookit" do
    it "calls Octokit's create_hook API for a repository" do
      expect(subject.client).to receive(:create_hook).with("fake/repo", "web", hook_config, anything).and_return("happiness")
      subject.hookit("fake/repo", "https://test.example.com/payload")
    end

    it "raises an exception with GitHub repo already has the webhook" do
      allow(subject.client).to receive(:create_hook).with("fake_repo", "web", hook_config, anything).and_raise(Octokit::UnprocessableEntity)
      expect(subject.hookit("fake_repo", "https://test.example.com/payload")).to match("Skipping fake_repo due to existing hook")
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
end
