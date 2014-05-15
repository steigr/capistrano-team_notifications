require 'net/http'

namespace :team_notifications do
  task :started do
    team_notify "%{deployer} is deploying %{application}#{':'+branch if branch != 'master'}#{' to '+stage if stage != 'production'}, commit: %{commit_message}"
  end

  task :finished do
    team_notify "%{deployer} successfully deployed %{application}#{':'+branch if branch != 'master'}#{' to '+stage if stage != 'production'}"
  end

  def team_notify(message)
    deployer = fetch(:deployer,  `git config user.name`.chomp)
    application = fetch(:application)
    commit_message = `git log --oneline -n 1 | cut -f2- -d' '`.chomp

    message = message % {deployer: deployer, application: application, commit_message: commit_message}

    nc_notify(message)
  end

  def nc_notify(message)
    team_notifications_token = fetch(:team_notifications_token)
    raise "Undefined capistrano-team_notifications token" if team_notifications_token.nil? || team_notifications_token.empty?
    (fetch :team_notifications_token).keys.each do |push_service|
      case push_service.to_s
      when 'space_notice'
        http = Net::HTTP.new("space-notice.com", 443)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        http.post("/p/#{team_notifications_token[push_service]}", "message=#{message}")
      when 'dna'
        http = Net::HTTP.new("dna.app.stei.gr", 443)
        http.use_ssl = true
        # http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        http.post("/#{team_notifications_token[push_service]}", "notification[message]=#{message}")
      end
    end
  end

  def branch
    fetch(:branch).to_s
  end

  def stage
    fetch(:stage).to_s
  end
end

namespace :deploy do
  before 'deploy', 'team_notifications:started'
  after 'finished', 'team_notifications:finished'
end
