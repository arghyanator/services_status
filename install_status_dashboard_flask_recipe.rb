##
## Chef Recipe to install and run
## Python Flask web app with NGINX
## Install Chef-client 13
## 		curl -L https://omnitruck.chef.io/install.sh | sudo bash -s -- -v 13.0.118
## Run chef using the following bash shell script:
##
##    #!/bin/bash
##    sudo wget https://s3.amazonaws.com/<yourbucket>install_json_flask_recipe.rb -O /root/cookbooks/install_jsonflask/recipes/default.rb
##    sudo sh -c "cd /root && chef-client --local-mode --disable-config -r 'recipe[install_jsonflask::default]' -L /var/log/chef-client.log"
##
##
# Install status Dashboard Python Flask app recipe
# Use Chef-client in local mode to execute cookbook
#   chef-client --local-mode -r 'recipe[install_nodejs::default]'
##########################
# Cookbook does the following
# => Installs software required to run python flask and NGINX apps
# => Configures SSL certs and 

# Run apt-get update at the begining of cookbook
apt_update 'Update the apt cache' do
  action :update # If nothing specified defaults to "periodic"
end

# Install ubuntu packages required for flask, nginx - ignore failures if already installed

## Certbot for SSL certs
execute "add certbot repo" do
  command "add-apt-repository ppa:certbot/certbot"
  action :run
end
# Re-Run apt-get update after adding new repo
apt_update 'Update the apt cache' do
  action :update # If nothing specified defaults to "periodic"
end


## Create 'deploy' linux user with SSH key based authentication, full sudo privileges and disable root SSH logins (less secure)
user "deploy" do
  manage_home true
  home "/home/deploy"
  shell "/bin/bash"
  group "users"
  notifies :run, "execute[set_ssh_key_deploy]", :immediately
  not_if "getent passwd deploy"
end

execute "set_ssh_key_deploy" do
  command "mkdir -p /home/deploy/.ssh && chown deploy:users /home/deploy/.ssh && chmod 744 /home/deploy/.ssh && echo 'deploy ALL=(ALL) NOPASSWD:ALL' >>/etc/sudoers"
  action :nothing
end

## Disable SSH root login and enable auhtorized_keys
bash 'modify_sshd_settings' do
  code <<-EOH
    sed -i "s/PermitRootLogin yes/PermitRootLogin no/" /etc/ssh/sshd_config
    sed -i "s|^#AuthorizedKeysFile.*$|AuthorizedKeysFile     %h/.ssh/authorized_keys|" /etc/ssh/sshd_config
    sed -i "s|deploy:!:17590:0:99999:7:::|deploy:*:17590:0:99999:7:::|" /etc/shadow
  EOH
end

bash 'modify_sshd_settings_last' do
  code <<-EOH
    echo "Match user deploy
    PasswordAuthentication no" >>/etc/ssh/sshd_config
  EOH
  notifies :run, "execute[restart_sshd]", :immediately
  not_if "grep 'Match user deploy' /etc/ssh/sshd_config"
end

remote_file '/home/deploy/.ssh/authorized_keys' do
  source 'https://s3.amazonaws.com/yourbucket/deploy_rsa.pub'
  owner 'deploy'
  group 'users'
  mode '0644'
  action :create
end

execute "restart_sshd" do
  command "systemctl restart ssh.service"
  action :nothing
end

# Install software required for running python APP
%w(cloud-utils python-pip python-dev nginx python-certbot-nginx).each do |ubuntupkg|
	package "#{ubuntupkg}" do
		ignore_failure true
	end
end

## Install the flask apps and configure wsgi
%w(/flask-app /flask-app/templates /flask-app/static).each do |appdirs|
    directory "#{appdirs}" do
      owner 'www-data'
      group 'www-data'
      mode '0755'
      action :create
      recursive true
      ignore_failure true
    end.run_action(:create)
end

## Create all the python modules requirements file 
## which will be used to 'pip' install python modules
file '/flask-app/requirements.txt' do
      owner 'www-data'
      group 'www-data'
      mode '0644'
      content '
flask
virtualenv
boto3
flask_wtf
uwsgi
botocore
wtforms_json
logging
'
    action :create
  end

## pip install the python modules in requirements
execute "Installing python pip packages" do
  command lazy { "pip install -r /flask-app/requirements.txt" }
  action :run
end

execute "create python virtualenv" do
  command lazy { "virtualenv /flask-app/flask-appenv && source /flask-app/flask-appenv/bin/activate && pip install -r /flask-app/requirements.txt && deactivate" }
  ignore_failure true
  action :run
end

## Create the code and depending files
file '/flask-app/flask-app.py' do
      owner 'www-data'
      group 'www-data'
      mode '0644'
      content 'CONTENTS FROM app.py with single quotes escaped
'
    action :create
end

file '/flask-app/templates/table.html' do
      owner 'www-data'
      group 'www-data'
      mode '0644'
      content '
<!doctype html>
<html>
<head><title>HealthCheck status</title></head>
<meta http-equiv="refresh" content="20; url=prod_status">
<body>
<link rel=stylesheet type=text/css href="{{ url_for(\'static\', filename=\'table.css\') }}">
<div class=page1>
  <h1>Your App HealthCheck</h1>
<table>
{% for item in items %}
<h2>{{titles1}}</h2>
<TR>
   <TD class="c1">{{item.value1}}</TD> <SPAN> </SPAN> <SPAN> </SPAN><TD class="c1">{{item.value13}}</TD> <SPAN> </SPAN> <SPAN> </SPAN> {% if (item.value15 == \'{"status":"ok"}\') and (item.value17 == \'{"status":"ok"}\') and (item.value19 == \'{"status":"ok"}\') %}<TD class="c2"><SPAN>{{item.value6}}</SPAN></TD>{% else %}<TD class="c6"><SPAN>{{item.value6}}</SPAN></TD> {% endif %}
</TR>
<TR>
   <TD class="c0">{{item.value2}}</TD> <SPAN> </SPAN> <SPAN> </SPAN><TD class="c3"><SPAN><a href="{{item.value14}}" target="_blank">{{item.value14}}</a></SPAN></TD> <SPAN> </SPAN> <SPAN> </SPAN> {% if (item.value15 == \'{"status":"ok"}\') %}<TD class="c7"><SPAN>{{item.value15}}</SPAN></TD>{% else %}<TD class="c8"><SPAN><TD class="c2"><SPAN>{{item.value15}}</SPAN></TD>{% endif %}
</TR>
<TR>
   <TD class="c0">{{item.value3}}</TD> <SPAN> </SPAN> <SPAN> </SPAN><TD class="c3"><SPAN><a href="{{item.value16}}" target="_blank">{{item.value16}}</a></SPAN></TD> <SPAN> </SPAN> <SPAN> </SPAN> {% if (item.value17 == \'{"status":"ok"}\') %}<TD class="c7"><SPAN>{{item.value17}}</SPAN></TD>{% else %}<TD class="c8"><SPAN><TD class="c2"><SPAN>{{item.value17}}</SPAN></TD>{% endif %}
</TR>
<TR>
   <TD class="c0">{{item.value4}}</TD> <SPAN> </SPAN> <SPAN> </SPAN><TD class="c3"><SPAN><a href="{{item.value18}}" target="_blank">{{item.value18}}</a></SPAN></TD> <SPAN> </SPAN> <SPAN> </SPAN> {% if (item.value19 == \'{"status":"ok"}\') %}<TD class="c7"><SPAN>{{item.value19}}</SPAN></TD>{% else %}<TD class="c8"><SPAN><TD class="c2"><SPAN>{{item.value19}}</SPAN></TD>{% endif %}
</TR>

{% endfor %}
</table>
</div>
<P>
<P>
<div class=page1>
  <h1>Your App ELB status</h1>
<table>
{% for item in items %}
<h2>{{titles2}}</h2>
<TR>
   <TD class="c1">{{item.value1}}</TD> <SPAN> </SPAN> <SPAN> </SPAN><TD class="c1">{{item.value20}}</TD> <SPAN> </SPAN> <SPAN> </SPAN> <TD class="c2"><SPAN>{{item.value21}}</SPAN></TD><SPAN> </SPAN> <SPAN> </SPAN> <TD class="c2"><SPAN>{{item.value31}}</SPAN></TD>
</TR>
<TR>
   <TD class="c0">{{item.value2}}</TD> <SPAN> </SPAN> <SPAN> </SPAN><TD class="c3"><SPAN>{{item.value22}}</SPAN></TD> <SPAN> </SPAN> <SPAN> </SPAN> {% if (item.value23 == item.value28) %}<TD class="c10"><SPAN>{{item.value23}}</SPAN></TD>{% else %}<TD class="c5"><SPAN>{{item.value23}}</SPAN></TD>{% endif %}<SPAN> </SPAN> <SPAN> </SPAN> <TD class="c5"><SPAN>{{item.value28}}</SPAN></TD>
</TR>
<TR>
   <TD class="c0">{{item.value3}}</TD> <SPAN> </SPAN> <SPAN> </SPAN><TD class="c3"><SPAN>{{item.value24}}</SPAN></TD> <SPAN> </SPAN> <SPAN> </SPAN> {% if (item.value25 == item.value29) %}<TD class="c10"><SPAN>{{item.value25}}</SPAN></TD>{% else %}<TD class="c5"><SPAN>{{item.value25}}</SPAN></TD>{% endif %}<SPAN> </SPAN> <SPAN> </SPAN> <TD class="c5"><SPAN>{{item.value29}}</SPAN></TD>
</TR>
<TR>
   <TD class="c0">{{item.value4}}</TD> <SPAN> </SPAN> <SPAN> </SPAN><TD class="c3"><SPAN>{{item.value26}}</SPAN></TD> <SPAN> </SPAN> <SPAN> </SPAN> {% if (item.value27 == item.value30) %}<TD class="c10"><SPAN>{{item.value27}}</SPAN></TD>{% else %}<TD class="c5"><SPAN>{{item.value27}}</SPAN></TD>{% endif %}<SPAN> </SPAN> <SPAN> </SPAN> <TD class="c5"><SPAN>{{item.value30}}</SPAN></TD>
</TR>

{% endfor %}
</table>
</div>

</body>
</html>
'
    action :create
end



file '/flask-app/templates/main.html' do
      owner 'www-data'
      group 'www-data'
      mode '0644'
      content '
<title>Your app Stats</title> 
<link rel=stylesheet type=text/css href="{{ url_for(\'static\', filename=\'table.css\') }}">

<body>
  <div class=main_frame_health>
        <iframe id=\'STATS\' frameborder=\'0\' noresize=\'noresize\' style=\'position: relative; background: transparent; width: 100%; height: 70%; display:block\' src="/prod_status" frameborder="0"></iframe>
    </div>
<P>
</P>
<P>
</p>
</body>
'
    action :create
end


file '/flask-app/static/table.css' do
      owner 'www-data'
      group 'www-data'
      mode '0644'
      content '
body            { font-family: "Lucida Sans Unicode", "Lucida Grande", sans-serif;}
a, h1, h2       { color: #377ba8; }
h1, h2          { margin: 0; }
h1              { border-bottom: 2px solid #eee; }
h2              { font-size: 1.2em; }

table.dataframe, .dataframe th, .dataframe td {
  border: 2px;
  border-bottom: 1px solid #C8C8C8;
  border-collapse: collapse;
  text-align:left;
  padding: 10px;
  margin-bottom: 40px;
  font-size: 0.9em;
}

.c0 {
    background-color: #add8e6;
    color: black;
}

.c1 {
    background-color: #add8e6;
    color: white;
}

.c2 {
    background-color: #77dd77;
    color: white;
}

.c3 {
    background-color: #ffffff;
    color: black;
}

.c4 {
    background-color: #e6bbad;
    color: white;
}

.c5 {
    background-color: #e6bbad;
    color: black;
    font-size: 0.7em;
}

.c6 {
  background-color: #ff0000;
  color: white;
}

.c7 {
  background-color: #77dd77;
  color: white;
  font-size: 0.7em;
}

.c8 {
  background-color: #ff0000;
  color: white;
  font-size: 0.7em;
}

.c9 {
  background-color: #77dd77;
  color: white;
  font-size: 0.7em;
}

.c10 {
  background-color: #ffa500;
  color: white;
  font-size: 0.7em;
}

tr:nth-child(odd)   { background-color:#eee; }
tr:nth-child(even)  { background-color:#fff; }

tr:hover            { background-color: #ffff99;}
'
    action :create
end

## Startup script to manually start Python Flask Application
file '/flask-app/start_app.sh' do
      owner 'root'
      group 'root'
      mode '0755'
      content '
export ACCESS_KEY_PROD="xxxxx";export SECRET_KEY_PROD="xxxxxxx";
nohup python /flask-app/flask-app.py &>> /var/log/flask-app.log &
'
    action :create
end

## Script to restart Flask APP using scripts - example: Logrotate script
file '/flask-app/restart_app.sh' do
      owner 'root'
      group 'root'
      mode '0755'
      content '
kill -9 $(ps -eaf |grep python |grep -v grep| awk \'{printf"%s ", $2}\')
export ACCESS_KEY_PROD="xxxxxx";export SECRET_KEY_PROD="xxxxxx";
python /flask-app/flask-app.py >> /var/log/flask-app.log 2>&1 &
'
    action :create
end

## Create the logrotate script for rsyslog to rotate Flask-app logs
file '/etc/logrotate.d/flask-app' do
      owner 'root'
      group 'root'
      mode '0644'
      content '
/var/log/flask-app.log {
        su root root
  daily
  missingok
  rotate 5
  compress
        copytruncate
  delaycompress
  notifempty
        postrotate
             /flask-app/restart_app.sh
        endscript
}
'
    action :create
end

## Create Nginx Config for flask app
file '/etc/nginx/sites-available/flask-app' do
      owner 'root'
      group 'root'
      mode '0644'
      content '
upstream flask-app {
    server 127.0.0.1:5000 fail_timeout=0;
}
server {
  listen 80 default;
  listen [::]:80 default;
  server_name 127.0.0.1 PUBLICNAME PRIVATENAME PRIVATEIP;
  return 301 https://$host$request_uri;
}
 
server {
    listen 443 default ssl;
    listen [::]:443 default ssl;
    server_name localhost PUBLICNAME PRIVATENAME;
    
    ssl_certificate       /etc/letsencrypt/live/jsonupdate.dev/fullchain.pem;
    ssl_certificate_key   /etc/letsencrypt/live/jsonupdate.dev/privkey.pem;

    ssl_session_timeout  5m;
    ssl_protocols  SSLv3 TLSv1;
    ssl_ciphers HIGH:!ADH:!MD5;
    ssl_prefer_server_ciphers on;
    
    location / {
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Host $http_host;
        proxy_redirect http:// https://;
  
        add_header Pragma "no-cache";
 
        if (!-f $request_filename) {
            proxy_pass http://flask-app;
            break;
        }
    }

}
'
    action :create
end

bash 'start flask-app process' do
  code <<-EOH
    cd /flask-app; nohup python /flask-app/start_app.sh &
  EOH
  only_if { ::File.exist?('/etc/nginx/sites-available/flask-app') }
end

bash 'replace_publicname_nginxconfig' do
  code <<-EOH
    publicname=$(hostname -f); sed -i 's/PUBLICNAME/\'"$publicname"\'/' /etc/nginx/sites-available/flask-app
    privatename=$(hostname -s); sed -i 's/PRIVATENAME/\'"$privatename"\'/' /etc/nginx/sites-available/flask-app
    privateip=$(LANG=c ifconfig | grep -B1 "inet addr" |awk '{ if ( $1 == "inet" ) { print $2 } else if ( $2 == "Link" ) { printf "%s:" ,$1 } }' |awk -F: '{ print $1 ": " $3 }' |grep ens |awk '{print $2}'); sed -i 's/PRIVATEIP/\'"$privateip"\'/' /etc/nginx/sites-available/flask-app
  EOH
  only_if { ::File.exist?('/etc/nginx/sites-available/flask-app') }
end

# Create softlink for nginx to load this site
link '/etc/nginx/sites-enabled/flask-app' do
  to '/etc/nginx/sites-available/flask-app'
end

directory '/etc/letsencrypt/live/jsonupdate.dev' do
  owner 'root'
  group 'root'
  mode '0755'
  action :create
  recursive true
  ignore_failure true
end.run_action(:create)

file '/etc/letsencrypt/live/jsonupdate.dev/fullchain.pem' do
      owner 'root'
      group 'root'
      mode '0644'
      content '
-----BEGIN CERTIFICATE-----
MIIGyTCCBbGgAwIBAgIQA229IzDLPWVOujtY8OCd3DANBgkqhkiG9w0BAQsFADBN
xxxxxxxx==
-----END CERTIFICATE-----
-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDanaYX/P1WZ1VZ
xxxxxxx=
-----END PRIVATE KEY-----
-----BEGIN CERTIFICATE-----
MIIElDCCA3ygAwIBAgIQAf2j627KdciIQ4tyS8+8kTANBgkqhkiG9w0BAQsFADBh
xxxxxxxx
-----END CERTIFICATE-----
'
    action :create
end

file '/etc/letsencrypt/live/jsonupdate.dev/privkey.pem' do
      owner 'root'
      group 'root'
      mode '0644'
      content '
-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDanaYX/P1WZ1VZ
xxxxxxxxx=
-----END PRIVATE KEY-----
'
    action :create
end

file '/etc/nginx/sites-enabled/default' do
  action :delete
end

execute "restart nginx" do
  command lazy { "systemctl restart nginx" }
  action :run
end

execute "restart rsyslog" do
  command lazy { "systemctl restart rsyslog" }
  action :run
end
