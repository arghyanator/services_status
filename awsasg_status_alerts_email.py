import boto3, os, logging, json

'''
Author: Arghya Banerjee


Sends Email alerts if ASG DesiredCapacity is (these are set as environment variables):
	- 80% or more of MaxSize send INFO email
	- 90% or more of MaxSize send WARNING email
	- 95% or more of MaxSize send CRITICAL email

IAM Policy required for this to work:
=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:*:*:*"
        },
        {
            "Action": [
                "autoscaling:DescribeAutoScalingGroups",
                "sns:Publish"
            ],
            "Effect": "Allow",
            "Resource": "*"
        }
    ]
}

Lambda Environment Variables required:
=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
ENVIRONMENT: [<PROD>/<STAGE>]
INFO: percentage integer
CRITICAL: percentage integer
WARNING: percentage integer

'''

## Check MAX instances in ASG (autoscaling) group
def check_asg_max_instance(env, region, infov, warnv, critv):
	##Check if Function is called for Env=PROD/STAGE
	if str(env) == "STAGE":
		autoscalingString="AUTOSCALINGGROUPNAMEPROD"
		aws_account="012345678901"
	else:
		autoscalingString="AUTOSCALINGGROUPNAMESTAGE"
		aws_account="112345678901"

	## Get the trigger thresholds for INFO, WARNING, CRITICAL
	INFOPERCENT = str(infov)
	WARNPERCENT = str(warnv)
	CRITPERCENT = str(critv)

	## Check ASG MaxSize, DesiredCapacity and calculate what percentage of MaxSize is DesiredCapacity
	client = boto3.client('autoscaling', region_name=str(region))
	for i in range(0,10):
		if autoscalingString in client.describe_auto_scaling_groups(AutoScalingGroupNames=[], )["AutoScalingGroups"][i]["AutoScalingGroupName"]:
			activeASG = client.describe_auto_scaling_groups(AutoScalingGroupNames=[], )["AutoScalingGroups"][i]["AutoScalingGroupName"]
			break

	maxASGsize = client.describe_auto_scaling_groups(AutoScalingGroupNames=[activeASG], )["AutoScalingGroups"][0]["MaxSize"]
	desiredASGcapacity = client.describe_auto_scaling_groups(AutoScalingGroupNames=[activeASG], )["AutoScalingGroups"][0]["DesiredCapacity"]
	percentage = 100 * int(desiredASGcapacity)/int(maxASGsize)

	## Send CRITICAL SNS email message if DesiredCapacity is more than or equal to 95% of MaxSize in ASG
	if ( percentage >= int(CRITPERCENT) ):
		message = {"environment": str(env), "ASGUsedCapacity": percentage}
		snsarn = "arn:aws:sns:" + region + ":" + aws_account + ":scripts"
		snsclient = boto3.client('sns')
		response = snsclient.publish(
			TargetArn=snsarn,
			Message=json.dumps({'default': json.dumps(message),
				'email': 'CRITICAL: ASG Used Capacity crossed 95 Percentage of Max capacity in ' + region + ' of ' + str(env) + ' Environtment.\n Current ASG Used Percentage is:' + str(percentage) + '\n Current ASG MaxSize is: ' + str(maxASGsize) + '\n Current DesiredCapacity of ASG instances is: ' + str(desiredASGcapacity) + '\n =-=-=-=-=-= \nEmail Sent by Lambda Function Name: ' + os.environ["AWS_LAMBDA_FUNCTION_NAME"]}),
			Subject=str(env) + ' CRITICAL: ASG Used Capacity Percentage Critical in ' + region,
			MessageStructure='json'
			)
		return True

	## Send WARNING SNS email message if DesiredCapacity is more than or equal to 90% of MaxSize in ASG
	if ( percentage >= int(WARNPERCENT) ):
		message = {"environment": str(env), "ASGUsedCapacity": percentage}
		snsarn = "arn:aws:sns:" + region + ":" + aws_account + ": scripts"
		snsclient = boto3.client('sns')
		response = snsclient.publish(
			TargetArn=snsarn,
			Message=json.dumps({'default': json.dumps(message),
				'email': 'WARNING: ASG Used Capacity crossed 90 Percentage of Max capacity in ' + region + ' of ' + str(env) + ' Environtment.\n Current ASG Used Percentage is:' + str(percentage) + '\n Current ASG MaxSize is: ' + str(maxASGsize) + '\n Current DesiredCapacity of ASG instances is: ' + str(desiredASGcapacity) + '\n =-=-=-=-=-= \nEmail Sent by Lambda Function Name: ' + os.environ["AWS_LAMBDA_FUNCTION_NAME"]}),
			Subject=str(env) + ' WARNING: ASG Used Capacity Percentage Warning in ' + region,
			MessageStructure='json'
			)
		return True

	## Send INFO SNS email message if DesiredCapacity is greater than or equal to 80% of MaxSize in ASG
	if ( percentage >= int(INFOPERCENT) ):
		message = {"environment": str(env), "ASGUsedCapacity": percentage}
		snsarn = "arn:aws:sns:" + region + ":" + aws_account + ":scripts"
		snsclient = boto3.client('sns')
		response = snsclient.publish(
			TargetArn=snsarn,
			Message=json.dumps({'default': json.dumps(message),
				'email': 'INFO: ASG Used Capacity crossed 80 Percentage of Max capacity in ' + region + ' of ' + str(env) + ' Environtment.\n Current ASG Used Percentage is:' + str(percentage) + '\n Current ASG MaxSize is: ' + str(maxASGsize) + '\n Current DesiredCapacity of ASG instances is: ' + str(desiredASGcapacity) + '\n =-=-=-=-=-= \nEmail Sent by Lambda Function Name: ' + os.environ["AWS_LAMBDA_FUNCTION_NAME"]}),
			Subject=str(env) + ' INFO: ASG Used Capacity Percentage crossed 80 in ' + region,
			MessageStructure='json'
			)
		return True

	return False


## Main Lambda "handler" function that lambda will invoke
def handler_checkasg(event, context):
	# Your function body here
	environment = os.environ["ENVIRONMENT"]
	region = os.environ["AWS_REGION"]
	infovar = os.environ["INFO"]
	critvar = os.environ["CRITICAL"]
	warnvar = os.environ["WARNING"]

	## Call ASG Max Instance check function with parameters
	check_asg_max_instance(environment, region, infovar, warnvar, critvar)

	return True
