# services_status_dashboard
Monitor Status of AWS resource and present on a dashboard<br>
**Python Flask app running on AWS micro instance**
## Flask App Logrotate 
Software or python script is installed under /flask-app

The script creates logs in /var/log/flask-app.log which is rotated using linux logrotate.d daily using the following logrotate configuration:
```
# cat /etc/logrotate.d/flask-app 
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
```
## Flask app restart shell script
```
# cat /flask-app/restart_app.sh 
kill -9 $(ps -eaf |grep python |grep -v grep| awk '{printf"%s ", $2}')
export ACCESS_KEY="AKIAIZxxxxxxxx";export SECRET_KEY="xxxxxxxxxbqgTyl0BiWKP0xxxxxx";
python /flask-app/flask-app.py >> /var/log/flask-app.log 2>&1 &
```
Script uses AWS User credentials with read-only privileges on EC2 in AWS account.

## Configuration Chef cookbook
The instance is configured and software is installed using Chef automation in 'local-mode'.

## Lambda function to send alert emails when ASG capacity is coming up to max set
```
awsasg_status_alerts_email.py
```
