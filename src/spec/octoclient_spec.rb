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
      Dcob::Octoclient.hookit("foo", "https://test.example.com/payload")
    end
  end

  describe "#hookit" do
    it "calls Octokit's create_hook API for a repository" do
      expect(Octokit).to receive(:create_hook).with("fake_repo", "web", hook_config, anything).and_return("happiness")
      subject.hookit("fake_repo", "https://test.example.com/payload")
    end

    it "raises an exception with GitHub repo already has the webhook" do
      allow(Octokit).to receive(:create_hook).with("fake_repo", "web", hook_config, anything).and_raise(Octokit::UnprocessableEntity)
      expect(subject.hookit("fake_repo", "https://test.example.com/payload")).to match("Skipping fake_repo due to existing hook")
    end
  end
end
