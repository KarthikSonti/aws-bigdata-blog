# Building Event Driven Batch Analytics on AWS

## Overview

This repository contains the code that supports the [AWS Big Data Blog Post](https://blogs.aws.amazon.com/bigdata/)

The class LambdaContainer contains all the Lambda functions configured for "Validation/Conversion" , "Tracking Input" ,  "EMR Job Submission" and "EMR Job Monitoring" layers. Fabricated "sales" and "items" data files are created to test this code. [Maven](https://maven.apache.org/) is used for build and dependency management

## Pre-Requisites
1. Create VPC with at least one private <<MyPrivateSubnet>> and one public subnet <<MyPublicSubnet>>
2. Create a NAT Gateway or NAT Instance for [lambda functions in private subnet](https://aws.amazon.com/blogs/aws/new-access-resources-in-a-vpc-from-your-lambda-functions/) to be able to access internet
3. Create a role <<myLambdaRole> with AWSLambdaVPCAccessExecution, AWSLambdaRole, ElasticMapReduceForEC2Role,S3 and Cloudwatch access policies
4. Create security group <<MySecurityGroup>> with inbound MySQL (3306) and Redshift (5439) ports open
5. Jar file with all dependencies is already available in S3 at this location. Download it your local environment [location](s3://event-driven-batch-analytics/code/eventdrivenbatchanalytics.jar)
6. If you wish to build your own jar,download mySQL JDBC driver and Redshift JDBC Driver and add it to your maven repository

## Getting Started

1. Create S3 bucket
  ```
  aws s3 mb event-driven-batch-analytics
  ```
2. Create Validation/Conversion Layer Lambda function
```
aws lambda create-function --function-name validateAndNormalizeInputData --zip-file fileb:///<<MyPath>>/eventdrivenbatchanalytics.jar --handler com.amazonaws.bigdatablog.edba.LambdaContainer::validateAndNormalizeInputData --role arn:aws:iam::<<myAccountNumber>>:role/<<myLambdaRole>> --runtime java8 --timeout 120
```
3. Provide S3 permissions to invoke the Validation Layer lambda function

```
aws lambda add-permission --function-name auditValidatedFile --statement-id 2222 --action "lambda:InvokeFunction" --principal s3.amazonaws.com --source-arn arn:aws:s3:::event-driven-batch-analytics --source-account <<MyAccount>>
```
4. Create "Input Tracking Layer" lambda function

```
aws lambda create-function --function-name  auditValidatedFile --zip-file fileb:///<<MyPath>>/eventdrivenbatchanalytics.jar --handler com.amazonaws.bigdatablog.edba.LambdaContainer::auditValidatedFile --role arn:aws:iam::<<myAccountNumber>>:role/lambdas3eventprocessor --runtime java8 --vpc-config '{"SubnetIds":["MyPrivateSubnet"],"SecurityGroupIds":["MySecurityGroup"]}' --memory-size 1024 --timeout 120
```
5. Provide S3 permissions to invoke "Input Tracking Layer" lambda function
```
aws lambda add-permission --function-name auditValidatedFile --statement-id 2222 --action "lambda:InvokeFunction" --principal s3.amazonaws.com --source-arn arn:aws:s3:::event-driven-batch-analytics --source-account 203726645967
```
6. Configure events in S3 to trigger "Validation/Conversion Layer" and "Input Tracking Layer" lambda functions
```
aws s3api put-bucket-notification-configuration --notification-configuration file:///<<MyPath>>/put-bucket-notification.json --bucket event-driven-batch-analytics
```
7. Create EMR Job Submission Layer lambda function. This function will submit a EMR job if the respective configured  criteria has been passed  
```
aws lambda create-function --function-name  checkCriteriaFireEMR --zip-file fileb:///<<MyPath>>/eventdrivenbatchanalytics-0.0.1-SNAPSHOT.jar --handler com.amazonaws.bigdatablog.edba.LambdaContainer::checkConditionStatusAndFireEMRStep --role arn:aws:iam::<<myAccountNumber>>:role/lambdas3eventprocessor --runtime java8 \
--vpc-config '{"SubnetIds":["MyPrivateSubnet"],"SecurityGroupIds":["MySecurityGroup"]}' --memory-size 1024 --timeout 300
```
9. Schedule CloudWatch Event to fire every 10 minutes to verify whether any Aggregation Job submission criteria is passed
```
aws events put-rule --name scheduledEMRJobRule --schedule-expression 'rate(10 minutes)'
```
9. Give CloudWatch events rule permission to invoke "scheduledEMRJobRule" lambda function
```
aws lambda add-permission \
--function-name checkCriteriaFireEMR \
--statement-id checkCriteriaFireEMR \
--action 'lambda:InvokeFunction' \
--principal events.amazonaws.com --source-arn  arn:aws:events:us-east-1:<<myAccountNumber>>:rule/scheduledEMRRule
```
10. Configure "checkCriteriaFireEMR" Lambda function as target for the "scheduledEMRJobRule" CloudWatch event rule
```
aws events put-targets --rule scheduledEMRJobRule  --targets '{"Id" : "1", "Arn": "arn:aws:lambda:us-east-1:<<myAccountNumber>>:function:checkCriteriaFireEMR"}'
```
11. Create EMR Job Monitoring Layer lambda function. This function will update AGGRJOBCONFIGURATION table with status of a RUNNING EMR step
```
aws lambda create-function --function-name  monitorEMRAggregationJob --zip-file fileb:///<<MyPath>>/eventdrivenbatchanalytics-0.0.1-SNAPSHOT.jar --handler com.amazonaws.bigdatablog.edba.LambdaContainer::monitorEMRStep --role arn:aws:iam::<<myAccountNumber>>:role/lambdas3eventprocessor --runtime java8 \
--vpc-config '{"SubnetIds":["MyPrivateSubnet"],"SecurityGroupIds":["MySecurityGroup"]}' --memory-size 500 --timeout 300
```
12. Schedule CloudWatch Event to monitor submitted EMR jobs  every 15 minutes
```
aws events put-rule --name monitorEMRJobRule --schedule-expression 'rate(15 minutes)'
```
13. Give Cloudwatch event rule permission to invoke "monitorEMRAggregationJob" lambda function
```
aws lambda add-permission \
--function-name monitorEMRAggregationJob \
--statement-id monitorEMRAggregationJob \
--action 'lambda:InvokeFunction' \
--principal events.amazonaws.com --source-arn  arn:aws:events:us-east-1:<<myAccountNumber>>:rule/monitorEMRJobRule
```
14. Configure "monitorEMRAggregationJob" lambda function as target for "monitorEMRJobRule"
```
aws events put-targets --rule monitorEMRJobRule  --targets '{"Id" : "1", "Arn": "arn:aws:lambda:us-east-1:<<myAccountNumber>>:function:monitorEMRAggregationJob"}'
```
15. [Create a Amazon RDS Mysql 5.7.x instance](http://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_GettingStarted.CreatingConnecting.MySQL.html)
16. Connect to the instance and execute sql statements inside resources/edba_config_mysql.sql
17. Create Redshift cluster and connect to it to execute statements inside resources/edba_redshift.sql file
18. Download the files from resource/sampledata/ to your lcoal directory and from the directory where you downloaded the files to, upload them to S3://event-driven-batch-analytics/ with prefix data/source-identical
```
aws s3 sync . s3://event-driven-batch-analytics/data/source-identical/
```
19. Observe the timestamps of CloudWatch logs for each of the lambda functions being created and updated. Notice that there are no errors recorded
20. After around 10 minutes, connect to the MySQL client and verify whether any jobs have been submitted. The schedule interval will determine the delay
```
select job_config_id from aggrjobconfiguration where last_exec_status = 'RUNNING';
```
21. Connect to the redshift cluster and verify that the data in the tables "salessummary" and "saleitemsummary" is populated
22. If for any reason a job is failed, execute the below query to find out the impacted files
```
select t1.job_config_id,t2.file_url,t2.last_validated_timestamp from aggrjobconfiguration t1 join ingestedfilestatus t2 on json_contains(t2.submitted_jobs,json_array(t1.job_config_id))=1 where t1.last_exec_status='FAILED';
```
