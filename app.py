#!/usr/bin/env python
# Import Python modules 

from flask import Flask, render_template, request, jsonify
import json, os, sys, tempfile, requests
from wtforms import widgets, Form
from wtforms.fields import SelectFieldBase, StringField, TextAreaField, SubmitField
from wtforms.validators import ValidationError, InputRequired
import logging
import wtforms_json
import boto3

'''
Assumptions:
	1. Application is deployed in 3 AWS regions
	2. Application has multiple (A & B) stacks with one stack and ELB active at any one point of time
	3. Application stack is using Auto-scaling groups
'''
app = Flask(__name__)
app.config["WTF_CSRF_ENABLED"] = False
wtforms_json.init()

# Get credentials from Environment vatiables
ACCESS_KEY=os.environ["ACCESS_KEY"]
SECRET_KEY=os.environ["SECRET_KEY"]

## if debug logging requested as parameter True - setting debug logging for API HTTP Calls
logging.basicConfig()
logging.getLogger().setLevel(logging.DEBUG)
requests_log = logging.getLogger("requests.packages.urllib3")
requests_log.setLevel(logging.DEBUG)
requests_log.propagate = False

## Setting Debug to False by default
REQ_DEBUG = "False"

# Set http verbose logging ON or OFF
if str(REQ_DEBUG) == "true":
    #print "Debug option requested...running app in debug mode"
    ## Set HTTP debug logging
    try:
        import http.client as http_client
    except ImportError:
        # Python 2
        import httplib as http_client
    http_client.HTTPConnection.debuglevel = 1
else:
    #print "Debug logging not requested...running add in non-debug mode"
    ## Set HTTP debug logging
    try:
        import http.client as http_client
    except ImportError:
        # Python 2
        import httplib as http_client
    http_client.HTTPConnection.debuglevel = 0

# Check ELB inService Instance count in all 3 regions
def check_elb():
	# UE1
	client = boto3.client('elb', aws_access_key_id=ACCESS_KEY, aws_secret_access_key=SECRET_KEY, region_name='us-east-1')
	ELBNameUE1=['COMMA', 'SEPARATED', 'LIST OF YOUR ELB NAMES HERE']
	for ELB in ELBNameUE1:
		response = client.describe_instance_health(LoadBalancerName=ELB)
		instancecount = 0
		for instance in response['InstanceStates']:
			#Calculate Instances in state InService in the
			if instance['State'] == "InService":
				instancecount = instancecount + 1
		if instancecount > 0:
			activeELBnameUE1 = ELB
			instanceCountUE1 = instancecount
	# EW1
	client = boto3.client('elb', aws_access_key_id=ACCESS_KEY, aws_secret_access_key=SECRET_KEY, region_name='eu-west-1')
	ELBNameEW1=['COMMA', 'SEPARATED', 'LIST OF YOUR ELB NAMES HERE']
	for ELB in ELBNameEW1:
		response = client.describe_instance_health(LoadBalancerName=ELB)
		instancecount = 0
		for instance in response['InstanceStates']:
			#Calculate Instances in state InService in the
			if instance['State'] == "InService":
				instancecount = instancecount + 1
		if instancecount > 0:
			activeELBnameEW1 = ELB
			instanceCountEW1 = instancecount

	# AN1
	client = boto3.client('elb', aws_access_key_id=ACCESS_KEY, aws_secret_access_key=SECRET_KEY, region_name='ap-northeast-1')
	ELBNameAN1=['COMMA', 'SEPARATED', 'LIST OF YOUR ELB NAMES HERE']
	for ELB in ELBNameAN1:
		response = client.describe_instance_health(LoadBalancerName=ELB)
		instancecount = 0
		for instance in response['InstanceStates']:
			#Calculate Instances in state InService in the
			if instance['State'] == "InService":
				instancecount = instancecount + 1
		if instancecount > 0:
			activeELBnameAN1 = ELB
			instanceCountAN1 = instancecount

	#return True
	return [activeELBnameUE1, instanceCountUE1, activeELBnameEW1, instanceCountEW1, activeELBnameAN1, instanceCountAN1]


## Check MAX instances in ASG (autoscaling) group
def asg_max_instance():
	##UE1
	client = boto3.client('autoscaling', aws_access_key_id=ACCESS_KEY, aws_secret_access_key=SECRET_KEY, region_name='us-east-1')
	for i in range(0,10):
		if "YOUR AUTOSCALINGGROUP NAME HERE" in client.describe_auto_scaling_groups(AutoScalingGroupNames=[], )["AutoScalingGroups"][i]["AutoScalingGroupName"]:
			activeASG = client.describe_auto_scaling_groups(AutoScalingGroupNames=[], )["AutoScalingGroups"][i]["AutoScalingGroupName"]
			break

	maxASGsizeUE = client.describe_auto_scaling_groups(AutoScalingGroupNames=[activeASG], )["AutoScalingGroups"][0]["MaxSize"]

	##EW1
	client = boto3.client('autoscaling', aws_access_key_id=ACCESS_KEY, aws_secret_access_key=SECRET_KEY, region_name='eu-west-1')
	for i in range(0,10):
		if "YOUR AUTOSCALINGGROUP NAME HERE" in client.describe_auto_scaling_groups(AutoScalingGroupNames=[], )["AutoScalingGroups"][i]["AutoScalingGroupName"]:
			activeASG = client.describe_auto_scaling_groups(AutoScalingGroupNames=[], )["AutoScalingGroups"][i]["AutoScalingGroupName"]
			break

	maxASGsizeEW = client.describe_auto_scaling_groups(AutoScalingGroupNames=[activeASG], )["AutoScalingGroups"][0]["MaxSize"]	

	##AN1
	client = boto3.client('autoscaling', aws_access_key_id=ACCESS_KEY, aws_secret_access_key=SECRET_KEY, region_name='ap-northeast-1')
	for i in range(0,10):
		if "YOUR AUTOSCALINGGROUP NAME HERE" in client.describe_auto_scaling_groups(AutoScalingGroupNames=[], )["AutoScalingGroups"][i]["AutoScalingGroupName"]:
			activeASG = client.describe_auto_scaling_groups(AutoScalingGroupNames=[], )["AutoScalingGroups"][i]["AutoScalingGroupName"]
			break

	maxASGsizeAN = client.describe_auto_scaling_groups(AutoScalingGroupNames=[activeASG], )["AutoScalingGroups"][0]["MaxSize"]


	return [maxASGsizeUE, maxASGsizeEW, maxASGsizeAN]



     
@app.route('/prod_status', methods=['GET'])

def prod_status():
	if request.method == 'GET':
		# UE1 region
		yourappnameUE1url = 'https://yourappue1.name.com/healthchekurl'
		reqyourappnameUE1 = requests.get(yourappnameUE1url)
		if str(reqyourappnameUE1.status_code) != "200":
		    print reqyourappnameUE1.content
		    UE1Status = "DOWN - " + str(reqyourappnameUE1.content)
		else:
		    print reqyourappnameUE1.content
		    UE1Status = str(reqyourappnameUE1.content)

		# EW1 region
		yourappnameEW1url = 'https://yourappew1.name.com/healthchekurl'
		reqyourappnameEW1 = requests.get(yourappnameEW1url)
		if str(reqyourappnameEW1.status_code) != "200":
		    print reqyourappnameEW1.content
		    EW1Status = "DOWN - " + str(reqyourappnameEW1.content)
		else:
		    print reqyourappnameEW1.content
		    EW1Status = str(reqyourappnameEW1.content)

		# AN1 region
		yourappnameAN1url = 'https://yourappan1.name.com/healthchekurl'
		reqyourappnameAN1 = requests.get(yourappnameAN1url)
		if str(reqyourappnameAN1.status_code) != "200":
		    print reqyourappnameAN1.content
		    AN1Status = "DOWN - " + str(reqyourappnameAN1.content)
		else:
		    print reqyourappnameAN1.content
		    AN1Status = str(reqyourappnameAN1.content)

		#Check ELB
		elbstatus = check_elb()
		activeELBnameUE1 = elbstatus[0]
		instanceCountUE1 = elbstatus[1]
		activeELBnameEW1 = elbstatus[2] 
		instanceCountEW1 = elbstatus[3] 
		activeELBnameAN1 = elbstatus[4] 
		instanceCountAN1 = elbstatus[5]

		#Check ASG
		asgstatus = asg_max_instance()
		maxASGsizeUE = asgstatus[0]
		maxASGsizeEW = asgstatus[1]
		maxASGsizeAN = asgstatus[2]

		#Render the HTML page
		items = []
		HealthCheckItems = dict(#Healthcheck URLS
			value13="HealthCheck URLs", value14=yourappnameUE1url, value15=UE1Status, 
			value16=yourappnameEW1url, value17=EW1Status, 
			value18=yourappnameAN1url, value19=AN1Status,
			# Load Balancer / ASG instance status
			value20="ACTIVE ELB Name", value21="Active Instances",
			value22=activeELBnameUE1, value23=instanceCountUE1,
			value24=activeELBnameEW1, value25=instanceCountEW1,
			value26=activeELBnameAN1, value27=instanceCountAN1,
			value28=maxASGsizeUE, value29=maxASGsizeEW, 
			value30=maxASGsizeAN, value31="ASG Max count")
		items.append(HealthCheckItems)
		titles1 = 'Health Check status'
		titles2 = 'ELB Instance health'

	return render_template('table.html', items = items, titles1 = titles1, titles2 = titles2)


@app.route('/prod', methods=['GET'])
## Function to check Health checks
def prod():
	return render_template('main.html')


if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
