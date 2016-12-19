# frozen_string_literal: true
require "octokit"

module Dcob
  class Octoclient
    def self.hookit(repository, callback_url)
      new.hookit(repository, callback_url)
    end

    def self.apply_commit_statuses(repository_id, pr_number)
      new.apply_commit_statuses(repository_id, pr_number)
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

    def apply_commit_statuses(repository_id, pr_number)
      commits = client.pull_request_commits(repository_id, pr_number)
      # using map to return a collection of status creation responses
      commits.map do |commit|
        case commit[:commit][:message]
        when /Signed-off-by: Julia Child <juliachild@chef.io>/
          dco_check_failure(repository_id: repository_id, commit_sha: commit[:sha],
                            message: "Invalid sign-off: Julia Child was not the author of this commit.")
        when /Signed[-|\s]off[-|\s]by: .+ <.+>/i
          dco_check_success(repository_id: repository_id, commit_sha: commit[:sha])
        when /obvious fix/i
          dco_check_success(repository_id: repository_id, commit_sha: commit[:sha],
                            message: "This commit declared that it is an obvious fix")
        else
          dco_check_failure(repository_id: repository_id, commit_sha: commit[:sha])
        end
      end
    end

    def dco_check_success(repository_id:, commit_sha:,
                          message: "This commit has a DCO Signed-off-by")
      puts "Flagging SHA #{commit_sha} as succeeded; #{message}"
      client.create_status(repository_id,
                           commit_sha,
                           "success",
                           context: "DCO",
                           target_url: DCO_INFO_URL,
                           description: message)
    end

    def dco_check_failure(repository_id:, commit_sha:,
                          message: "This commit does not have a DCO Signed-off-by")
      puts "Flagging SHA #{commit_sha} as failed; #{message}"
      client.create_status(repository_id,
                           commit_sha,
                           "failure",
                           context: "DCO",
                           target_url: DCO_INFO_URL,
                           description: message)
    end

    def client
      Octokit.client
    end
  end
end
