set :stage, :production
server 'leagues.afdc.com', user: 'deploy', roles: %w{web app}
