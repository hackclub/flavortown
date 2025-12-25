require "base64"

class GitRepoService
  def self.is_cloneable?(repo_url, force: false)
    cache_key = "clone_check_#{Base64.encode64(repo_url)}"
    Rails.cache.delete(cache_key) if force
    Rails.cache.fetch(cache_key, expires_in: 1.minute) do
      _output, status = Open3.capture2e(
        {
          "GIT_TERMINAL_PROMPT" => "1",
          "GIT_ASKPASS" => "/bin/true",
          "GIT_CONFIG_GLOBAL" => "/dev/null",
          "GIT_CONFIG_SYSTEM" => "/dev/null"
        },
        "timeout", "2s",
        "git", "ls-remote", "--exit-code", "--heads",
        repo_url,
        chdir: "/"
      )
      status.success?
    end
  end
end
