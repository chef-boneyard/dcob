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
      begin
        retries ||= 0
        client.create_hook(repository, github_service_name, hook_config, hook_options)
      rescue Octokit::NotFound, Faraday::TimeoutError => e
        if (retries += 1) < 3
          sleep retries * 10 if ENV["RACK_ENV"] == "production"
          retry
        else
          raise e
        end
      end
    rescue Octokit::UnprocessableEntity => e
      "Skipping #{repository} due to existing hook"
    end

    def client
      Octokit.client
    end
  end
end
