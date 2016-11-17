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
        when /Signed[-|\s]off[-|\s]by: .+ <.+>/i
          puts "Flagging SHA #{commit[:sha]} as succeeded; has DCO"
          dco_check_success(repository_id, commit[:sha])
        when /obvious fix/i
          puts "Flagging SHA #{commit[:sha]} as succeeded; obvious fix declared"
          obvious_fix_check_success(repository_id, commit[:sha])
        else
          puts "Flagging SHA #{commit[:sha]} as failed; no DCO"
          dco_check_failure(repository_id, commit[:sha])
        end
      end
    end

    def dco_check_success(repository_id, commit_sha)
      client.create_status(repository_id,
                           commit_sha,
                           "success",
                           context: "DCO",
                           target_url: DCO_INFO_URL,
                           description: "This commit has a DCO Signed-off-by")
    end

    def dco_check_failure(repository_id, commit_sha)
      client.create_status(repository_id,
                           commit_sha,
                           "failure",
                           context: "DCO",
                           target_url: DCO_INFO_URL,
                           description: "This commit does not have a DCO Signed-off-by")
    end

    def obvious_fix_check_success(repository_id, commit_sha)
      client.create_status(repository_id,
                           commit_sha,
                           "success",
                           context: "DCO",
                           target_url: DCO_INFO_URL,
                           description: "This commit declared that it is an obvious fix")
    end

    def client
      Octokit.client
    end
  end
end
