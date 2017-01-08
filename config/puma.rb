# Change to match your CPU core count
workers 1

# Min and Max threads per worker
threads 1, 6

app_dir = File.expand_path("../..", __FILE__)
shared_dir = "/tmp/"

bind 'tcp://0.0.0.0:3000'

activate_control_app
