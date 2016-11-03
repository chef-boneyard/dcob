require "octokit"

module Dcob
  class Octoclient
    def self.hookit(repository, callback_url)
      new.hookit(repository, callback_url)
    end

    def hookit(repository, callback_url)
      github_service_name = "web"
      hook_config = { url: callback_url,
                      content_type: "json",
                      secret: SECRET_TOKEN }
      hook_options = { events: ["pull_request"],
                       active: true }
      Octokit.create_hook(repository, github_service_name, hook_config, hook_options)
    rescue Octokit::UnprocessableEntity => e
      "Skipping #{repository} due to existing hook"
    end
  end
end
