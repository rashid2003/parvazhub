# Change these
server ENV["SSH_IP"], port: ENV["SSH_PORT"], roles: [:web, :app, :db], primary: true

set :repo_url,        'git@github.com:sizief/parvazhub.git'
set :application,     'parvazhub'
set :user,            ENV["SSH_USER"]
set :pty,             true
set :use_sudo,        false
set :stage,           :production
set :deploy_via,      :remote_cache
set :deploy_to,       "/var/www/#{fetch(:application)}"
set :ssh_options,     { forward_agent: true, user: fetch(:user), keys: %w(~/.ssh/id_rsa.pub) }

#set :puma_bind,       "unix://#{shared_path}/tmp/sockets/#{fetch(:application)}-puma.sock"
#set :puma_state,      "#{shared_path}/tmp/pids/puma.state"
#set :puma_pid,        "#{shared_path}/tmp/pids/puma.pid"
#set :puma_access_log, "#{release_path}/log/puma.error.log"
#set :puma_error_log,  "#{release_path}/log/puma.access.log"
#set :puma_preload_app, true
#set :puma_worker_timeout, nil
#set :puma_init_active_record, true  # Change to false when not using ActiveRecord
#set :puma_threads,    [4, 16]
#set :puma_workers,    0

## Defaults:
# set :scm,           :git
# set :branch,        :master
# set :format,        :pretty
# set :log_level,     :debug
# set :keep_releases, 5

## Linked Files & Directories (Default None):
set :linked_files, %w{.env .env.production}
set :linked_dirs,  %w{log tmp/pids tmp/cache tmp/sockets .bundle }


namespace :deploy do
  desc "Make sure local git is in sync with remote."
  task :check_revision do
    on roles(:app) do
      unless `git rev-parse HEAD` == `git rev-parse origin/master`
        puts "WARNING: HEAD is not the same as origin/master"
        puts "Run `git push` to sync changes."
        exit
      end
    end
  end

  desc 'Restart application'
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      invoke 'puma:restart'
    end
  end

  before :starting,     :check_revision
  after  :finishing,    :compile_assets
  after  :finishing,    :cleanup
  #after  :finishing,    :restart
end

namespace :foreman do
  desc "Export the Procfile to Ubuntu's systemd scripts"
  task :export do
    on roles(:app) do
      run "cd /var/www/parvazhub/current && sudo foreman export --app parvazhub --user sizief systemd /etc/systemd/system/"
    end
  end
  
  desc "Start the application services"
  task :start do
    on roles(:app) do
      sudo "sudo systemctl start parvazhub.target"
    end
  end

  desc "Stop the application services"
  task :stop do
    on roles(:app) do
      sudo "sudo systemctl stop parvazhub.target"
    end
  end

  desc "Restart the server services"
  task :systemd_restart do
    on roles(:app) do
      run "systemctl daemon-reload"
    end
  end

  desc "Restart the server nginx"
  task :nginx_restart do
    on roles(:app) do
      run "sudo systemctl restart nginx.service"
    end
  end
end

after "deploy:update", "foreman:export"
after "deploy:update", "foreman:systemd_restart"
after "deploy:update", "foreman:stop"
after "deploy:update", "foreman:start"
after "deploy:update", "foreman:nginx_restart"

# ps aux | grep puma    # Get puma pid
# kill -s SIGUSR2 pid   # Restart puma
# kill -s SIGTERM pid   # Stop puma