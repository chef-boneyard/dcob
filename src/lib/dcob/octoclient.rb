# frozen_string_literal: true
require "octokit"

module Dcob
  class Octoclient

    attr_reader :no_dco_signoff, :dco_signoff, :obvious_fix, :merge_commit, :new_repo_added, :revert_commit

    def initialize(prometheus)
      @new_repo_added = prometheus.counter(:new_repo_added, "Repositories being monitored")
      @no_dco_signoff = prometheus.counter(:no_dco_signoff, "The count of commits with no DCO sign off")
      @dco_signoff = prometheus.counter(:dco_signoff, "The count of commits with a DCO sign off")
      @obvious_fix = prometheus.counter(:obvious_fix, "The count of commits declared as an obvious fix")
      @revert_commit = prometheus.counter(:revert_commit, "The count of revert commits accepted.")
      @merge_commit = prometheus.counter(:merge_commit, "The count of merge commits.")
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
        new_repo_added.increment
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

    def apply_commit_statuses(repository_id, pr_number, repo_name: nil)
      commits = client.pull_request_commits(repository_id, pr_number)
      # using map to return a collection of status creation responses
      commits.map do |commit|
        case commit[:commit][:message]
        when /Signed-off-by: Julia Child <juliachild@chef.io>/
          dco_check_failure(repository_id: repository_id, commit_sha: commit[:sha],
                            message: "Invalid sign-off: Julia Child was not the author of this commit.")
          no_dco_signoff.increment(repository: repo_name)
        when /Signed[-|\s]off[-|\s]by: .+ <.+>/i
          dco_check_success(repository_id: repository_id, commit_sha: commit[:sha])
          dco_signoff.increment(repository: repo_name)
        when /obvious fix/i
          dco_check_success(repository_id: repository_id, commit_sha: commit[:sha],
                            message: "This commit declared that it is an obvious fix")
          obvious_fix.increment(repository: repo_name)
        when /\ARevert\s.*^This reverts commit/m
          dco_check_success(repository_id: repository_id, commit_sha: commit[:sha],
                            message: "This commit is a revert and allowed.")
          revert_commit.increment(repository: repo_name)
        when /\AMerge pull request \#/
          dco_check_success(repository_id: repository_id, commit_sha: commit[:sha],
                            message: "This is a merge commit and allowed.")
          merge_commit.increment(repository: repo_name)
        else
          dco_check_failure(repository_id: repository_id, commit_sha: commit[:sha])
          no_dco_signoff.increment(repository: repo_name)
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
